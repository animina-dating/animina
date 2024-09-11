defmodule AniminaWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use AniminaWeb, :controller
      use AniminaWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicons favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: true

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: AniminaWeb.Layouts]

      import Plug.Conn
      import AniminaWeb.Gettext

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {AniminaWeb.Layouts, :app}

      import Gettext, only: [with_locale: 2]

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      import Phoenix.HTML.Form
      use PhoenixHTMLHelpers
      # Core UI components and translation
      import AniminaWeb.CoreComponents
      import AniminaWeb.AniminaComponents
      import AniminaWeb.ProfileComponents
      import AniminaWeb.ChatComponents
      import AniminaWeb.StoriesComponents
      import AniminaWeb.BookmarksComponents
      import AniminaWeb.DashboardComponents
      import AniminaWeb.TopNavigationCompontents
      import AniminaWeb.Gettext
      import AniminaWeb.PostsComponents
      import AniminaWeb.ReportComponents
      import AniminaWeb.WaitlistComponents

      # https://elixirforum.com/t/form-for-not-working-in-phoenix-1-7/52013

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: AniminaWeb.Endpoint,
        router: AniminaWeb.Router,
        statics: AniminaWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
