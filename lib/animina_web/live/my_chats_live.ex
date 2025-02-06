defmodule AniminaWeb.MyChatsLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts.Message
  alias Animina.Accounts.Photo
  alias Animina.GenServers.ProfileViewCredits
  alias Phoenix.PubSub

  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(active_tab: :chats)
      |> assign(:conversations, Message.get_conversations(socket.assigns.current_user.id))
      |> assign(page_title: "#{with_locale(language, fn -> gettext("Chats") end)}")

    subscribe(socket, socket.assigns.current_user)

    {:ok, socket}
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
    if current_user.state in user_states_to_be_auto_logged_out() do
      {:noreply,
       socket
       |> push_navigate(to: "/auth/user/sign-out?auto_log_out=#{current_user.state}")}
    else
      {:noreply, socket |> assign(:current_user, current_user)}
    end
  end

  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  def handle_info({:new_message, message}, socket) do
    {:noreply,
     socket
     |> assign(:conversations, Message.get_conversations(socket.assigns.current_user.id))}
  end

  defp subscribe(socket, current_user) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )

      Phoenix.PubSub.subscribe(Animina.PubSub, "user_flag:created:#{current_user.id}")
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
    <div class="dark:text-white flex flex-col gap-2 text-black">
      <p class="text-xl font-medium">
        <%= with_locale(@language, fn -> gettext("My Chats") end) %>
      </p>
      <%= for {user , message ,_ } <- @conversations do %>
        <.link
          navigate={"/#{@current_user.username}/messages/#{user.username}"}
          class="border-b-[1px] hover:bg-blue-100 hover:text-blue-700 border-b-gray-500 duration-500 ease-in-out cursor-pointer flex gap-4 items-start p-2"
        >
          <img
            class="object-cover w-16 h-16 rounded-full"
            src={Photo.get_optimized_photo_to_use(user.profile_photo, :normal)}
          />

          <div class="flex flex-col gap-1">
            <p>
              <%= user.name %>
            </p>
            <p class="text-gray-500 text-sm">
              <%= message.content %>
            </p>
          </div>
        </.link>
      <% end %>
    </div>
    """
  end
end
