defmodule AniminaWeb.ChatLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Message
  alias Animina.Accounts.Points
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.User
  alias Animina.ChatCompletion
  alias Animina.GenServers.ProfileViewCredits
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
      |> assign(:suggested_messages, [])
      |> assign(:messages, messages_between_sender_and_receiver.results)
      |> assign(receiver: receiver)
      |> assign(:language, language)
      |> assign(:unread_messages, [])
      |> assign(profile_points: Points.humanized_points(receiver.credit_points))
      |> assign(:show_use_ai_button, true)
      |> assign(
        :message_when_generating,
        with_locale(language, fn ->
          gettext("Feeding our internal AI with this text. Please wait a second")
        end)
      )
      |> assign(:intersecting_green_flags_count, intersecting_green_flags_count)
      |> assign(:intersecting_red_flags_count, intersecting_red_flags_count)
      |> assign(:intersecting_green_flags, intersecting_green_flags)
      |> assign(:intersecting_red_flags, intersecting_red_flags)
      |> assign(:number_of_unread_messages, 0)
      |> assign(:message_value, "")
      |> assign(:generating_message, false)
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

  def handle_event("use_ai_message", %{"content" => content}, socket) do
    params = %{
      "receiver_id" => socket.assigns.receiver.id,
      "sender_id" => socket.assigns.sender.id,
      "content" => content
    }

    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:show_use_ai_button, false)
     |> assign(:message_value, content)}
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

    {:noreply,
     socket
     |> assign(form: form)
     |> assign(:message_value, params["content"])}
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
         |> assign(:message_value, "")
         |> assign(suggested_messages: [])
         |> assign(form: create_message_form())}

      {:error, _} ->
        {:noreply, assign(socket, form: socket.assigns.form)}
    end
  end

  def handle_event("generate_message_with_ai", _params, socket) do
    Process.send_after(self(), {:render_generating_message, 1}, 1000)
    send(self(), {:generate_messages, []})

    {:noreply,
     socket
     |> assign(:show_use_ai_button, false)
     |> assign(:generating_message, true)}
  end

  defp filter_flags(user, color, _language) do
    case UserFlags.by_user_id(user.id) do
      {:ok, traits} ->
        traits
        |> Enum.filter(fn trait ->
          trait.color == color and trait.flag != nil
        end)
        |> Enum.map(fn trait ->
          %{
            id: trait.flag.id,
            name: trait.flag.name,
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
      "Chat: #{sender.username} <-> #{receiver.username}"
    end
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

  def handle_info({:render_generating_message, count}, socket) do
    if socket.assigns.generating_message do
      new_message =
        case count do
          1 -> "."
          2 -> "."
          3 -> "."
          _ -> "."
        end

      message_when_generating_story = socket.assigns.message_when_generating <> new_message

      Process.send_after(self(), {:render_generating_message, rem(count + 1, 4)}, 1000)

      if count == 1 do
        {:noreply,
         assign(
           socket,
           :message_when_generating,
           with_locale(socket.assigns.language, fn ->
             gettext("Feeding our internal AI with this text. Please wait a second ")
           end)
         )}
      else
        {:noreply, assign(socket, :message_when_generating, message_when_generating_story)}
      end
    else
      {:noreply, socket}
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
  def handle_info({request_pid, {:data, %{"done" => false, "response" => chunk}}}, socket) do
    socket =
      case socket.assigns.current_request do
        %{pid: ^request_pid} ->
          generated_message = socket.assigns.generated_message <> chunk

          socket
          |> assign(:generated_message, generated_message)
          |> assign(:suggested_messages, ChatCompletion.parse_message(generated_message))

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({request_pid, {:data, %{"done" => true, "response" => response}}}, socket) do
    socket =
      case socket.assigns.current_request do
        %{pid: ^request_pid} ->
          generated_message = socket.assigns.generated_message <> response

          socket
          |> assign(:generated_message, generated_message)
          |> assign(:current_request, nil)
          |> assign(:show_use_ai_button, true)
          |> assign(:generated_message, false)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:generate_messages, _}, socket) do
    socket =
      case ChatCompletion.request_message(socket.assigns.sender, socket.assigns.receiver) do
        {:ok, task} ->
          socket
          |> assign(:current_request, task)
          |> assign(:generated_message, "")
          |> assign(:show_use_ai_button, true)

        {:error, _} ->
          socket
          |> put_flash(
            :error,
            with_locale(socket.assigns.language, fn ->
              gettext("Could not generate message with AI, Kindly Try Again")
            end)
          )
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket) do
    deduct_points(socket.assigns.sender, 20)
    {:noreply, socket |> assign(:generating_message, false)}
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

  defp deduct_points(user, points) do
    Credit.create!(%{
      user_id: user.id,
      points: points,
      subject: "Chat Help Completion"
    })
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={" #{if @suggested_messages != [] do "h-[140vh] md:h-[85vh]" else  "md:h-[90vh] h-[85vh]" end} relative  w-[100%] flex gap-4 flex-col justify-betwen"}>
      <.chat_messages_component
        sender={@sender}
        receiver={@receiver}
        language={@language}
        messages={@messages}
        profile_points={@profile_points}
        current_user_has_liked_profile?={@current_user_has_liked_profile?}
        intersecting_green_flags_count={@intersecting_green_flags_count}
        intersecting_red_flags_count={@intersecting_red_flags_count}
        intersecting_green_flags={@intersecting_green_flags}
        intersecting_red_flags={@intersecting_red_flags}
        years_text={with_locale(@language, fn -> gettext("years") end)}
        centimeters_text={with_locale(@language, fn -> gettext("cm") end)}
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
              placeholder: with_locale(@language, fn -> gettext("Your message here...") end),
              value: @message_value,
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
                unless(@form.source.valid? == false || @generating_message == false,
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                ),
            disabled: @form.source.valid? == false || @generating_message == true
          ) do %>
              <.send_message_button />
            <% end %>
          </div>
        </.form>

        <%= if Enum.count(@messages) == 0 && @current_user_credit_points >=
        Application.get_env(:animina, :ai_message_help_price)
         && @suggested_messages == [] && @show_use_ai_button do %>
          <div class="w-[100%]  flex justify-start my-3 items-center">
            <p
              phx-click="generate_message_with_ai"
              phx-disable-with="Generating potential first messages. Please wait (up to 30 seconds) ..."
              class={
                  "flex p-2 justify-center cursor-pointer hover:scale-105 transition-all ease-in-out duration-500 items-center rounded-md bg-indigo-600 dark:bg-indigo-500 h-[100%] px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                  if @generating_message do
                  " cursor-not-allowed opacity-50"
                  else
                  ""
                  end
                  }
              disabled={if @generating_message, do: true, else: false}
            >
              <%= if @generating_message do %>
                <%= @message_when_generating %>
              <% else %>
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Need help with your first message?") %>
                <% end) %>
              <% end %>
            </p>
          </div>
        <% end %>

        <div
          :if={@suggested_messages != [] && @show_use_ai_button}
          class="flex flex-col gap-1 mt-2 text-black dark:text-white"
        >
          <p class="font-bold ">
            <%= with_locale(@language, fn -> %>
              <%= gettext("Here are some ideas. Copy one and customize it (e.g. add a greeting).") %>
            <% end) %>
          </p>

          <ul class="pl-5 list-disc">
            <%= for {message, index} <- Enum.with_index(@suggested_messages) do %>
              <li class="mt-2 ml-2 md:ml-6 list-item">
                <div class="flex items-start justify-between gap-1 ">
                  <span class="md:w-[85%] w-[70%]">
                    <%= message %>
                  </span>
                  <span class="md:w-[12%] w-[25%] flex justify-end items-end">
                    <%= if length(@suggested_messages) == 3  && index + 2 == 4 do %>
                      <button
                        :if={@show_use_ai_button && @generating_message == false}
                        phx-value-content={message}
                        phx-click="use_ai_message"
                        class="flex  text-sm justify-center  items-center rounded-md bg-indigo-600 dark:bg-indigo-500  px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 "
                      >
                        <%= with_locale(@language, fn -> %>
                          <%= gettext("Copy ") %>
                        <% end) %>
                      </button>
                    <% else %>
                      <button
                        :if={@show_use_ai_button && index + 2 <= length(@suggested_messages)}
                        phx-value-content={message}
                        phx-click="use_ai_message"
                        class="flex  text-sm justify-center  items-center rounded-md bg-indigo-600 dark:bg-indigo-500  px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 "
                      >
                        <%= with_locale(@language, fn -> %>
                          <%= gettext("Copy") %>
                        <% end) %>
                      </button>
                    <% end %>
                  </span>
                </div>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
