defmodule AniminaWeb.DashboardLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Message
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.User
  alias Animina.GenServers.ProfileViewCredits
  alias AshPhoenix.Form
  alias Phoenix.PubSub

  require Ash.Query
  require Ash.Sort

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

    unread_messages =
      case Message.unread_messages_for_user(socket.assigns.current_user.id) do
        {:ok, messages} ->
          messages

        _ ->
          []
      end

    socket =
      socket
      |> assign(active_tab: :home)
      |> assign(unread_messages: unread_messages)
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

    unread_messages =
      case Message.unread_messages_for_user(socket.assigns.current_user.id) do
        {:ok, messages} ->
          messages

        _ ->
          []
      end

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
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
    <div class="px-6 mx-auto max-w-7xl lg:px-8">
      <div class="max-w-2xl mx-auto lg:mx-0">
        <h2 class="text-3xl font-bold tracking-tight dark:text-gray-300 text-gray-900 sm:text-4xl">
          <%= gettext("Members you might be interested in") |> raw() %>
        </h2>
        <p class="text-lg leading-8 text-gray-600">
          <%= gettext("Here are other animima members who match your potential partner settings.")
          |> raw() %>
        </p>
      </div>
      <ul
        role="list"
        class="grid max-w-2xl grid-cols-1 mx-auto mt-10 gap-x-8 gap-y-16 sm:grid-cols-2 lg:mx-0 lg:max-w-none lg:grid-cols-4"
      >
        <%= for potential_partner <- potential_partners(@current_user) do %>
          <li>
            <.link
              navigate={~p"/#{potential_partner.username}"}
              class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
            >
              <img
                class="aspect-[1/1] w-full rounded-2xl object-cover"
                src={"/uploads/#{potential_partner.profile_photo.filename}"}
                alt={
                  gettext("Image of %{name}.",
                    name: potential_partner.name |> Phoenix.HTML.Safe.to_iodata() |> to_string()
                  )
                  |> raw()
                }
              />

              <h3 class="mt-6 text-lg font-semibold leading-8 tracking-tight text-gray-900">
                <%= potential_partner.name %>
              </h3>
            </.link>

            <p class="text-base leading-7 text-gray-600">
              Lorepsum Ipsum. This should be the first 200 characters of the "about me" story. ...
            </p>
            <div class="pt-2">
              <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
                <%= potential_partner.age %> <%= gettext("years") |> raw() %>
              </span>
              <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
                <%= potential_partner.height %> <%= gettext("cm") |> raw() %>
              </span>
              <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
                📍 <%= potential_partner.city.name %>
              </span>
            </div>
          </li>
        <% end %>
      </ul>

      <div class="grid grid-cols-1 gap-6 mt-10 md:grid-cols-2">
        <.dashboard_card_like_component
          title={gettext("Likes")}
          likes_received_by_user_in_seven_days={@likes_received_by_user_in_seven_days}
          profiles_liked_by_user={@profiles_liked_by_user}
          total_likes_received_by_user={@total_likes_received_by_user}
        />

        <.dashboard_card_messages_component
          title={gettext("Unread Chats")}
          unread_messages={@unread_messages}
          language={@language}
          current_user={@current_user}
          form={@form}
        />

        <.dashboard_card_chat_component
          title={gettext("Latest Chat")}
          last_unread_message={@last_unread_message}
          language={@language}
          current_user={@current_user}
          form={@form}
        />
      </div>
    </div>
    """
  end

  def potential_partners(current_user) do
    case current_user.gender do
      "male" ->
        User
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(gender == "female")
        |> Ash.Query.sort(Ash.Sort.expr_sort(fragment("RANDOM()")))
        |> Ash.Query.limit(4)
        |> Accounts.read!()

      _ ->
        User
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(gender == "male")
        |> Ash.Query.sort(Ash.Sort.expr_sort(fragment("RANDOM()")))
        |> Ash.Query.limit(4)
        |> Accounts.read!()
    end
  end
end
