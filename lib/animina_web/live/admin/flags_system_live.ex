defmodule AniminaWeb.Admin.FlagsSystemLive do
  use AniminaWeb, :live_view

  alias Animina.FeatureFlags
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.FeatureFlagHelpers,
    only: [search_bar: 1, filter_by_search: 2, save_value_setting: 4]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("System Settings"),
       system_settings: FeatureFlags.get_all_system_settings(),
       search_query: "",
       selected_system_setting: nil,
       system_form: nil
     )}
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: String.trim(query))}
  end

  def handle_event("clear-search", _params, socket) do
    {:noreply, assign(socket, search_query: "")}
  end

  def handle_event("open-system-setting", %{"setting" => setting_name}, socket) do
    setting_atom = String.to_existing_atom(setting_name)
    setting = Enum.find(socket.assigns.system_settings, fn s -> s.name == setting_atom end)

    form_data = %{"value" => setting.current_value}

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

    save_value_setting(socket, setting, params["value"],
      refresh: [system_settings: FeatureFlags.get_all_system_settings()],
      clear: [selected_system_setting: nil, system_form: nil]
    )
  end

  # --- Render ---

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :filtered_settings,
        filter_by_search(assigns.system_settings, assigns.search_query)
      )

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <.breadcrumb_nav>
          <:crumb navigate={~p"/admin"}>{gettext("Admin")}</:crumb>
          <:crumb navigate={~p"/admin/flags"}>{gettext("Feature Flags")}</:crumb>
          <:crumb>{gettext("System Settings")}</:crumb>
        </.breadcrumb_nav>

        <h1 class="text-2xl font-bold text-base-content mb-2">{gettext("System Settings")}</h1>
        <p class="text-base-content/70 mb-6">{gettext("Application configuration")}</p>

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
      </div>
    </Layouts.app>
    """
  end
end
