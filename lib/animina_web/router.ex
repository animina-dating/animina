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

    # get "/", PageController, :home
    live "/", RootLive, :register
    live "/registration/potential-partner", PotentialPartnerLive, :index
    live "/registration/profile-photo", ProfilePhotoLive, :index
    live "/registration/white-flags", FlagsLive, :white
    live "/registration/green-flags", FlagsLive, :green
    live "/registration/red-flags", FlagsLive, :red
    # live "/register", AniminaWeb.AuthLive.Index, :register
    live "/sign-in", AniminaWeb.AuthLive.Index, :sign_in

    get "/demo", PageController, :demo
    # get "/register", AuthController, :register

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
