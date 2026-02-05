defmodule AniminaWeb.Admin.FeatureFlagsLive do
  use AniminaWeb, :live_view

  alias Animina.FeatureFlags

  import AniminaWeb.Helpers.AdminHelpers, only: [parse_non_negative_int: 2]

  @impl true
  def mount(_params, _session, socket) do
    flags = FeatureFlags.get_all_photo_flags()
    system_settings = FeatureFlags.get_all_system_settings()
    debug_flags = FeatureFlags.get_all_debug_flags()
    admin_flags = FeatureFlags.get_all_admin_flags()

    {:ok,
     assign(socket,
       page_title: gettext("Feature Flags"),
       photo_flags: flags,
       system_settings: system_settings,
       debug_flags: debug_flags,
       admin_flags: admin_flags,
       selected_flag: nil,
       selected_system_setting: nil,
       form: nil,
       system_form: nil
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

  def handle_event("toggle-debug-flag", %{"flag" => flag_name}, socket) do
    flag_atom = String.to_existing_atom(flag_name)

    if FeatureFlags.enabled?(flag_atom) do
      FeatureFlags.disable(flag_atom)
    else
      FeatureFlags.enable(flag_atom)
    end

    {:noreply, assign(socket, debug_flags: FeatureFlags.get_all_debug_flags())}
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl px-4 py-8">
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Feature Flags")}</h1>
          <p class="text-base-content/70 mt-1">
            {gettext("Control feature flags and system settings.")}
          </p>
        </div>

        <%!-- Photo Processing Section --%>
        <div class="mb-8">
          <h2 class="text-lg font-semibold text-base-content mb-4 flex items-center gap-2">
            <.icon name="hero-photo" class="h-5 w-5" />
            {gettext("Photo Processing")}
          </h2>

          <div class="space-y-3">
            <%= for flag <- @photo_flags do %>
              <div
                class="bg-base-200 rounded-lg p-4 flex items-center justify-between"
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

        <%!-- System Settings Section --%>
        <div class="mb-8">
          <h2 class="text-lg font-semibold text-base-content mb-4 flex items-center gap-2">
            <.icon name="hero-cog-8-tooth" class="h-5 w-5" />
            {gettext("System Settings")}
          </h2>

          <div class="space-y-3">
            <%= for setting <- @system_settings do %>
              <div
                class="bg-base-200 rounded-lg p-4 flex items-center justify-between"
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

        <%!-- Debug Flags Section --%>
        <div class="mb-8">
          <h2 class="text-lg font-semibold text-base-content mb-4 flex items-center gap-2">
            <.icon name="hero-bug-ant" class="h-5 w-5" />
            {gettext("Debug Flags")}
          </h2>

          <div class="space-y-3">
            <%= for flag <- @debug_flags do %>
              <div
                class="bg-base-200 rounded-lg p-4 flex items-center justify-between"
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
                      phx-click="toggle-debug-flag"
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

        <%!-- Admin Flags Section --%>
        <div class="mb-8">
          <h2 class="text-lg font-semibold text-base-content mb-4 flex items-center gap-2">
            <.icon name="hero-shield-check" class="h-5 w-5" />
            {gettext("Admin Flags")}
          </h2>

          <div class="space-y-3">
            <%= for flag <- @admin_flags do %>
              <div
                class="bg-base-200 rounded-lg p-4 flex items-center justify-between"
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

        <%!-- Usage Info --%>
        <div class="bg-base-200/50 rounded-lg p-4 border border-base-300">
          <h3 class="font-medium text-base-content mb-2">{gettext("How it works")}</h3>
          <ul class="text-sm text-base-content/70 space-y-1 list-disc list-inside">
            <li>{gettext("Toggle switches enable/disable processing steps")}</li>
            <li>{gettext("Auto-approve skips the check and returns a preset value")}</li>
            <li>{gettext("Delays simulate slow processing for UX testing")}</li>
          </ul>
        </div>

        <%!-- Settings Modal --%>
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
      </div>
    </Layouts.app>
    """
  end
end
