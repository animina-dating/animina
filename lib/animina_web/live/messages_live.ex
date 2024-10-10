defmodule AniminaWeb.MessagesLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts.Message
  alias Animina.GenServers.ProfileViewCredits
  alias Phoenix.PubSub

  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )
    end

    messages = Message.unique_new_messages_for_user(socket.assigns.current_user.id)

    {
      :ok,
      socket
      |> assign(:language, language)
      |> assign(:messages, messages)
      |> assign(active_tab: :chat)
    }
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
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
    <div class="flex items-center justify-between">
      <h1 class="text-3xl font-semibold text-white">
        <%= gettext("New Messages") %>
      </h1>
    </div>
    <%= if @messages == [] do %>
      <div class="flex items-center justify-center h-full">
        <p class="text-white text-2xl">No new Messages</p>
      </div>
    <% else %>
      <div class="grid grid-cols-1 py-10 md:grid-cols-2 gap-5">
        <%= for message <- @messages do %>
          <.link
            class="mx-auto w-full max-w-3xl bg-[#1E1E2F] p-6 rounded-lg shadow-lg transition-transform transform hover:scale-105 hover:shadow-2xl"
            navigate={"/#{@current_user.username}/messages/#{message.sender.username}"}
          >
            <div class="flex items-center space-x-4">
              <div class="flex-shrink-0">
                <img
                  src="https://images.unsplash.com/photo-1728209228772-76351edd20b1?w=800&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxmZWF0dXJlZC1waG90b3MtZmVlZHwxN3x8fGVufDB8fHx8fA%3D%3D"
                  alt="A photo of a mountain"
                  class="rounded-full h-20 w-20 border-4 border-[#4A5568] shadow-sm"
                />
              </div>
              <div class="text-white">
                <h2 class="text-2xl font-semibold"><%= message.sender.name %></h2>
                <p class="text-gray-400"><%= message.content %></p>
                <p class="text-gray-400">
                  <%= Timex.format!(message.created_at, "{relative}", :relative) %>
                </p>
              </div>
            </div>
          </.link>
        <% end %>
      </div>
    <% end %>
    """
  end
end
