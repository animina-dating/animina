defmodule AniminaWeb.DashboardLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.GenServers.ProfileViewCredits
  alias Phoenix.PubSub

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )
    end

    socket =
      socket
      |> assign(active_tab: :home)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, url, socket) do
    case URI.parse(url) do
      %URI{path: "/my/"} ->
        {:noreply, socket |> push_redirect(to: "/my/dashboard")}

      %URI{path: "/my"} ->
        {:noreply, socket |> push_redirect(to: "/my/dashboard")}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  def handle_info({:user, current_user}, socket) do
    {:noreply,
     socket
     |> assign(current_user: current_user)}
  end

  @impl true
  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="grid md:grid-cols-3 grid-cols-1 gap-4 ">
        <.dashboard_card_component title={gettext("Likes")} />
        <.dashboard_card_component title={gettext("Messages")} />
        <.dashboard_card_component title={gettext("Profiles")} />
      </div>
    </div>
    """
  end
end
