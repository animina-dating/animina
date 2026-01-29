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
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AniminaWeb do
    pipe_through :browser

    live_session :public,
      on_mount: [{AniminaWeb.UserAuth, :mount_current_scope}] do
      live "/", DemoIndex2Live
      live "/demo", DemoLive
      live "/demo/mission_statement", DemoMissionStatementLive
    end
  end

  # Health check endpoint (excluded from force_ssl in prod.exs)
  scope "/", AniminaWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", AniminaWeb do
  #   pipe_through :api
  # end

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
  end

  ## Authentication routes

  scope "/", AniminaWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{AniminaWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/users/waitlist", UserLive.Waitlist
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", AniminaWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{AniminaWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/confirm/:token", UserLive.PinConfirmation
      live "/users/forgot-password", UserLive.ForgotPassword
      live "/users/reset-password/:token", UserLive.ResetPassword
    end

    post "/users/log-in", UserSessionController, :create
    post "/users/log-in/pin-confirmed", UserSessionController, :create_from_pin
    delete "/users/log-out", UserSessionController, :delete
  end
end
