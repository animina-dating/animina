defmodule AniminaWeb.Admin.FlagsIndexLive do
  use AniminaWeb, :live_view

  alias Animina.FeatureFlags
  alias AniminaWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    ollama_count = length(FeatureFlags.ollama_settings_definitions())
    system_count = length(FeatureFlags.system_setting_definitions())
    discovery_count = length(FeatureFlags.discovery_settings_definitions())

    {:ok,
     assign(socket,
       page_title: gettext("Feature Flags"),
       ollama_count: ollama_count,
       system_count: system_count,
       discovery_count: discovery_count
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.page_header
          title={gettext("Feature Flags")}
          subtitle={gettext("Control feature flags and system settings.")}
        >
          <:crumb navigate={~p"/admin"}>{gettext("Admin")}</:crumb>
        </.page_header>

        <div class="grid gap-4">
          <.hub_card
            navigate={~p"/admin/flags/ai"}
            title={gettext("AI / Ollama")}
            subtitle={gettext("Photo analysis and debug settings")}
            icon="hero-cpu-chip"
            icon_class="h-8 w-8"
            padding="p-5"
          >
            <:trailing>
              <span class="badge badge-lg badge-outline font-mono">
                {@ollama_count}
              </span>
            </:trailing>
          </.hub_card>

          <.hub_card
            navigate={~p"/admin/flags/system"}
            title={gettext("System Settings")}
            subtitle={gettext("Application configuration")}
            icon="hero-cog-8-tooth"
            icon_class="h-8 w-8"
            padding="p-5"
          >
            <:trailing>
              <span class="badge badge-lg badge-outline font-mono">
                {@system_count}
              </span>
            </:trailing>
          </.hub_card>

          <.hub_card
            navigate={~p"/admin/flags/discovery"}
            title={gettext("Discovery / Matching")}
            subtitle={gettext("Partner suggestion algorithm tuning")}
            icon="hero-sparkles"
            icon_class="h-8 w-8"
            padding="p-5"
          >
            <:trailing>
              <span class="badge badge-lg badge-outline font-mono">
                {@discovery_count}
              </span>
            </:trailing>
          </.hub_card>
        </div>

        <div class="bg-base-200/50 rounded-lg p-4 border border-base-300 mt-8">
          <h3 class="font-medium text-base-content mb-2">{gettext("How it works")}</h3>
          <ul class="text-sm text-base-content/70 space-y-1 list-disc list-inside">
            <li>{gettext("Toggle switches enable/disable processing steps")}</li>
            <li>{gettext("Auto-approve skips the check and returns a preset value")}</li>
            <li>{gettext("Delays simulate slow processing for UX testing")}</li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
