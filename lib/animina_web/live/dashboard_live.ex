defmodule AniminaWeb.DashboardLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Message
  alias Animina.Accounts.Reaction
  alias Animina.GenServers.ProfileViewCredits
  alias AshPhoenix.Form
  alias Phoenix.PubSub

  @impl true
  def mount(_params, %{"language" => language}, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )

      Phoenix.PubSub.subscribe(
        Animina.PubSub,
        "reaction:created:#{socket.assigns.current_user.id}"
      )

      Phoenix.PubSub.subscribe(
        Animina.PubSub,
        "reaction:deleted:#{socket.assigns.current_user.id}"
      )
    end

    likes_received_by_user_in_seven_days =
      Reaction.likes_received_by_user_in_seven_days!(socket.assigns.current_user.id)
      |> Enum.count()

    profiles_liked_by_user =
      Reaction.profiles_liked_by_user!(socket.assigns.current_user.id) |> Enum.count()

    total_likes_received_by_user =
      Reaction.total_likes_received_by_user!(socket.assigns.current_user.id)
      |> Enum.count()

    last_unread_message =
      case Message.last_unread_message_by_receiver(socket.assigns.current_user.id) do
        {:ok, message} ->
          message

        _ ->
          nil
      end

    socket =
      socket
      |> assign(active_tab: :home)
      |> assign(last_unread_message: last_unread_message)
      |> assign(form: create_message_form())
      |> assign(language: language)
      |> assign(likes_received_by_user_in_seven_days: likes_received_by_user_in_seven_days)
      |> assign(profiles_liked_by_user: profiles_liked_by_user)
      |> assign(total_likes_received_by_user: total_likes_received_by_user)

    {:ok, socket}
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
  def handle_params(_params, url, socket) do
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

  def handle_info({:new_message, _message}, socket) do
    last_unread_message =
      case Message.last_unread_message_by_receiver(socket.assigns.current_user.id) do
        {:ok, message} ->
          message

        _ ->
          nil
      end

    {:noreply,
     socket
     |> assign(last_unread_message: last_unread_message)}
  end

  def handle_info(
        %{event: "create", payload: %{data: %Reaction{} = _reaction}},
        socket
      ) do
    likes_received_by_user_in_seven_days =
      Reaction.likes_received_by_user_in_seven_days!(socket.assigns.current_user.id)
      |> Enum.count()

    profiles_liked_by_user =
      Reaction.profiles_liked_by_user!(socket.assigns.current_user.id) |> Enum.count()

    total_likes_received_by_user =
      Reaction.total_likes_received_by_user!(socket.assigns.current_user.id)
      |> Enum.count()

    {:noreply,
     socket
     |> assign(likes_received_by_user_in_seven_days: likes_received_by_user_in_seven_days)
     |> assign(profiles_liked_by_user: profiles_liked_by_user)
     |> assign(total_likes_received_by_user: total_likes_received_by_user)}
  end

  def handle_info(
        %{event: "destroy", payload: %{data: %Reaction{} = _reaction}},
        socket
      ) do
    likes_received_by_user_in_seven_days =
      Reaction.likes_received_by_user_in_seven_days!(socket.assigns.current_user.id)
      |> Enum.count()

    profiles_liked_by_user =
      Reaction.profiles_liked_by_user!(socket.assigns.current_user.id) |> Enum.count()

    total_likes_received_by_user =
      Reaction.total_likes_received_by_user!(socket.assigns.current_user.id)
      |> Enum.count()

    {:noreply,
     socket
     |> assign(likes_received_by_user_in_seven_days: likes_received_by_user_in_seven_days)
     |> assign(profiles_liked_by_user: profiles_liked_by_user)
     |> assign(total_likes_received_by_user: total_likes_received_by_user)}
  end

  @impl true
  def handle_event("validate", %{"message" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", %{"message" => params}, socket) do
    case Message.create(params, actor: socket.assigns.current_user) do
      {:ok, message} ->
        # read the unread message
        Message.has_been_read(socket.assigns.last_unread_message,
          actor: socket.assigns.current_user
        )

        PubSub.broadcast(Animina.PubSub, "messages", {:new_message, message})

        last_unread_message =
          case Message.last_unread_message_by_receiver(socket.assigns.current_user.id) do
            {:ok, message} ->
              message

            _ ->
              nil
          end

        {:noreply,
         socket
         |> assign(last_unread_message: last_unread_message)
         |> assign(form: create_message_form())}

      {:error, _} ->
        {:noreply, assign(socket, form: socket.assigns.form)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="grid md:grid-cols-2 grid-cols-1 gap-6 ">
        <.dashboard_card_like_component
          title={gettext("Likes")}
          likes_received_by_user_in_seven_days={@likes_received_by_user_in_seven_days}
          profiles_liked_by_user={@profiles_liked_by_user}
          total_likes_received_by_user={@total_likes_received_by_user}
        />

        <.dashboard_card_chat_component
          title={gettext("Chats")}
          last_unread_message={@last_unread_message}
          language={@language}
          current_user={@current_user}
          form={@form}
        />
      </div>
    </div>
    """
  end
end
