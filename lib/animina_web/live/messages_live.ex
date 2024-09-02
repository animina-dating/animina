defmodule AniminaWeb.MessagesLive do
  use AniminaWeb, :live_view
  alias Animina.GenServers.ProfileViewCredits
  alias Phoenix.PubSub
  alias Animina.Accounts.Message
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

    {:ok, messages} = Message.unique_conversations(socket.assigns.current_user.id) |> IO.inspect()

    grouped_messages = Enum.group_by(messages, &{&1.sender_id, &1.receiver_id})

    transformed_messages =
      grouped_messages
      |> Enum.map(fn {{sender_id, receiver_id}, msgs} ->
        %{
          sender_id: sender_id,
          receiver_id: receiver_id,
          messages: msgs,
          last_message: Enum.at(Enum.sort_by(msgs, & &1.created_at), -1)
        }
      end)

    IO.inspect(transformed_messages, label: "grouped_messages")

    socket =
      socket
      |> assign(language: language)
      |> assign(active_tab: :home)
      |> assign(messages: transformed_messages)

    {:ok, socket}
  end

  @impl true
  def handle_info({:user, current_user}, socket) do
    if current_user.state in user_states_to_be_auto_logged_out() do
      {:noreply,
       socket
       |> push_navigate(to: "/auth/user/sign-out?auto_log_out=#{current_user.state}")}
    else
      {:noreply, socket |> assign(:current_user, current_user)}
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

  @impl true
  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  defp user_states_to_be_auto_logged_out do
    [
      :under_investigation,
      :banned,
      :archived
    ]
  end

  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
  end

  def render(assigns) do
    ~H"""
    <div class="px-5 space-y-4">
      <h2 class="text-xl font-bold dark:text-white">Hello</h2>
      <ul class="text-[#fff]">
        <%= for conversation <- @messages do %>
          <li>
            <strong>Sender:</strong> <%= conversation.sender_id %>
            <strong>Receiver:</strong> <%= conversation.name %>
            <ul>
              <%= for message <- conversation.messages do %>
                <li>
                  <strong>Content:</strong> <%= message.last_message.content %>
                  <strong>Created At:</strong> <%= message.created_at %>
                  <strong>Read At:</strong> <%= message.read_at %>
                </li>
              <% end %>
            </ul>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end
end
