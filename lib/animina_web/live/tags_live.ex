defmodule AniminaWeb.TagsLive do
  use AniminaWeb, :live_view

  alias AniminaWeb.Registration
  alias Animina.Accounts

  @impl true
  def mount(_params, session, socket) do
    current_user =
      case Registration.get_current_user(session) do
        nil ->
          redirect(socket, to: "/")

        user ->
          user
      end

    socket =
      socket
      |> assign(current_user: current_user)
      |> assign(max_selected: 20)
      |> assign(active_tab: :home)
      |> assign(page_title: gettext("Select your interests"))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-10 px-5">
      <.notification_box
        title={gettext("Hello %{name}!", name: @current_user.name)}
        message={gettext("To complete your profile choose topics you are interested in")}
      />

      <h2 class="font-bold text-xl"><%= gettext("Click to select your interests") %></h2>
    </div>
    """
  end
end
