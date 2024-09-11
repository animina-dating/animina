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

    ash_authentication_live_session :authentication_optional,
      on_mount: {AniminaWeb.LiveUserAuth, :live_no_user} do
      live "/sign-in", RootLive, :sign_in
      live "/reset-password", RequestPasswordLive, :index
    end

    ash_authentication_live_session :authentication_required_for_email_validation,
      on_mount: {AniminaWeb.LiveUserAuth, :live_user_required_for_validation} do
      live "/my/email-validation", EmailValidationLive, :index
    end

    ash_authentication_live_session :authentication_required_for_too_successful,
      on_mount: {AniminaWeb.LiveUserAuth, :live_user_required_for_too_successful} do
      live "/my/too-successful", TooSuccessFulLive, :index
    end

    ash_authentication_live_session :live_authentication_required,
      on_mount: {AniminaWeb.LiveUserAuth, :live_admin_required} do
      live "/admin/waitlist", WaitlistLive, :index
      live "/admin/reports/all", AllReportsLive, :index
      live "/admin/reports/pending", PendingReportsLive, :index
      live "/admin/reports/:id", ShowReportLive, :index
      live "/admin/reports/pending/:id/review", ReviewReportLive, :index
    end

    ash_authentication_live_session :authentication_required,
      on_mount: {AniminaWeb.LiveUserAuth, :live_user_required} do
      live "/my/potential-partner", PotentialPartnerLive, :index
      live "/my/profile-photo", ProfilePhotoLive, :index
      live "/my/profile/edit", UpdateProfileLive, :index
      live "/my/flags/white", FlagsLive, :white
      live "/my/flags/green", FlagsLive, :green
      live "/my/flags/red", FlagsLive, :red
      live "/my/about-me", StoryLive, :about_me
      live "/my/profile/visibility", ProfileVisibilityLive, :index
      live "/my/profile/delete_account", DeleteAccountLive, :index
    end

    ash_authentication_live_session :authentication_required_and_about_me_story,
      on_mount: {AniminaWeb.LiveUserAuth, :live_user_required_with_about_me_story} do
      live "/my/stories/new", StoryLive, :new
      live "/my/stories/:id/edit", StoryLive, :edit
      live "/my/posts/new", PostLive, :new
      live "/my/posts/:id/edit", PostLive, :edit
      live "/my/bookmarks", BookmarksLive, :bookmarks
      live "/my/bookmarks/:filter_type", BookmarksLive, :bookmarks
      live "/my/messages/:profile", ChatLive, :index
      live "/my", DashboardLive, :index
      live "/my/dashboard", DashboardLive, :index
      live "/:current_user/messages/:profile", ChatLive, :index
      live "/:username/report", ProfileLive, :report
    end

    ash_authentication_live_session :user_optional,
      on_mount: {AniminaWeb.LiveUserAuth, :live_user_home_optional} do
      live "/", RootLive, :register
    end

    ash_authentication_live_session :user_optional_home,
      on_mount: {AniminaWeb.LiveUserAuth, :live_user_optional} do
      live "/:username", ProfileLive
      live "/my/profile", ProfileLive
      live "/:username/:year/:month/:day/:slug", PostViewLive
    end

    post "/auth/user/sign_in/", AuthController, :sign_in
    post "/auth/user/request_password", AuthController, :request_password

    sign_out_route AuthController, "/auth/user/sign-out"
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
