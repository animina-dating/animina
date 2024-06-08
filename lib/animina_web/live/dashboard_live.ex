defmodule AniminaWeb.DashboardLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Message
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.User
  alias Animina.GenServers.ProfileViewCredits
  alias Animina.Markdown
  alias Animina.Narratives.Story
  alias Animina.Traits.UserFlags
  alias AniminaWeb.PotentialPartner
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
      |> assign(
        page_title: "#{gettext("Animina dashboard for")} #{socket.assigns.current_user.name}"
      )

    {:ok, socket}
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

  defp get_translation(translations, language) do
    language = String.split(language, "-") |> Enum.at(0)

    translation =
      Enum.find(translations, nil, fn translation -> translation.language == language end)

    translation.name
  end

  def get_intersecting_flags(first_flag_array, second_flag_array) do
    Enum.filter(first_flag_array, fn x ->
      x.id in Enum.map(second_flag_array, fn x -> x.id end)
    end)
    |> Enum.take(2)
  end

  defp get_about_me_story_by_user(user_id) do
    case Story.about_story_by_user(user_id) do
      {:ok, story} ->
        story

      _ ->
        nil
    end
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
      <div :if={
        PotentialPartner.potential_partners(@current_user,
          limit: 4,
          remove_bookmarked_potential_users: true
        ) != []
      }>
        <div class="max-w-2xl mx-auto lg:mx-0">
          <h2 class="text-3xl font-bold tracking-tight text-gray-900 dark:text-gray-300 sm:text-4xl">
            <%= gettext("Potential Matches") |> raw() %>
          </h2>
        </div>

        <ul
          role="list"
          class="grid max-w-2xl grid-cols-1 grid-cols-2 mx-auto mt-10 gap-x-8 gap-y-16 lg:mx-0 lg:max-w-none lg:grid-cols-4"
        >
          <%= for potential_partner <- PotentialPartner.potential_partners(@current_user, [limit: 4, remove_bookmarked_potential_users: true]) do %>
            <li>
              <.link
                navigate={~p"/#{potential_partner.username}"}
                class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
              >
                <div class="relative">
                  <img
                    :if={
                      potential_partner && potential_partner.profile_photo &&
                        display_potential_partner(
                          potential_partner.profile_photo.state,
                          @current_user,
                          potential_partner
                        )
                    }
                    class="aspect-[1/1] w-full rounded-2xl object-cover"
                    src={"/uploads/#{potential_partner.profile_photo.filename}"}
                    alt={
                      gettext("Image of %{name}.",
                        name: potential_partner.name |> Phoenix.HTML.Safe.to_iodata() |> to_string()
                      )
                      |> raw()
                    }
                  />
                  <p
                    :if={
                      @current_user && potential_partner.profile_photo.state != :approved &&
                        current_user_admin?(@current_user)
                    }
                    class={"p-1 text-[10px] #{get_photo_state_styling(potential_partner.profile_photo.state)} absolute top-2 left-2 rounded-md "}
                  >
                    <%= get_photo_state_name(potential_partner.profile_photo.state) %>
                  </p>
                </div>

                <h3 class="mt-6 text-lg font-semibold leading-8 tracking-tight text-gray-900 dark:text-gray-300">
                  <%= potential_partner.name %>
                </h3>
              </.link>

              <div
                :if={get_about_me_story_by_user(potential_partner.id).content != nil}
                class="text-base leading-7 text-gray-600 dark:text-gray-400"
              >
                <%= Markdown.format(
                  get_about_me_story_by_user(potential_partner.id).content
                  |> Animina.StringHelper.slice_at_word_boundary(150, potential_partner.username, true)
                ) %>
              </div>
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
                <.potential_users_intersecting_green_flags green_flags={
                  get_intersecting_flags(
                    filter_flags(@current_user, :green, @language),
                    filter_flags(potential_partner, :white, @language)
                  )
                } />
              </div>
            </li>
          <% end %>
        </ul>
      </div>

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

  defp get_photo_state_styling(:error) do
    "bg-red-500 text-white"
  end

  defp get_photo_state_styling(:nsfw) do
    "bg-red-500 text-white"
  end

  defp get_photo_state_styling(:rejected) do
    "bg-red-500 text-white"
  end

  defp get_photo_state_styling(:pending_review) do
    "bg-yellow-500 text-white"
  end

  defp get_photo_state_styling(:in_review) do
    "bg-blue-500 text-white"
  end

  defp get_photo_state_name(:error) do
    gettext("Error")
  end

  defp get_photo_state_name(:nsfw) do
    gettext("NSFW")
  end

  defp get_photo_state_name(:rejected) do
    gettext("Rejected")
  end

  defp get_photo_state_name(:pending_review) do
    gettext("Pending review")
  end

  defp get_photo_state_name(:in_review) do
    gettext("In review")
  end

  defp get_photo_state_name(_) do
    gettext("Error")
  end

  def display_potential_partner(:pending_review, _, _) do
    true
  end

  def display_potential_partner(:approved, _, _) do
    true
  end

  def display_potential_partner(:in_review, _, _) do
    true
  end

  def display_potential_partner(:error, nil, _) do
    false
  end

  def display_potential_partner(:nsfw, nil, _) do
    false
  end

  def display_potential_partner(:nsfw, current_user, user) do
    if user.id == current_user.id || current_user_admin?(current_user) do
      true
    else
      false
    end
  end

  def display_potential_partner(:error, current_user, user) do
    if user.id == current_user.id || current_user_admin?(current_user) do
      true
    else
      false
    end
  end

  def display_potential_partner(_, _, _) do
    false
  end

  def current_user_admin?(current_user) do
    case current_user.roles do
      [] ->
        false

      roles ->
        roles
        |> Enum.map(fn x -> x.name end)
        |> Enum.any?(fn x -> x == :admin end)
    end
  end
end
