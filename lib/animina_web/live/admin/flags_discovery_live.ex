defmodule AniminaWeb.Admin.FlagsDiscoveryLive do
  use AniminaWeb, :live_view

  alias Animina.ActivityLog
  alias Animina.FeatureFlags
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.FeatureFlagHelpers,
    only: [flag_toggle: 1, search_bar: 1, filter_by_search: 2, save_value_setting: 4]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Discovery / Matching"),
       discovery_settings: FeatureFlags.get_all_discovery_settings(),
       search_query: "",
       selected_discovery_setting: nil,
       discovery_form: nil
     )}
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("toggle-discovery-flag", %{"flag" => flag_name}, socket) do
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

    {:noreply, assign(socket, discovery_settings: FeatureFlags.get_all_discovery_settings())}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: String.trim(query))}
  end

  def handle_event("clear-search", _params, socket) do
    {:noreply, assign(socket, search_query: "")}
  end

  def handle_event("open-discovery-setting", %{"setting" => setting_name}, socket) do
    setting_atom = String.to_existing_atom(setting_name)
    setting = Enum.find(socket.assigns.discovery_settings, fn s -> s.name == setting_atom end)

    form_data = %{"value" => setting.current_value}

    {:noreply,
     assign(socket,
       selected_discovery_setting: setting,
       discovery_form: to_form(form_data, as: "discovery_setting")
     )}
  end

  def handle_event("close-discovery-modal", _params, socket) do
    {:noreply, assign(socket, selected_discovery_setting: nil, discovery_form: nil)}
  end

  def handle_event("save-discovery-setting", %{"discovery_setting" => params}, socket) do
    setting = socket.assigns.selected_discovery_setting

    save_value_setting(socket, setting, params["value"],
      refresh: [discovery_settings: FeatureFlags.get_all_discovery_settings()],
      clear: [selected_discovery_setting: nil, discovery_form: nil]
    )
  end

  # --- Render ---

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :filtered_settings,
        filter_by_search(assigns.discovery_settings, assigns.search_query)
      )

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/admin/flags"}>{gettext("Feature Flags")}</.link>
            </li>
            <li>{gettext("Discovery / Matching")}</li>
          </ul>
        </div>

        <h1 class="text-2xl font-bold text-base-content mb-2">{gettext("Discovery / Matching")}</h1>
        <p class="text-base-content/70 mb-6">
          {gettext("Partner suggestion algorithm tuning")}
        </p>

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
                class="border border-base-300 rounded-xl p-4 flex items-center justify-between hover:border-pink-300 transition-colors shadow-sm"
                data-setting={setting.name}
              >
                <div class="flex-1">
                  <div class="flex items-center gap-2">
                    <span class="font-medium text-base-content">{setting.label}</span>
                    <%= if setting.type == :flag do %>
                      <span class={[
                        "badge badge-sm",
                        if(setting.enabled, do: "badge-success", else: "badge-ghost")
                      ]}>
                        {if setting.enabled, do: gettext("On"), else: gettext("Off")}
                      </span>
                    <% else %>
                      <span class="badge badge-sm badge-primary">{setting.current_value}</span>
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
                  <%= if setting.type == :flag do %>
                    <.flag_toggle
                      checked={setting.enabled}
                      event="toggle-discovery-flag"
                      flag_name={setting.name}
                    />
                  <% else %>
                    <button
                      type="button"
                      class="btn btn-ghost btn-sm"
                      phx-click="open-discovery-setting"
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

        <%!-- Discovery Setting Modal --%>
        <%= if @selected_discovery_setting do %>
          <div
            class="modal modal-open"
            id="discovery-setting-modal"
            phx-window-keydown="close-discovery-modal"
            phx-key="escape"
          >
            <div class="modal-box">
              <button
                type="button"
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
                phx-click="close-discovery-modal"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>

              <h3 class="font-bold text-lg mb-4">
                {@selected_discovery_setting.label}
              </h3>

              <p class="text-sm text-base-content/70 mb-4">
                {@selected_discovery_setting.description}
              </p>

              <.form
                for={@discovery_form}
                id="discovery-setting-form"
                phx-submit="save-discovery-setting"
                class="space-y-4"
              >
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">{gettext("Value")}</span>
                  </label>
                  <%= if @selected_discovery_setting.type == :string do %>
                    <input
                      type="text"
                      name="discovery_setting[value]"
                      value={@discovery_form[:value].value}
                      class="input input-bordered"
                    />
                    <label class="label">
                      <span class="label-text-alt text-base-content/50">
                        {gettext("Default: %{default}",
                          default: @selected_discovery_setting.default_value
                        )}
                      </span>
                    </label>
                  <% else %>
                    <input
                      type="number"
                      name="discovery_setting[value]"
                      value={@discovery_form[:value].value}
                      min={@selected_discovery_setting.min_value}
                      max={@selected_discovery_setting.max_value}
                      class="input input-bordered"
                    />
                    <label class="label">
                      <span class="label-text-alt text-base-content/50">
                        {gettext("Default: %{default}, Range: %{min}-%{max}",
                          default: @selected_discovery_setting.default_value,
                          min: @selected_discovery_setting.min_value,
                          max: @selected_discovery_setting.max_value
                        )}
                      </span>
                    </label>
                  <% end %>
                </div>

                <div class="modal-action">
                  <button type="button" class="btn btn-ghost" phx-click="close-discovery-modal">
                    {gettext("Cancel")}
                  </button>
                  <button type="submit" class="btn btn-primary">
                    {gettext("Save")}
                  </button>
                </div>
              </.form>
            </div>
            <div class="modal-backdrop" phx-click="close-discovery-modal"></div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
