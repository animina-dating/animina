defmodule AniminaWeb.DeleteAccountLive do
  use AniminaWeb, :live_view
  alias Animina.Accounts.Points
  alias Animina.Accounts.User
  alias Animina.GenServers.ProfileViewCredits
  alias Phoenix.PubSub

  @impl true
  def mount(_params, %{"language" => language}, socket) do
    subscribe(socket)

    socket =
      socket
      |> assign(active_tab: :home)
      |> assign(language: language)
      |> assign(counter: 10)
      |> assign(page_title: "#{gettext("Delete Profile")}")

    Process.sleep(1000)

    start_counter(socket)

    {:ok, socket}
  end

  def start_counter(socket) do
    send(self(), :update_counter)
    socket
  end

  defp subscribe(socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )
    end
  end

  def handle_info(:update_counter, socket) do
    if socket.assigns.counter > 0 do
      Process.sleep(1000)
      start_counter(socket)
      {:noreply, socket |> assign(counter: socket.assigns.counter - 1)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
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

  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)
      |> Points.humanized_points()

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  @impl true
  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_account", _params, socket) do
    User.destroy(socket.assigns.current_user)

    {:noreply, socket |> push_navigate(to: "/auth/user/sign-out")}
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
    <div class="flex flex-col min-h-[90vh] justify-center gap-4  items-center gap-3">
      <h1 class="text-2xl dark:text-white font-semibold">
        <%= gettext("Delete Your Account") %>
      </h1>

      <div class="text-xl w-[90%] text-center md:w-[60%] text-gray-400 font-medium">
        <%= gettext("You can delete your account here but you have to wait ") %>
        <span class="font-semibold dark:text-white text-black"><%= gettext("10 seconds") %></span> <%= gettext(
          "to make sure that this is not an accident."
        ) %>
      </div>

      <div :if={@counter > 0} class="text-2xl dark:text-white font-semibold">
        <%= @counter %> <%= gettext("Seconds Remaining") %>
      </div>

      <div :if={@counter == 0} class=" w-[100%] flex flex-col justify-center items-center">
        <p class="text-red-500 text-xl w-[90%] text-center ">
          <%= gettext(
            "If you want to delete your account, click the button below, this action is irreversible"
          ) %>
        </p>
        <button
          phx-click="delete_account"
          id="delete_account"
          data-confirm={gettext("Are You Sure You want to delete your account.")}
          class="bg-red-500 px-4 py-2 mt-4 rounded-md text-white cursor-pointer hover:scale-105 transition-all ease-in-out duration-500"
        >
          <%= gettext("Delete Account") %>
        </button>
      </div>
    </div>
    """
  end
end
