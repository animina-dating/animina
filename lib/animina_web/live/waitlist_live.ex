defmodule AniminaWeb.WaitlistLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts.Points

  alias Animina.Accounts.User

  alias Phoenix.PubSub

  alias Animina.GenServers.ProfileViewCredits
  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )

      Phoenix.PubSub.subscribe(
        Animina.PubSub,
        "user_flag:created:#{socket.assigns.current_user.id}"
      )
    end

    socket =
      socket
      |> assign(active_tab: :waitlist)
      |> assign(:language, language)
      |> assign(:page_title, gettext("Waitlist"))

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, socket) do
    users_in_waitlist = User.users_in_waitlist!()
    {:noreply, socket |> assign(users_in_waitlist: users_in_waitlist)}
  end

  @impl true
  def handle_event("give_user_in_waitlist_access", %{"id" => id}, socket) do
    user = User.by_id!(id)

    {:ok, _} = User.give_user_in_waitlist_access(user)

    users_in_waitlist = User.users_in_waitlist!()

    {:noreply,
     socket
     |> put_flash(:info, gettext("User has been given access"))
     |> assign(users_in_waitlist: users_in_waitlist)}
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)
      |> Points.humanized_points()

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
  end

  @impl true
  def handle_info({:email, _}, socket) do
    {:noreply, socket}
  end

  def handle_info({:user, current_user}, socket) do
    if current_user.state in user_states_to_be_auto_logged_out() do
      {:noreply,
       socket
       |> push_navigate(to: "/auth/user/sign-out?auto_log_out=#{current_user.state}")}
    else
      {:noreply,
       socket
       |> assign(:current_user, current_user)}
    end
  end

  defp user_states_to_be_auto_logged_out do
    [
      :under_investigation,
      :banned,
      :archived
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.waitlist_users_table users={@users_in_waitlist} />
    </div>
    """
  end
end
