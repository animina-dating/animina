defmodule AniminaWeb.Admin.FlagsAiLive do
  use AniminaWeb, :live_view

  alias Animina.ActivityLog
  alias Animina.FeatureFlags
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.AdminHelpers, only: [parse_non_negative_int: 2]

  import AniminaWeb.Helpers.FeatureFlagHelpers,
    only: [
      flag_toggle: 1,
      search_bar: 1,
      filter_by_search: 2,
      parse_auto_approve_value: 1,
      save_value_setting: 4
    ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("AI / Ollama"),
       ollama_settings: FeatureFlags.get_all_ollama_settings(),
       search_query: "",
       selected_ollama_setting: nil,
       ollama_form: nil
     )}
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("toggle-ollama-flag", %{"flag" => flag_name}, socket) do
    flag_atom = String.to_existing_atom(flag_name)
    new_state = !FeatureFlags.enabled?(flag_atom)

    if new_state do
      FeatureFlags.enable(flag_atom)
    else
      FeatureFlags.disable(flag_atom)
    end

    ActivityLog.log(
      "admin",
      "feature_flag_toggled",
      "Feature flag #{flag_name} #{if new_state, do: "enabled", else: "disabled"}",
      actor_id: socket.assigns.current_scope.user.id,
      metadata: %{"flag" => flag_name, "enabled" => new_state}
    )

    {:noreply, assign(socket, ollama_settings: FeatureFlags.get_all_ollama_settings())}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: String.trim(query))}
  end

  def handle_event("clear-search", _params, socket) do
    {:noreply, assign(socket, search_query: "")}
  end

  def handle_event("open-ollama-setting", %{"setting" => setting_name}, socket) do
    setting_atom = String.to_existing_atom(setting_name)
    setting = Enum.find(socket.assigns.ollama_settings, fn s -> s.name == setting_atom end)

    form_data =
      case setting.type do
        :flag ->
          {:ok, flag_setting} =
            FeatureFlags.get_or_create_flag_setting(setting_name, %{
              description: setting.description,
              settings: %{
                auto_approve: false,
                auto_approve_value: setting.default_auto_approve_value,
                delay_ms: 0
              }
            })

          %{
            "auto_approve" => flag_setting.settings["auto_approve"] || false,
            "auto_approve_value" => flag_setting.settings["auto_approve_value"],
            "delay_ms" => flag_setting.settings["delay_ms"] || 0
          }

        _ ->
          %{"value" => setting.current_value}
      end

    {:noreply,
     assign(socket,
       selected_ollama_setting: setting,
       ollama_form: to_form(form_data, as: "ollama_setting")
     )}
  end

  def handle_event("close-ollama-modal", _params, socket) do
    {:noreply, assign(socket, selected_ollama_setting: nil, ollama_form: nil)}
  end

  def handle_event("save-ollama-setting", %{"ollama_setting" => params}, socket) do
    setting = socket.assigns.selected_ollama_setting

    case setting.type do
      :flag ->
        new_settings = %{
          "auto_approve" => params["auto_approve"] == "true",
          "auto_approve_value" => parse_auto_approve_value(params["auto_approve_value"]),
          "delay_ms" => parse_non_negative_int(params["delay_ms"], 0)
        }

        {:ok, flag_setting} =
          FeatureFlags.get_or_create_flag_setting(setting.name, %{
            description: setting.description,
            settings: %{
              auto_approve: false,
              auto_approve_value: setting.default_auto_approve_value,
              delay_ms: 0
            }
          })

        case FeatureFlags.update_flag_setting(flag_setting, %{settings: new_settings}) do
          {:ok, _updated} ->
            socket =
              socket
              |> assign(
                ollama_settings: FeatureFlags.get_all_ollama_settings(),
                selected_ollama_setting: nil,
                ollama_form: nil
              )
              |> put_flash(:info, gettext("Settings saved."))

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, gettext("Could not save settings."))}
        end

      _ ->
        save_value_setting(socket, setting, params["value"],
          refresh: [ollama_settings: FeatureFlags.get_all_ollama_settings()],
          clear: [selected_ollama_setting: nil, ollama_form: nil]
        )
    end
  end

  # --- Render ---

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :filtered_settings,
        filter_by_search(assigns.ollama_settings, assigns.search_query)
      )

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/admin"}>{gettext("Admin")}</.link>
            </li>
            <li>
              <.link navigate={~p"/admin/flags"}>{gettext("Feature Flags")}</.link>
            </li>
            <li>{gettext("AI / Ollama")}</li>
          </ul>
        </div>

        <h1 class="text-2xl font-bold text-base-content mb-2">{gettext("AI / Ollama")}</h1>
        <p class="text-base-content/70 mb-6">{gettext("Photo analysis and debug settings")}</p>

        <.search_bar search_query={@search_query} />

        <%= if @search_query != "" && Enum.empty?(@filtered_settings) do %>
          <div class="text-center py-12">
            <.icon name="hero-magnifying-glass" class="h-12 w-12 text-base-content/30 mx-auto mb-4" />
            <p class="text-base-content/60">
              {gettext("No results found for \"%{query}\"", query: @search_query)}
            </p>
          </div>
        <% else %>
          <div class="space-y-3">
            <%= for setting <- @filtered_settings do %>
              <div
                class="border border-base-300 rounded-xl p-4 flex items-center justify-between hover:border-purple-300 transition-colors shadow-sm"
                data-setting={setting.name}
              >
                <div class="flex-1">
                  <div class="flex items-center gap-2">
                    <span class="font-medium text-base-content">{setting.label}</span>
                    <%= if setting.type == :flag do %>
                      <%= if setting.setting && setting.setting.settings["delay_ms"] && setting.setting.settings["delay_ms"] > 0 do %>
                        <span class="badge badge-sm badge-warning">
                          {setting.setting.settings["delay_ms"]}ms
                        </span>
                      <% end %>
                      <%= if setting.setting && setting.setting.settings["auto_approve"] do %>
                        <span class="badge badge-sm badge-info">{gettext("Auto")}</span>
                      <% end %>
                    <% else %>
                      <span class="badge badge-sm badge-purple">{setting.current_value}</span>
                    <% end %>
                  </div>
                  <p class="text-sm text-base-content/60 mt-1">{setting.description}</p>
                  <%= if setting.type == :integer do %>
                    <p class="text-xs text-base-content/40 mt-1">
                      {gettext("Default: %{default}, Range: %{min}-%{max}",
                        default: setting.default_value,
                        min: setting.min_value,
                        max: setting.max_value
                      )}
                    </p>
                  <% end %>
                  <%= if setting.type == :string do %>
                    <p class="text-xs text-base-content/40 mt-1">
                      {gettext("Default: %{default}", default: setting.default_value)}
                    </p>
                  <% end %>
                </div>

                <div class="flex items-center gap-3">
                  <%= if setting.type != :flag or setting.default_auto_approve_value != nil do %>
                    <button
                      type="button"
                      class="btn btn-ghost btn-sm"
                      phx-click="open-ollama-setting"
                      phx-value-setting={setting.name}
                    >
                      <.icon name="hero-cog-6-tooth" class="h-4 w-4" />
                    </button>
                  <% end %>

                  <%= if setting.type == :flag do %>
                    <.flag_toggle
                      checked={setting.enabled}
                      event="toggle-ollama-flag"
                      flag_name={setting.name}
                    />
                  <% else %>
                    <button
                      type="button"
                      class="btn btn-ghost btn-sm"
                      phx-click="open-ollama-setting"
                      phx-value-setting={setting.name}
                    >
                      <.icon name="hero-pencil" class="h-4 w-4" />
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <%!-- Ollama Setting Modal --%>
        <%= if @selected_ollama_setting do %>
          <div
            class="modal modal-open"
            id="ollama-setting-modal"
            phx-window-keydown="close-ollama-modal"
            phx-key="escape"
          >
            <div class="modal-box">
              <button
                type="button"
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
                phx-click="close-ollama-modal"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>

              <h3 class="font-bold text-lg mb-4">
                {@selected_ollama_setting.label}
              </h3>

              <p class="text-sm text-base-content/70 mb-4">
                {@selected_ollama_setting.description}
              </p>

              <.form
                for={@ollama_form}
                id="ollama-setting-form"
                phx-submit="save-ollama-setting"
                class="space-y-4"
              >
                <%= if @selected_ollama_setting.type == :flag do %>
                  <div class="form-control">
                    <label class="label cursor-pointer justify-start gap-3">
                      <input
                        type="checkbox"
                        name="ollama_setting[auto_approve]"
                        value="true"
                        checked={
                          @ollama_form[:auto_approve].value == true ||
                            @ollama_form[:auto_approve].value == "true"
                        }
                        class="checkbox checkbox-primary"
                      />
                      <div>
                        <span class="label-text font-medium">{gettext("Auto-approve")}</span>
                        <p class="text-xs text-base-content/50">
                          {gettext("Skip this check and return a preset value")}
                        </p>
                      </div>
                    </label>
                  </div>

                  <%= if @selected_ollama_setting.default_auto_approve_value != nil do %>
                    <div class="form-control">
                      <label class="label">
                        <span class="label-text">{gettext("Auto-approve value")}</span>
                      </label>
                      <select
                        name="ollama_setting[auto_approve_value]"
                        class="select select-bordered"
                      >
                        <option
                          value="true"
                          selected={@ollama_form[:auto_approve_value].value == true}
                        >
                          true
                        </option>
                        <option
                          value="false"
                          selected={@ollama_form[:auto_approve_value].value == false}
                        >
                          false
                        </option>
                      </select>
                      <label class="label">
                        <span class="label-text-alt text-base-content/50">
                          {gettext("Value returned when auto-approve is enabled")}
                        </span>
                      </label>
                    </div>
                  <% end %>

                  <div class="form-control">
                    <label class="label">
                      <span class="label-text">{gettext("Delay (ms)")}</span>
                    </label>
                    <input
                      type="number"
                      name="ollama_setting[delay_ms]"
                      value={@ollama_form[:delay_ms].value}
                      min="0"
                      max="30000"
                      step="100"
                      class="input input-bordered"
                      placeholder="0"
                    />
                    <label class="label">
                      <span class="label-text-alt text-base-content/50">
                        {gettext("Artificial delay in milliseconds (0 = no delay)")}
                      </span>
                    </label>
                  </div>
                <% else %>
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text">{gettext("Value")}</span>
                    </label>
                    <%= if @selected_ollama_setting.type == :string do %>
                      <input
                        type="text"
                        name="ollama_setting[value]"
                        value={@ollama_form[:value].value}
                        class="input input-bordered"
                      />
                      <label class="label">
                        <span class="label-text-alt text-base-content/50">
                          {gettext("Default: %{default}",
                            default: @selected_ollama_setting.default_value
                          )}
                        </span>
                      </label>
                    <% else %>
                      <input
                        type="number"
                        name="ollama_setting[value]"
                        value={@ollama_form[:value].value}
                        min={@selected_ollama_setting.min_value}
                        max={@selected_ollama_setting.max_value}
                        class="input input-bordered"
                      />
                      <label class="label">
                        <span class="label-text-alt text-base-content/50">
                          {gettext("Default: %{default}, Range: %{min}-%{max}",
                            default: @selected_ollama_setting.default_value,
                            min: @selected_ollama_setting.min_value,
                            max: @selected_ollama_setting.max_value
                          )}
                        </span>
                      </label>
                    <% end %>
                  </div>
                <% end %>

                <div class="modal-action">
                  <button type="button" class="btn btn-ghost" phx-click="close-ollama-modal">
                    {gettext("Cancel")}
                  </button>
                  <button type="submit" class="btn btn-primary">
                    {gettext("Save")}
                  </button>
                </div>
              </.form>
            </div>
            <div class="modal-backdrop" phx-click="close-ollama-modal"></div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
