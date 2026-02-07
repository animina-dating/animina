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
      live "/", DemoIndex2Live
      live "/demo", DemoLive
      live "/debug", DebugLive
      live "/datenschutz", PrivacyPolicyLive
      live "/agb", TermsOfServiceLive
      live "/impressum", ImpressumLive
      live "/moodboard/:user_id", UserLive.ProfileMoodboard
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
      live "/my-profile", UserLive.ProfileHub, :index
      live "/users/settings", UserLive.SettingsHub, :index
      live "/users/settings/account", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/users/settings/profile", UserLive.EditProfile, :edit
      live "/users/settings/preferences", UserLive.EditPreferences, :edit
      live "/users/settings/language", UserLive.LanguageSettings, :edit
      live "/users/settings/locations", UserLive.EditLocations, :edit
      live "/users/settings/traits", UserLive.TraitsWizard, :index
      live "/users/settings/passkeys", UserLive.PasskeySettings, :index
      live "/users/settings/delete-account", UserLive.DeleteAccount, :delete
      live "/users/settings/avatar", UserLive.AvatarUpload, :edit
      live "/users/settings/moodboard", UserLive.MoodboardEditor
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
      live "/admin/ollama-logs", Admin.OllamaLogsLive
    end

    post "/role/switch", RoleController, :switch
    post "/users/update-password", UserSessionController, :update_password

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
  end
end
