defmodule AniminaWeb.Router do
  use AniminaWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AniminaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
    plug AniminaWeb.Plugs.AcceptLanguage
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  scope "/", AniminaWeb do
    pipe_through :browser

    ash_authentication_live_session :user_optional,
      on_mount: {AniminaWeb.LiveUserAuth, :live_user_optional} do
      live "/", RootLive, :register
    end

    ash_authentication_live_session :authentication_optional,
      on_mount: {AniminaWeb.LiveUserAuth, :live_no_user} do
      live "/sign-in", RootLive, :sign_in
    end

    ash_authentication_live_session :authentication_required,
      on_mount: {AniminaWeb.LiveUserAuth, :live_user_required} do
      live "/profile/potential-partner", PotentialPartnerLive, :index
      live "/profile/profile-photo", ProfilePhotoLive, :index
      live "/profile/white-flags", FlagsLive, :white
      live "/profile/green-flags", FlagsLive, :green
      live "/profile/red-flags", FlagsLive, :red
      live "/profile/create-story", StoryLive, :new
      live "/profile/edit-story/:id", StoryLive, :edit
      live "/profile/about-me", StoryLive, :about_me
      live "/:username", ProfileLive
    end

    get "/demo", PageController, :demo

    sign_out_route AuthController
    auth_routes_for Animina.Accounts.User, to: AuthController
    reset_route []
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
end
