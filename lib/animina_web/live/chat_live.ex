defmodule AniminaWeb.ChatLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Message
  alias Animina.GenServers.ProfileViewCredits
  alias AshPhoenix.Form
  alias Phoenix.PubSub

  @impl true
  def mount(%{"profile" => profile} = params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")
    end

    sender =
      if params["current_user"] do
        {:ok, sender} = Accounts.User.by_username(params["current_user"])
        sender
      else
        socket.assigns.current_user
      end

    {:ok, receiver} = Accounts.User.by_username(profile)

    {:ok, messages_between_sender_and_receiver} =
      Message.messages_for_sender_and_receiver(sender.id, receiver.id, actor: sender)

    # we make sure that the messages are marked as read when the user visits the chat page
    update_read_at_messages(messages_between_sender_and_receiver, sender)

    socket =
      socket
      |> assign(active_tab: :chat)
      |> assign(sender: sender)
      |> assign(:messages, messages_between_sender_and_receiver)
      |> assign(receiver: receiver)
      |> assign(form: create_message_form())
      |> assign(page_title: gettext("Chat"))

    {:ok, socket}
  end

  defp update_read_at_messages(messages, sender) do
    Enum.each(messages, fn message ->
      if message.receiver_id == sender.id and message.read_at == nil do
        Message.has_been_read(message, actor: sender)
      end
    end)
  end

  defp create_message_form do
    Form.for_create(Message, :create,
      api: Accounts,
      as: "message",
      forms: [auto?: true]
    )
    |> to_form()
  end

  @impl true
  def handle_event("validate", %{"message" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", %{"message" => params}, socket) do
    case Message.create(params, actor: socket.assigns.sender) do
      {:ok, message} ->
        {:ok, messages_between_sender_and_receiver} =
          Message.messages_for_sender_and_receiver(message.sender_id, message.receiver_id,
            actor: socket.assigns.sender
          )

        PubSub.broadcast(Animina.PubSub, "messages", {:new_message, message})

        {:noreply,
         socket
         |> assign(messages: messages_between_sender_and_receiver)
         |> assign(form: create_message_form())}

      {:error, _} ->
        {:noreply, assign(socket, form: socket.assigns.form)}
    end
  end

  defp message_belongs_to_current_user_or_profile(message, current_user, profile) do
    if (message.sender_id == current_user.id and message.receiver_id == profile.id) or
         (message.sender_id == profile.id and message.receiver_id == current_user.id) do
      true
    else
      false
    end
  end

  def handle_info({:new_message, message}, socket) do
    {:ok, message} = Message.by_id(message.id)

    messages =
      (socket.assigns.messages ++ message)
      |> Enum.uniq()

    if message_belongs_to_current_user_or_profile(
         List.first(message),
         socket.assigns.sender,
         socket.assigns.receiver
       ) do
      {:noreply, socket |> assign(messages: messages)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_user(socket, credits)

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  @impl true
  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      phx-hook="Test"
      id="test"
      class="md:h-[90vh] h-[85vh] relative  w-[100%] flex gap-4 flex-col justify-betwen"
    >
      <.chat_messages_component sender={@sender} receiver={@receiver} messages={@messages} />
      <div class="w-[100%]  absolute bottom-0">
        <.form
          :let={f}
          for={@form}
          phx-change="validate"
          phx-submit="submit"
          class="w-[100%] flex justify-between items-end"
        >
          <div phx-feedback-for={f[:content].name} class="md:w-[93%] w-[90%]">
            <%= textarea(
              f,
              :content,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:content], :content) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("Your message here..."),
              value: f[:content].value,
              type: :text,
              required: true,
              rows: 2,
              autocomplete: :content,
              "phx-debounce": "200"
            ) %>

            <%= hidden_input(f, :sender_id, value: @sender.id) %>
            <%= hidden_input(f, :receiver_id, value: @receiver.id) %>
          </div>

          <div class="md:w-[5%] w-[8%] flex justify-center items-center">
            <%= submit(
            class:
              "flex w-full justify-center rounded-md bg-indigo-600 dark:bg-indigo-500 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@form.source.valid? == false,
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                ),
            disabled: @form.source.valid? == false
          ) do %>
              <.send_message_button />
            <% end %>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
