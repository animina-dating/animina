defmodule AniminaWeb.Admin.FeatureFlagsLive do
  use AniminaWeb, :live_view

  alias Animina.FeatureFlags

  import AniminaWeb.Helpers.AdminHelpers, only: [parse_non_negative_int: 2]

  @impl true
  def mount(_params, _session, socket) do
    photo_flags = FeatureFlags.get_all_photo_flags()
    ollama_settings = FeatureFlags.get_all_ollama_settings()
    system_settings = FeatureFlags.get_all_system_settings()
    admin_flags = FeatureFlags.get_all_admin_flags()

    {:ok,
     assign(socket,
       page_title: gettext("Feature Flags"),
       photo_flags: photo_flags,
       ollama_settings: ollama_settings,
       system_settings: system_settings,
       admin_flags: admin_flags,
       search_query: "",
       selected_flag: nil,
       selected_system_setting: nil,
       selected_ollama_setting: nil,
       form: nil,
       system_form: nil,
       ollama_form: nil
     )}
  end

  # --- Event Handlers (grouped together) ---

  @impl true
  def handle_event("toggle-flag", %{"flag" => flag_name}, socket) do
    flag_atom = String.to_existing_atom(flag_name)

    if FeatureFlags.enabled?(flag_atom) do
      FeatureFlags.disable(flag_atom)
    else
      FeatureFlags.enable(flag_atom)
    end

    {:noreply, assign(socket, photo_flags: FeatureFlags.get_all_photo_flags())}
  end

  def handle_event("toggle-ollama-flag", %{"flag" => flag_name}, socket) do
    flag_atom = String.to_existing_atom(flag_name)

    if FeatureFlags.enabled?(flag_atom) do
      FeatureFlags.disable(flag_atom)
    else
      FeatureFlags.enable(flag_atom)
    end

    {:noreply, assign(socket, ollama_settings: FeatureFlags.get_all_ollama_settings())}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: String.trim(query))}
  end

  def handle_event("clear-search", _params, socket) do
    {:noreply, assign(socket, search_query: "")}
  end

  def handle_event("toggle-admin-flag", %{"flag" => flag_name}, socket) do
    flag_atom = String.to_existing_atom(flag_name)

    if FeatureFlags.enabled?(flag_atom) do
      FeatureFlags.disable(flag_atom)
    else
      FeatureFlags.enable(flag_atom)
    end

    {:noreply, assign(socket, admin_flags: FeatureFlags.get_all_admin_flags())}
  end

  def handle_event("open-settings", %{"flag" => flag_name}, socket) do
    flag_atom = String.to_existing_atom(flag_name)
    flag = Enum.find(socket.assigns.photo_flags, fn f -> f.name == flag_atom end)

    # Get or create the setting
    {:ok, setting} =
      FeatureFlags.get_or_create_flag_setting(flag_name, %{
        description: flag.description,
        settings: %{
          auto_approve: false,
          auto_approve_value: flag.default_auto_approve_value,
          delay_ms: 0
        }
      })

    form_data = %{
      "auto_approve" => setting.settings["auto_approve"] || false,
      "auto_approve_value" => setting.settings["auto_approve_value"],
      "delay_ms" => setting.settings["delay_ms"] || 0
    }

    {:noreply,
     assign(socket,
       selected_flag: flag,
       selected_setting: setting,
       form: to_form(form_data, as: "settings")
     )}
  end

  def handle_event("close-modal", _params, socket) do
    {:noreply, assign(socket, selected_flag: nil, form: nil)}
  end

  def handle_event("save-settings", %{"settings" => settings_params}, socket) do
    new_settings = %{
      "auto_approve" => settings_params["auto_approve"] == "true",
      "auto_approve_value" => parse_auto_approve_value(settings_params["auto_approve_value"]),
      "delay_ms" => parse_non_negative_int(settings_params["delay_ms"], 0)
    }

    case FeatureFlags.update_flag_setting(socket.assigns.selected_setting, %{
           settings: new_settings
         }) do
      {:ok, _updated} ->
        socket =
          socket
          |> assign(
            photo_flags: FeatureFlags.get_all_photo_flags(),
            selected_flag: nil,
            form: nil
          )
          |> put_flash(:info, gettext("Settings saved."))

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save settings."))}
    end
  end

  def handle_event("open-system-setting", %{"setting" => setting_name}, socket) do
    setting_atom = String.to_existing_atom(setting_name)
    setting = Enum.find(socket.assigns.system_settings, fn s -> s.name == setting_atom end)

    form_data = %{
      "value" => setting.current_value
    }

    {:noreply,
     assign(socket,
       selected_system_setting: setting,
       system_form: to_form(form_data, as: "system_setting")
     )}
  end

  def handle_event("close-system-modal", _params, socket) do
    {:noreply, assign(socket, selected_system_setting: nil, system_form: nil)}
  end

  def handle_event("save-system-setting", %{"system_setting" => params}, socket) do
    setting = socket.assigns.selected_system_setting
    value = parse_system_setting_value(params["value"], setting)

    flag_name = "system:#{setting.name}"

    {:ok, flag_setting} =
      FeatureFlags.get_or_create_flag_setting(flag_name, %{
        description: setting.description,
        settings: %{value: setting.default_value}
      })

    case FeatureFlags.update_flag_setting(flag_setting, %{settings: %{value: value}}) do
      {:ok, _updated} ->
        socket =
          socket
          |> assign(
            system_settings: FeatureFlags.get_all_system_settings(),
            selected_system_setting: nil,
            system_form: nil
          )
          |> put_flash(:info, gettext("Setting saved."))

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save setting."))}
    end
  end

  def handle_event("open-ollama-setting", %{"setting" => setting_name}, socket) do
    setting_atom = String.to_existing_atom(setting_name)
    setting = Enum.find(socket.assigns.ollama_settings, fn s -> s.name == setting_atom end)

    form_data =
      case setting.type do
        :flag ->
          # Get or create the setting for flags
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
        value = parse_ollama_setting_value(params["value"], setting)
        flag_name = "system:#{setting.name}"

        {:ok, flag_setting} =
          FeatureFlags.get_or_create_flag_setting(flag_name, %{
            description: setting.description,
            settings: %{value: setting.default_value}
          })

        case FeatureFlags.update_flag_setting(flag_setting, %{settings: %{value: value}}) do
          {:ok, _updated} ->
            socket =
              socket
              |> assign(
                ollama_settings: FeatureFlags.get_all_ollama_settings(),
                selected_ollama_setting: nil,
                ollama_form: nil
              )
              |> put_flash(:info, gettext("Setting saved."))

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, gettext("Could not save setting."))}
        end
    end
  end

  # --- Private Helpers ---

  defp parse_auto_approve_value("true"), do: true
  defp parse_auto_approve_value("false"), do: false
  defp parse_auto_approve_value(""), do: nil
  defp parse_auto_approve_value(nil), do: nil
  defp parse_auto_approve_value(value), do: value

  defp parse_system_setting_value(value, %{type: :string}) do
    value |> to_string() |> String.trim()
  end

  defp parse_system_setting_value(value, setting) do
    # Integer type (default)
    parsed = parse_non_negative_int(value, setting.default_value)
    max(setting.min_value, min(setting.max_value, parsed))
  end

  defp parse_ollama_setting_value(value, %{type: :string}) do
    value |> to_string() |> String.trim()
  end

  defp parse_ollama_setting_value(value, setting) do
    # Integer type
    parsed = parse_non_negative_int(value, setting.default_value)
    max(setting.min_value, min(setting.max_value, parsed))
  end

  defp matches_search?(_item, query) when query == "", do: true

  defp matches_search?(item, query) do
    query = String.downcase(query)
    name = item.name |> to_string() |> String.downcase()
    label = item.label |> String.downcase()
    description = item.description |> String.downcase()

    String.contains?(name, query) ||
      String.contains?(label, query) ||
      String.contains?(description, query)
  end

  defp filter_by_search(items, query) when query == "", do: items
  defp filter_by_search(items, query), do: Enum.filter(items, &matches_search?(&1, query))

  @impl true
  def render(assigns) do
    # Filter items by search query
    assigns =
      assigns
      |> assign(
        :filtered_ollama_settings,
        filter_by_search(assigns.ollama_settings, assigns.search_query)
      )
      |> assign(
        :filtered_photo_flags,
        filter_by_search(assigns.photo_flags, assigns.search_query)
      )
      |> assign(
        :filtered_system_settings,
        filter_by_search(assigns.system_settings, assigns.search_query)
      )
      |> assign(
        :filtered_admin_flags,
        filter_by_search(assigns.admin_flags, assigns.search_query)
      )

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Feature Flags")}</h1>
          <p class="text-base-content/70 mt-1">
            {gettext("Control feature flags and system settings.")}
          </p>
        </div>

        <%!-- Search Input --%>
        <div class="mb-6">
          <div class="relative">
            <.icon
              name="hero-magnifying-glass"
              class="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-base-content/40"
            />
            <input
              type="text"
              placeholder={gettext("Search flags and settings...")}
              value={@search_query}
              phx-keyup="search"
              phx-debounce="150"
              name="query"
              class="input input-bordered w-full pl-10 pr-10"
            />
            <%= if @search_query != "" do %>
              <button
                type="button"
                phx-click="clear-search"
                class="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/40 hover:text-base-content"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>
            <% end %>
          </div>
        </div>

        <%= if @search_query != "" && Enum.empty?(@filtered_ollama_settings) && Enum.empty?(@filtered_photo_flags) && Enum.empty?(@filtered_system_settings) && Enum.empty?(@filtered_admin_flags) do %>
          <div class="text-center py-12">
            <.icon name="hero-magnifying-glass" class="h-12 w-12 text-base-content/30 mx-auto mb-4" />
            <p class="text-base-content/60">
              {gettext("No results found for \"%{query}\"", query: @search_query)}
            </p>
          </div>
        <% else %>
          <%!-- AI/Ollama Section --%>
          <%= if Enum.any?(@filtered_ollama_settings) do %>
            <div class="mb-8">
              <div class="flex items-center gap-3 mb-4">
                <div class="p-2 rounded-lg bg-purple-500/10">
                  <.icon name="hero-cpu-chip" class="h-5 w-5 text-purple-600" />
                </div>
                <div>
                  <h2 class="text-lg font-semibold text-base-content">{gettext("AI / Ollama")}</h2>
                  <p class="text-sm text-base-content/50">
                    {gettext("Photo analysis and debug settings")}
                  </p>
                </div>
              </div>

              <div class="space-y-3">
                <%= for setting <- @filtered_ollama_settings do %>
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
                        <label class="swap swap-flip">
                          <input
                            type="checkbox"
                            checked={setting.enabled}
                            phx-click="toggle-ollama-flag"
                            phx-value-flag={setting.name}
                          />
                          <div class={[
                            "swap-on flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium",
                            "bg-success/20 text-success"
                          ]}>
                            <.icon name="hero-check-circle-mini" class="h-4 w-4" />
                            {gettext("On")}
                          </div>
                          <div class={[
                            "swap-off flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium",
                            "bg-base-300 text-base-content/50"
                          ]}>
                            <.icon name="hero-x-circle-mini" class="h-4 w-4" />
                            {gettext("Off")}
                          </div>
                        </label>
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
            </div>
          <% end %>

          <%!-- Photo Processing Section --%>
          <%= if Enum.any?(@filtered_photo_flags) do %>
            <div class="mb-8">
              <div class="flex items-center gap-3 mb-4">
                <div class="p-2 rounded-lg bg-blue-500/10">
                  <.icon name="hero-photo" class="h-5 w-5 text-blue-600" />
                </div>
                <div>
                  <h2 class="text-lg font-semibold text-base-content">
                    {gettext("Photo Processing")}
                  </h2>
                  <p class="text-sm text-base-content/50">{gettext("Image validation and checks")}</p>
                </div>
              </div>

              <div class="space-y-3">
                <%= for flag <- @filtered_photo_flags do %>
                  <div
                    class="border border-base-300 rounded-xl p-4 flex items-center justify-between hover:border-blue-300 transition-colors shadow-sm"
                    data-flag={flag.name}
                  >
                    <div class="flex-1">
                      <div class="flex items-center gap-2">
                        <span class="font-medium text-base-content">{flag.label}</span>
                        <%= if flag.setting && flag.setting.settings["delay_ms"] && flag.setting.settings["delay_ms"] > 0 do %>
                          <span class="badge badge-sm badge-warning">
                            {flag.setting.settings["delay_ms"]}ms
                          </span>
                        <% end %>
                        <%= if flag.setting && flag.setting.settings["auto_approve"] do %>
                          <span class="badge badge-sm badge-info">{gettext("Auto")}</span>
                        <% end %>
                      </div>
                      <p class="text-sm text-base-content/60 mt-1">{flag.description}</p>
                    </div>

                    <div class="flex items-center gap-3">
                      <button
                        type="button"
                        class="btn btn-ghost btn-sm"
                        phx-click="open-settings"
                        phx-value-flag={flag.name}
                      >
                        <.icon name="hero-cog-6-tooth" class="h-4 w-4" />
                      </button>

                      <label class="swap swap-flip">
                        <input
                          type="checkbox"
                          checked={flag.enabled}
                          phx-click="toggle-flag"
                          phx-value-flag={flag.name}
                        />
                        <div class={[
                          "swap-on flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium",
                          "bg-success/20 text-success"
                        ]}>
                          <.icon name="hero-check-circle-mini" class="h-4 w-4" />
                          {gettext("On")}
                        </div>
                        <div class={[
                          "swap-off flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium",
                          "bg-base-300 text-base-content/50"
                        ]}>
                          <.icon name="hero-x-circle-mini" class="h-4 w-4" />
                          {gettext("Off")}
                        </div>
                      </label>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <%!-- System Settings Section --%>
          <%= if Enum.any?(@filtered_system_settings) do %>
            <div class="mb-8">
              <div class="flex items-center gap-3 mb-4">
                <div class="p-2 rounded-lg bg-base-300/50">
                  <.icon name="hero-cog-8-tooth" class="h-5 w-5 text-base-content/70" />
                </div>
                <div>
                  <h2 class="text-lg font-semibold text-base-content">
                    {gettext("System Settings")}
                  </h2>
                  <p class="text-sm text-base-content/50">{gettext("Application configuration")}</p>
                </div>
              </div>

              <div class="space-y-3">
                <%= for setting <- @filtered_system_settings do %>
                  <div
                    class="border border-base-300 rounded-xl p-4 flex items-center justify-between hover:border-base-400 transition-colors shadow-sm"
                    data-setting={setting.name}
                  >
                    <div class="flex-1">
                      <div class="flex items-center gap-2">
                        <span class="font-medium text-base-content">{setting.label}</span>
                        <span class="badge badge-sm badge-primary">{setting.current_value}</span>
                      </div>
                      <p class="text-sm text-base-content/60 mt-1">{setting.description}</p>
                      <%= if setting[:type] == :string do %>
                        <p class="text-xs text-base-content/40 mt-1">
                          {gettext("Default: %{default}", default: setting.default_value)}
                        </p>
                      <% else %>
                        <p class="text-xs text-base-content/40 mt-1">
                          {gettext("Default: %{default}, Range: %{min}-%{max}",
                            default: setting.default_value,
                            min: setting.min_value,
                            max: setting.max_value
                          )}
                        </p>
                      <% end %>
                    </div>

                    <div class="flex items-center gap-3">
                      <button
                        type="button"
                        class="btn btn-ghost btn-sm"
                        phx-click="open-system-setting"
                        phx-value-setting={setting.name}
                      >
                        <.icon name="hero-pencil" class="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <%!-- Admin Flags Section --%>
          <%= if Enum.any?(@filtered_admin_flags) do %>
            <div class="mb-8">
              <div class="flex items-center gap-3 mb-4">
                <div class="p-2 rounded-lg bg-amber-500/10">
                  <.icon name="hero-shield-check" class="h-5 w-5 text-amber-600" />
                </div>
                <div>
                  <h2 class="text-lg font-semibold text-base-content">{gettext("Admin Flags")}</h2>
                  <p class="text-sm text-base-content/50">{gettext("Administrative capabilities")}</p>
                </div>
              </div>

              <div class="space-y-3">
                <%= for flag <- @filtered_admin_flags do %>
                  <div
                    class="border border-base-300 rounded-xl p-4 flex items-center justify-between hover:border-amber-300 transition-colors shadow-sm"
                    data-flag={flag.name}
                  >
                    <div class="flex-1">
                      <div class="flex items-center gap-2">
                        <span class="font-medium text-base-content">{flag.label}</span>
                      </div>
                      <p class="text-sm text-base-content/60 mt-1">{flag.description}</p>
                    </div>

                    <div class="flex items-center gap-3">
                      <label class="swap swap-flip">
                        <input
                          type="checkbox"
                          checked={flag.enabled}
                          phx-click="toggle-admin-flag"
                          phx-value-flag={flag.name}
                        />
                        <div class={[
                          "swap-on flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium",
                          "bg-success/20 text-success"
                        ]}>
                          <.icon name="hero-check-circle-mini" class="h-4 w-4" />
                          {gettext("On")}
                        </div>
                        <div class={[
                          "swap-off flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium",
                          "bg-base-300 text-base-content/50"
                        ]}>
                          <.icon name="hero-x-circle-mini" class="h-4 w-4" />
                          {gettext("Off")}
                        </div>
                      </label>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <%!-- Usage Info --%>
          <div class="bg-base-200/50 rounded-lg p-4 border border-base-300">
            <h3 class="font-medium text-base-content mb-2">{gettext("How it works")}</h3>
            <ul class="text-sm text-base-content/70 space-y-1 list-disc list-inside">
              <li>{gettext("Toggle switches enable/disable processing steps")}</li>
              <li>{gettext("Auto-approve skips the check and returns a preset value")}</li>
              <li>{gettext("Delays simulate slow processing for UX testing")}</li>
            </ul>
          </div>
        <% end %>

        <%!-- Settings Modal (for photo flags) --%>
        <%= if @selected_flag do %>
          <div
            class="modal modal-open"
            id="settings-modal"
            phx-window-keydown="close-modal"
            phx-key="escape"
          >
            <div class="modal-box">
              <button
                type="button"
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
                phx-click="close-modal"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>

              <h3 class="font-bold text-lg mb-4">
                {@selected_flag.label} {gettext("Settings")}
              </h3>

              <.form for={@form} id="settings-form" phx-submit="save-settings" class="space-y-4">
                <div class="form-control">
                  <label class="label cursor-pointer justify-start gap-3">
                    <input
                      type="checkbox"
                      name="settings[auto_approve]"
                      value="true"
                      checked={
                        @form[:auto_approve].value == true || @form[:auto_approve].value == "true"
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

                <%= if @selected_flag.default_auto_approve_value != nil do %>
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text">{gettext("Auto-approve value")}</span>
                    </label>
                    <select name="settings[auto_approve_value]" class="select select-bordered">
                      <option value="true" selected={@form[:auto_approve_value].value == true}>
                        true
                      </option>
                      <option value="false" selected={@form[:auto_approve_value].value == false}>
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
                    name="settings[delay_ms]"
                    value={@form[:delay_ms].value}
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

                <div class="modal-action">
                  <button type="button" class="btn btn-ghost" phx-click="close-modal">
                    {gettext("Cancel")}
                  </button>
                  <button type="submit" class="btn btn-primary">
                    {gettext("Save")}
                  </button>
                </div>
              </.form>
            </div>
            <div class="modal-backdrop" phx-click="close-modal"></div>
          </div>
        <% end %>

        <%!-- System Setting Modal --%>
        <%= if @selected_system_setting do %>
          <div
            class="modal modal-open"
            id="system-setting-modal"
            phx-window-keydown="close-system-modal"
            phx-key="escape"
          >
            <div class="modal-box">
              <button
                type="button"
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
                phx-click="close-system-modal"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>

              <h3 class="font-bold text-lg mb-4">
                {@selected_system_setting.label}
              </h3>

              <p class="text-sm text-base-content/70 mb-4">
                {@selected_system_setting.description}
              </p>

              <.form
                for={@system_form}
                id="system-setting-form"
                phx-submit="save-system-setting"
                class="space-y-4"
              >
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">{gettext("Value")}</span>
                  </label>
                  <%= if @selected_system_setting[:type] == :string do %>
                    <input
                      type="text"
                      name="system_setting[value]"
                      value={@system_form[:value].value}
                      class="input input-bordered"
                    />
                    <label class="label">
                      <span class="label-text-alt text-base-content/50">
                        {gettext("Default: %{default}",
                          default: @selected_system_setting.default_value
                        )}
                      </span>
                    </label>
                  <% else %>
                    <input
                      type="number"
                      name="system_setting[value]"
                      value={@system_form[:value].value}
                      min={@selected_system_setting.min_value}
                      max={@selected_system_setting.max_value}
                      class="input input-bordered"
                    />
                    <label class="label">
                      <span class="label-text-alt text-base-content/50">
                        {gettext("Default: %{default}, Range: %{min}-%{max}",
                          default: @selected_system_setting.default_value,
                          min: @selected_system_setting.min_value,
                          max: @selected_system_setting.max_value
                        )}
                      </span>
                    </label>
                  <% end %>
                </div>

                <div class="modal-action">
                  <button type="button" class="btn btn-ghost" phx-click="close-system-modal">
                    {gettext("Cancel")}
                  </button>
                  <button type="submit" class="btn btn-primary">
                    {gettext("Save")}
                  </button>
                </div>
              </.form>
            </div>
            <div class="modal-backdrop" phx-click="close-system-modal"></div>
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
