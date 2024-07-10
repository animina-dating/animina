defmodule AniminaWeb.ChatLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Message
  alias Animina.Accounts.Points
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.User
  alias Animina.Traits.UserFlags
  alias AshPhoenix.Form
  alias Phoenix.PubSub

  @impl true
  def mount(%{"profile" => profile} = params, %{"language" => language} = _session, socket) do
    sender =
      if params["current_user"] do
        Accounts.User.by_username!(params["current_user"])
      else
        socket.assigns.current_user
      end

    receiver = Accounts.User.by_username!(profile)

    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )

      Phoenix.PubSub.subscribe(Animina.PubSub, "user_flag:created:#{sender.id}")

      Phoenix.PubSub.subscribe(Animina.PubSub, "user_flag:created:#{receiver.id}")
    end

    {:ok, messages_between_sender_and_receiver} =
      Message.messages_for_sender_and_receiver(sender.id, receiver.id, actor: sender)

    intersecting_green_flags_count =
      get_intersecting_flags_count(
        filter_flags(sender, :green, language),
        filter_flags(receiver, :white, language)
      )

    intersecting_red_flags_count =
      get_intersecting_flags_count(
        filter_flags(sender, :red, language),
        filter_flags(receiver, :white, language)
      )

    intersecting_red_flags =
      get_intersecting_flags(
        filter_flags(sender, :red, language),
        filter_flags(receiver, :white, language)
      )
      |> Enum.take(5)

    intersecting_green_flags =
      get_intersecting_flags(
        filter_flags(sender, :green, language),
        filter_flags(receiver, :white, language)
      )
      |> Enum.take(5)

    # we make sure that the messages are marked as read when the user visits the chat page
    update_read_at_messages(messages_between_sender_and_receiver.results, sender)

    socket =
      socket
      |> assign(active_tab: :chat)
      |> assign(sender: sender)
      |> assign(:messages, messages_between_sender_and_receiver.results)
      |> assign(receiver: receiver)
      |> assign(:language, language)
      |> assign(:unread_messages, [])
      |> assign(profile_points: Points.humanized_points(receiver.credit_points))
      |> assign(:intersecting_green_flags_count, intersecting_green_flags_count)
      |> assign(:intersecting_red_flags_count, intersecting_red_flags_count)
      |> assign(:intersecting_green_flags, intersecting_green_flags)
      |> assign(:intersecting_red_flags, intersecting_red_flags)
      |> assign(:number_of_unread_messages, 0)
      |> assign(form: create_message_form())
      |> assign(
        current_user_has_liked_profile?: current_user_has_liked_profile(sender.id, receiver.id)
      )
      |> assign(page_title: "Chat: #{sender.username} <-> #{receiver.username}")

    if receiver == nil or sender == nil do
      {:ok,
       socket
       |> push_navigate(to: ~p"/")}
    else
      if profile != Ash.CiString.value(socket.assigns.receiver.username) or
           params["current_user"] != Ash.CiString.value(socket.assigns.sender.username) do
        {:ok,
         socket
         |> push_navigate(
           to: ~p"/#{socket.assigns.sender.username}/messages/#{socket.assigns.receiver.username}"
         )}
      else
        {:ok, socket}
      end
    end
  end

  defp update_read_at_messages(messages, sender) do
    Enum.each(messages, fn message ->
      if message.receiver_id == sender.id and message.read_at == nil do
        Message.has_been_read(message, actor: sender)
      end
    end)
  end

  def handle_event("add_like", _params, socket) do
    Reaction.like(
      %{
        sender_id: socket.assigns.sender.id,
        receiver_id: socket.assigns.receiver.id
      },
      actor: socket.assigns.sender
    )

    {:noreply,
     socket
     |> assign(
       current_user_has_liked_profile?:
         current_user_has_liked_profile(socket.assigns.sender.id, socket.assigns.receiver.id)
     )}
  end

  @impl true
  def handle_event("remove_like", _params, socket) do
    reaction =
      get_reaction_for_sender_and_receiver(socket.assigns.sender.id, socket.assigns.receiver.id)

    Reaction.unlike(reaction, actor: socket.assigns.sender)

    {:noreply,
     socket
     |> assign(
       current_user_has_liked_profile?:
         current_user_has_liked_profile(socket.assigns.sender.id, socket.assigns.receiver.id)
     )}
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
         |> assign(messages: messages_between_sender_and_receiver.results)
         |> assign(form: create_message_form())}

      {:error, _} ->
        {:noreply, assign(socket, form: socket.assigns.form)}
    end
  end

  defp filter_flags(user, color, language) do
    case UserFlags.by_user_id(user.id) do
      {:ok, traits} ->
        traits
        |> Enum.filter(fn trait ->
          trait.color == color and trait.flag != nil
        end)
        |> Enum.map(fn trait ->
          %{
            id: trait.flag.id,
            name: get_translation(trait.flag.flag_translations, language),
            emoji: trait.flag.emoji,
            position: trait.position
          }
        end)
        |> Enum.sort_by(& &1.position)

      _ ->
        []
    end
  end

  defp get_reaction_for_sender_and_receiver(user_id, current_user_id) do
    {:ok, reaction} =
      Reaction.by_sender_and_receiver_id(user_id, current_user_id)

    reaction
  end

  defp get_page_title(message, sender, receiver) do
    # if I am the one who has received the new message it should add the chat icon
    if message.receiver_id == sender.id do
      "Chat: 💬 #{sender.username} <-> #{receiver.username}"
    else
      "Chat#{sender.username} <-> #{receiver.username}"
    end
  end

  defp get_translation(translations, language) do
    language = String.split(language, "-") |> Enum.at(0)

    translation =
      Enum.find(translations, nil, fn translation -> translation.language == language end)

    translation.name
  end

  defp current_user_has_liked_profile(user_id, current_user_id) do
    case Reaction.by_sender_and_receiver_id(user_id, current_user_id) do
      {:ok, _user} ->
        true

      {:error, _} ->
        false
    end
  end

  def handle_info({:user, current_user}, socket) do
    if current_user.state in user_states_to_be_auto_logged_out() do
      {:noreply,
       socket
       |> push_navigate(to: "/auth/user/sign-out?auto_log_out=#{current_user.state}")}
    else
      {:noreply,
       socket
       |> assign(sender: current_user)
       |> assign(
         current_user_has_liked_profile?:
           current_user_has_liked_profile(current_user.id, socket.assigns.receiver.id)
       )}
    end
  end

  def handle_info(
        %{event: "create", payload: %{data: %UserFlags{} = user_flag}},
        socket
      ) do
    user_flag_user = User.by_id!(user_flag.user_id)

    if user_flag.user_id == socket.assigns.current_user.id do
      intersecting_green_flags_count =
        get_intersecting_flags_count(
          filter_flags(user_flag_user, :green, socket.assigns.language),
          filter_flags(socket.assigns.receiver, :white, socket.assigns.language)
        )

      intersecting_red_flags_count =
        get_intersecting_flags_count(
          filter_flags(user_flag_user, :red, socket.assigns.language),
          filter_flags(socket.assigns.receiver, :white, socket.assigns.language)
        )

      intersecting_red_flags =
        get_intersecting_flags(
          filter_flags(user_flag_user, :red, socket.assigns.language),
          filter_flags(socket.assigns.receiver, :white, socket.assigns.language)
        )
        |> Enum.take(5)

      intersecting_green_flags =
        get_intersecting_flags(
          filter_flags(user_flag_user, :green, socket.assigns.language),
          filter_flags(socket.assigns.receiver, :white, socket.assigns.language)
        )
        |> Enum.take(5)

      {:noreply,
       socket
       |> assign(
         intersecting_green_flags_count: intersecting_green_flags_count,
         intersecting_red_flags_count: intersecting_red_flags_count
       )
       |> assign(
         intersecting_green_flags: intersecting_green_flags,
         intersecting_red_flags: intersecting_red_flags
       )}
    else
      intersecting_green_flags_count =
        get_intersecting_flags_count(
          filter_flags(socket.assigns.sender, :green, socket.assigns.language),
          filter_flags(user_flag_user, :white, socket.assigns.language)
        )

      intersecting_red_flags_count =
        get_intersecting_flags_count(
          filter_flags(socket.assigns.sender, :red, socket.assigns.language),
          filter_flags(user_flag_user, :white, socket.assigns.language)
        )

      intersecting_red_flags =
        get_intersecting_flags(
          filter_flags(socket.assigns.sender, :red, socket.assigns.language),
          filter_flags(user_flag_user, :white, socket.assigns.language)
        )
        |> Enum.take(5)

      intersecting_green_flags =
        get_intersecting_flags(
          filter_flags(socket.assigns.sender, :green, socket.assigns.language),
          filter_flags(user_flag_user, :white, socket.assigns.language)
        )
        |> Enum.take(5)

      {:noreply,
       socket
       |> assign(
         intersecting_green_flags_count: intersecting_green_flags_count,
         intersecting_red_flags_count: intersecting_red_flags_count
       )
       |> assign(
         intersecting_green_flags: intersecting_green_flags,
         intersecting_red_flags: intersecting_red_flags
       )}
    end
  end

  def handle_info({:new_message, message}, socket) do
    {:ok, message} = Message.by_id(message.id)

    {:ok, messages_between_sender_and_receiver} =
      Message.messages_for_sender_and_receiver(
        socket.assigns.sender.id,
        socket.assigns.receiver.id,
        actor: socket.assigns.sender
      )

    unread_messages = socket.assigns.unread_messages ++ [message]

    page_title =
      get_page_title(List.first(message), socket.assigns.sender, socket.assigns.receiver)

    {:noreply,
     socket
     |> assign(page_title: page_title)
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))
     |> assign(:messages, messages_between_sender_and_receiver.results)}
  end

  @impl true
  def handle_info(
        {:display_updated_credits, %{"points" => points, "user_id" => _user_id}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(current_user_credit_points: points)}
  end

  @impl true
  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
  end

  defp get_intersecting_flags_count(first_flag_array, second_flag_array) do
    first_flag_array = Enum.map(first_flag_array, fn x -> x.id end)
    second_flag_array = Enum.map(second_flag_array, fn x -> x.id end)

    Enum.count(first_flag_array, &(&1 in second_flag_array))
  end

  def get_intersecting_flags(first_flag_array, second_flag_array) do
    Enum.filter(first_flag_array, fn x ->
      x.id in Enum.map(second_flag_array, fn x -> x.id end)
    end)
  end

  defp user_states_to_be_auto_logged_out do
    [
      :under_investigation,
      :banned,
      :archived
    ]
  end

  defp create_message_form do
    Form.for_create(Message, :create,
      domain: Accounts,
      as: "message",
      forms: [auto?: true]
    )
    |> to_form()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="md:h-[90vh] h-[85vh] relative  w-[100%] flex gap-4 flex-col justify-betwen">
      <.chat_messages_component
        sender={@sender}
        receiver={@receiver}
        messages={@messages}
        profile_points={@profile_points}
        current_user_has_liked_profile?={@current_user_has_liked_profile?}
        intersecting_green_flags_count={@intersecting_green_flags_count}
        intersecting_red_flags_count={@intersecting_red_flags_count}
        intersecting_green_flags={@intersecting_green_flags}
        intersecting_red_flags={@intersecting_red_flags}
        years_text={gettext("years")}
        centimeters_text={gettext("cm")}
      />
      <div class="w-[100%]  absolute bottom-0">
        <.form
          :let={f}
          for={@form}
          phx-change="validate"
          phx-submit="submit"
          id="message_form"
          class="w-[100%] flex justify-between items-end"
        >
          <div phx-feedback-for={f[:content].name} class="md:w-[93%] w-[90%]">
            <%= textarea(
              f,
              :content,
              class:
                "block w-full h-[60px] rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:content], :content) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("Your message here..."),
              value: f[:content].value,
              type: :text,
              required: true,
              autocomplete: :content,
              "phx-debounce": "200"
            ) %>

            <%= hidden_input(f, :sender_id, value: @sender.id) %>
            <%= hidden_input(f, :receiver_id, value: @receiver.id) %>
          </div>

          <div class="md:w-[5%] w-[8%] h-[60px] flex justify-center items-center">
            <%= submit(
            class:
              "flex w-full justify-center items-center rounded-md bg-indigo-600 dark:bg-indigo-500 h-[100%] px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
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
