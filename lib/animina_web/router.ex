defmodule AniminaWeb.Router do
  use AniminaWeb, :router

  import AniminaWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AniminaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug AniminaWeb.Plugs.AdRedirect
    plug :fetch_current_scope_for_user
    plug AniminaWeb.Plugs.AnalyticsSession
    plug AniminaWeb.Plugs.AdSource
    plug AniminaWeb.Plugs.RequireAdminPath
    plug AniminaWeb.Plugs.SetLocale
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AniminaWeb do
    pipe_through :browser

    post "/locale", LocaleController, :update

    live_session :public,
      on_mount: [
        {AniminaWeb.UserAuth, :mount_current_scope},
        {AniminaWeb.AnalyticsHook, :track_page_view}
      ] do
      live "/", IndexLive
      live "/status", StatusLive
      live "/datenschutz", PrivacyPolicyLive
      live "/agb", TermsOfServiceLive
      live "/impressum", ImpressumLive
    end
  end

  # Photo serving with signed URLs
  scope "/", AniminaWeb do
    pipe_through :browser

    get "/photos/:signature/:filename", PhotoController, :show
  end

  # Health check endpoint (excluded from force_ssl in prod.exs)
  scope "/", AniminaWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:animina, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AniminaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/dev", AniminaWeb do
      pipe_through :browser

      post "/time-travel/add-hours", TimeMachineController, :add_hours
      post "/time-travel/add-days", TimeMachineController, :add_days
      post "/time-travel/reset", TimeMachineController, :reset
    end
  end

  ## Authentication routes

  scope "/", AniminaWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_no_tos,
      on_mount: [
        {AniminaWeb.UserAuth, :require_authenticated},
        {AniminaWeb.AnalyticsHook, :track_page_view}
      ] do
      live "/users/accept-terms", UserLive.AcceptTerms
    end

    live_session :require_authenticated_user,
      on_mount: [
        {AniminaWeb.UserAuth, :require_authenticated_with_tos},
        {AniminaWeb.AnalyticsHook, :track_page_view}
      ] do
      # Suspended/banned info page
      live "/my/suspended", UserLive.AccountSuspended

      # My hub
      live "/my", UserLive.MyHub, :index

      # Settings hub
      live "/my/settings", UserLive.SettingsHub, :index

      # Profile sub-pages (hub merged into SettingsHub; old URL still works)
      live "/my/settings/profile", UserLive.SettingsHub, :index
      live "/my/settings/profile/photo", UserLive.AvatarUpload, :edit
      live "/my/settings/profile/info", UserLive.EditProfile, :edit
      live "/my/settings/profile/moodboard", UserLive.MoodboardEditor
      live "/my/settings/profile/traits", UserLive.TraitsWizard, :index
      live "/my/settings/profile/preferences", UserLive.EditPreferences, :edit
      live "/my/settings/profile/locations", UserLive.EditLocations, :edit

      # Account & Security hub + sub-pages
      live "/my/settings/account", UserLive.AccountHub, :index
      live "/my/settings/account/email-password", UserLive.AccountEmailPassword, :edit
      live "/my/settings/account/passkeys", UserLive.AccountPasskeys, :index
      live "/my/settings/account/sessions", UserLive.AccountSessions, :index
      live "/my/settings/account/delete", UserLive.AccountDelete, :index
      live "/my/settings/confirm-email/:token", UserLive.AccountEmailPassword, :confirm_email

      # Privacy
      live "/my/settings/privacy", UserLive.PrivacySettings, :index
      live "/my/settings/blocked-contacts", UserLive.BlockedContacts, :index

      # Language
      live "/my/settings/language", UserLive.LanguageSettings, :edit

      # Logs
      live "/my/logs", UserLive.LogsHub, :index
      live "/my/logs/emails", UserLive.EmailLogs, :index
      live "/my/logs/logins", UserLive.LoginHistory, :index

      live "/my/waitlist", UserLive.Waitlist

      live "/my/spotlight", SpotlightLive

      live "/my/messages", MessagesLive, :index
      live "/my/messages/:conversation_id", MessagesLive, :show
      live "/my/relationships", RelationshipsLive, :index
    end

    live_session :require_moderator,
      on_mount: [
        {AniminaWeb.UserAuth, :require_moderator},
        {AniminaWeb.AnalyticsHook, :track_page_view}
      ] do
      live "/admin/photo-reviews", Admin.PhotoReviewsLive
      live "/admin/reports", Admin.ReportsLive
      live "/admin/reports/appeals", Admin.ReportAppealsLive
    end

    live_session :require_admin,
      on_mount: [
        {AniminaWeb.UserAuth, :require_admin},
        {AniminaWeb.AnalyticsHook, :track_page_view}
      ] do
      live "/admin", Admin.AdminHub, :index
      live "/admin/roles", Admin.UserRolesLive
      live "/admin/photos", Admin.PhotoExplorerLive
      live "/admin/photos/:id", Admin.PhotoDetailLive
      live "/admin/photos/:id/history", Admin.PhotoHistoryLive
      live "/admin/flags", Admin.FlagsIndexLive
      live "/admin/flags/ai", Admin.FlagsAiLive
      live "/admin/flags/system", Admin.FlagsSystemLive

      live "/admin/spotlight/funnel", Admin.SpotlightFunnelLive
      live "/admin/spotlight/funnel/:user_id", Admin.SpotlightFunnelLive

      live "/admin/photo-blacklist", Admin.PhotoBlacklistLive
      live "/admin/logs", Admin.LogsIndexLive
      live "/admin/logs/emails", Admin.EmailLogsLive
      live "/admin/logs/ai", Admin.AIJobsLive
      live "/admin/logs/activity", Admin.ActivityLogsLive
      live "/admin/tos-acceptances", Admin.TosAcceptancesLive

      live "/admin/ads", Admin.AdsLive
      live "/admin/ads/:id", Admin.AdDetailLive

      live "/admin/analytics", Admin.AnalyticsOverviewLive
      live "/admin/analytics/pages", Admin.AnalyticsPagesLive
      live "/admin/analytics/funnels", Admin.AnalyticsFunnelsLive
      live "/admin/analytics/engagement", Admin.AnalyticsEngagementLive
    end

    # Ad QR code serving (admin-only)
    get "/admin/ads/:id/qr-code", AdQrController, :download
    get "/admin/ads/:id/qr-code/show", AdQrController, :show

    post "/role/switch", RoleController, :switch
    post "/my/settings/update-password", UserSessionController, :update_password

    # WebAuthn passkey registration (requires authentication)
    post "/webauthn/register/begin", WebAuthnController, :register_begin
    post "/webauthn/register/complete", WebAuthnController, :register_complete
  end

  scope "/", AniminaWeb do
    pipe_through :browser

    live_session :current_user,
      on_mount: [
        {AniminaWeb.UserAuth, :mount_current_scope},
        {AniminaWeb.AnalyticsHook, :track_page_view}
      ] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/confirm/:token", UserLive.PinConfirmation
      live "/users/forgot-password", UserLive.ForgotPassword
      live "/users/reset-password/:token", UserLive.ResetPassword
      live "/users/reactivate", UserLive.ReactivateAccount, :reactivate
    end

    post "/users/log-in", UserSessionController, :create
    post "/users/log-in/pin-confirmed", UserSessionController, :create_from_pin
    delete "/users/log-out", UserSessionController, :delete

    # WebAuthn passkey authentication (public — no authentication required)
    post "/webauthn/auth/begin", WebAuthnController, :auth_begin
    post "/webauthn/auth/complete", WebAuthnController, :auth_complete

    # Security event undo/confirm (public — token from email is the auth factor)
    get "/users/security/undo/:token", SecurityEventController, :undo
    get "/users/security/confirm/:token", SecurityEventController, :confirm

    # User profile (after literal auth routes so they match first)
    live_session :user_profile,
      on_mount: [
        {AniminaWeb.UserAuth, :mount_current_scope},
        {AniminaWeb.AnalyticsHook, :track_page_view}
      ] do
      live "/users/:user_id", UserLive.ProfileMoodboard
    end
  end
end
