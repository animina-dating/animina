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
    plug :fetch_current_scope_for_user
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
      on_mount: [{AniminaWeb.UserAuth, :mount_current_scope}] do
      live "/", IndexLive
      live "/debug", DebugLive
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
      on_mount: [{AniminaWeb.UserAuth, :require_authenticated}] do
      live "/users/accept-terms", UserLive.AcceptTerms
    end

    live_session :require_authenticated_user,
      on_mount: [{AniminaWeb.UserAuth, :require_authenticated_with_tos}] do
      # Settings hub
      live "/settings", UserLive.SettingsHub, :index

      # Profile hub + nested sub-pages
      live "/settings/profile", UserLive.ProfileHub, :index
      live "/settings/profile/photo", UserLive.AvatarUpload, :edit
      live "/settings/profile/info", UserLive.EditProfile, :edit
      live "/settings/profile/moodboard", UserLive.MoodboardEditor
      live "/settings/profile/traits", UserLive.TraitsWizard, :index
      live "/settings/profile/preferences", UserLive.EditPreferences, :edit
      live "/settings/profile/locations", UserLive.EditLocations, :edit

      # Account & Security hub + sub-pages
      live "/settings/account", UserLive.AccountHub, :index
      live "/settings/account/email-password", UserLive.AccountEmailPassword, :edit
      live "/settings/account/passkeys", UserLive.AccountPasskeys, :index
      live "/settings/account/sessions", UserLive.AccountSessions, :index
      live "/settings/account/delete", UserLive.AccountDelete, :index
      live "/settings/confirm-email/:token", UserLive.AccountEmailPassword, :confirm_email

      # Privacy
      live "/settings/privacy", UserLive.PrivacySettings, :index
      live "/settings/blocked-contacts", UserLive.BlockedContacts, :index

      # Language
      live "/settings/language", UserLive.LanguageSettings, :edit

      # Logs
      live "/logs", UserLive.LogsHub, :index
      live "/logs/emails", UserLive.EmailLogs, :index

      live "/users/waitlist", UserLive.Waitlist
      live "/discover", DiscoverLive
      live "/messages", MessagesLive, :index
      live "/messages/:conversation_id", MessagesLive, :show
    end

    live_session :require_moderator,
      on_mount: [{AniminaWeb.UserAuth, :require_moderator}] do
      live "/admin/photo-reviews", Admin.PhotoReviewsLive
    end

    live_session :require_admin,
      on_mount: [{AniminaWeb.UserAuth, :require_admin}] do
      live "/admin/roles", Admin.UserRolesLive
      live "/admin/photos/:id/history", Admin.PhotoHistoryLive
      live "/admin/feature-flags", Admin.FeatureFlagsLive
      live "/admin/photo-blacklist", Admin.PhotoBlacklistLive
      live "/admin/logs", Admin.LogsIndexLive
      live "/admin/logs/emails", Admin.EmailLogsLive
      live "/admin/logs/ollama", Admin.OllamaLogsLive
      live "/admin/logs/activity", Admin.ActivityLogsLive
    end

    post "/role/switch", RoleController, :switch
    post "/settings/update-password", UserSessionController, :update_password

    # WebAuthn passkey registration (requires authentication)
    post "/webauthn/register/begin", WebAuthnController, :register_begin
    post "/webauthn/register/complete", WebAuthnController, :register_complete
  end

  scope "/", AniminaWeb do
    pipe_through :browser

    live_session :current_user,
      on_mount: [{AniminaWeb.UserAuth, :mount_current_scope}] do
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

    # Legacy redirects (301 permanent) — must be before /users/:user_id catch-all
    get "/users/settings", LegacyRedirectController, :settings_root
    get "/users/settings/*path", LegacyRedirectController, :settings
    get "/moodboard/:user_id", LegacyRedirectController, :moodboard

    # User profile (after literal auth routes and legacy redirects so they match first)
    live_session :user_profile,
      on_mount: [{AniminaWeb.UserAuth, :mount_current_scope}] do
      live "/users/:user_id", UserLive.ProfileMoodboard
    end
  end
end
