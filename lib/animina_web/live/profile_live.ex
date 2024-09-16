defmodule AniminaWeb.ProfileLive do
  @moduledoc """
  User Profile Liveview
  """

  use AniminaWeb, :live_view
  alias Animina.Accounts
  alias Animina.Accounts.BasicUser
  alias Animina.Accounts.Bookmark
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Points
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.User
  alias Animina.Accounts.VisitLogEntry
  alias Animina.GenServers.ProfileViewCredits
  alias Animina.Narratives.Story
  alias Animina.Traits.UserFlags
  alias Phoenix.PubSub

  require Ash.Query

  defp profile_socket(socket, username, language, current_user, :same_profile) do
    case Accounts.User.by_username_as_an_actor(username, actor: current_user) do
      {:ok, user} ->
        subscribe(socket, current_user, user)
        active_tab = if current_user.id == user.id, do: :profile, else: ""

        if connected?(socket) do
          create_or_update_visited_bookmark(current_user, user)

          deduct_points_for_first_profile_view(current_user, user)
        end

        add_points_for_viewing_to_profile(current_user.id, user.id, socket)

        visit_log_entry =
          create_visit_log_entry_for_bookmark_and_user(current_user, user, socket)

        update_visit_log_entry_for_bookmark_and_user(current_user, user)

        intersecting_green_flags_count =
          get_intersecting_flags_count(
            filter_flags(current_user, :green, language),
            filter_flags(user, :white, language)
          )

        intersecting_red_flags_count =
          get_intersecting_flags_count(
            filter_flags(current_user, :red, language),
            filter_flags(user, :white, language)
          )

        intersecting_red_flags =
          get_intersecting_flags(
            filter_flags(current_user, :red, language),
            filter_flags(user, :white, language)
          )
          |> Enum.take(3)

        intersecting_green_flags =
          get_intersecting_flags(
            filter_flags(current_user, :green, language),
            filter_flags(user, :white, language)
          )
          |> Enum.take(3)

        # we set it to be the current time and date by default so that we can display the profile to the user if
        # the user is the same as the current user

        user_registration_completed_at =
          if current_user.id == user.id do
            DateTime.utc_now()
          else
            user.registration_completed_at
          end

        if show_optional_404_page(user, current_user) || user_registration_completed_at == nil do
          raise Animina.Fallback
        else
          {:ok,
           socket
           |> assign(user: user)
           |> assign(active_tab: active_tab)
           |> assign(visit_log_entry: visit_log_entry)
           |> assign(
             current_user_credit_points:
               Points.humanized_points(socket.assigns.current_user.credit_points)
           )
           |> assign(intersecting_green_flags: intersecting_green_flags)
           |> assign(intersecting_red_flags: intersecting_red_flags)
           |> assign(intersecting_green_flags_count: intersecting_green_flags_count)
           |> assign(intersecting_red_flags_count: intersecting_red_flags_count)
           |> assign(profile_points: Points.humanized_points(user.credit_points))
           |> assign(page_title: "#{user.name} - #{gettext("Animina Profile")}")
           |> assign(
             current_user_has_liked_profile?:
               current_user_has_liked_profile(socket.assigns.current_user, user.id)
           )
           |> redirect_if_username_is_different(username, user)
           |> redirect_if_user_has_no_about_me_story(user)}
        end

      _ ->
        raise Animina.Fallback
    end
  end

  defp profile_socket(socket, username, _language, nil) do
    case Accounts.User.by_username(username) do
      {:ok, user} ->
        if show_optional_404_page(user, nil) ||
             user.state in user_states_not_visible_to_anonymous_users() ||
             user.registration_completed_at == nil do
          raise Animina.Fallback
        else
          {:ok,
           socket
           |> assign(user: user)
           |> assign(active_tab: "")
           |> assign(current_user_credit_points: 0)
           |> assign(intersecting_green_flags_count: 0)
           |> assign(intersecting_red_flags_count: 0)
           |> assign(page_title: "#{user.name} - #{gettext("Animina Profile")}")
           |> assign(intersecting_green_flags: [])
           |> assign(intersecting_red_flags: [])
           |> assign(show_404_page: false)
           |> assign(profile_points: Points.humanized_points(user.credit_points))
           |> assign(
             current_user_has_liked_profile?: current_user_has_liked_profile(nil, user.id)
           )
           |> redirect_if_username_is_different(username, user)}
        end

      _ ->
        raise Animina.Fallback
    end
  end

  defp profile_socket(socket, username, language, current_user) do
    case Accounts.User.by_username_as_an_actor(username, actor: current_user) do
      {:ok, user} ->
        subscribe(socket, current_user, user)
        active_tab = if current_user.id == user.id, do: :profile, else: ""

        if connected?(socket) do
          create_or_update_visited_bookmark(current_user, user)

          deduct_points_for_first_profile_view(current_user, user)
        end

        add_points_for_viewing_to_profile(current_user.id, user.id, socket)

        visit_log_entry =
          create_visit_log_entry_for_bookmark_and_user(current_user, user, socket)

        update_visit_log_entry_for_bookmark_and_user(current_user, user)

        intersecting_green_flags_count =
          get_intersecting_flags_count(
            filter_flags(current_user, :green, language),
            filter_flags(user, :white, language)
          )

        intersecting_red_flags_count =
          get_intersecting_flags_count(
            filter_flags(current_user, :red, language),
            filter_flags(user, :white, language)
          )

        intersecting_red_flags =
          get_intersecting_flags(
            filter_flags(current_user, :red, language),
            filter_flags(user, :white, language)
          )
          |> Enum.take(3)

        intersecting_green_flags =
          get_intersecting_flags(
            filter_flags(current_user, :green, language),
            filter_flags(user, :white, language)
          )
          |> Enum.take(3)

        # we set it to be the current time and date by default so that we can display the profile to the user if
        # the user is the same as the current user

        user_registration_completed_at =
          if current_user.id == user.id do
            DateTime.utc_now()
          else
            user.registration_completed_at
          end

        if show_optional_404_page(user, current_user) || user_registration_completed_at == nil do
          raise Animina.Fallback
        else
          {:ok,
           socket
           |> assign(user: user)
           |> assign(active_tab: active_tab)
           |> assign(visit_log_entry: visit_log_entry)
           |> assign(
             current_user_credit_points:
               Points.humanized_points(socket.assigns.current_user.credit_points)
           )
           |> assign(intersecting_green_flags: intersecting_green_flags)
           |> assign(intersecting_red_flags: intersecting_red_flags)
           |> assign(intersecting_green_flags_count: intersecting_green_flags_count)
           |> assign(intersecting_red_flags_count: intersecting_red_flags_count)
           |> assign(profile_points: Points.humanized_points(user.credit_points))
           |> assign(page_title: "#{user.name} - #{gettext("Animina Profile")}")
           |> assign(
             current_user_has_liked_profile?:
               current_user_has_liked_profile(socket.assigns.current_user, user.id)
           )
           |> redirect_if_username_is_different(username, user)}
        end

      _ ->
        raise Animina.Fallback
    end
  end

  @impl true
  def mount(%{"username" => username}, %{"language" => language}, socket) do
    socket =
      socket
      |> assign(language: language)

    current_user =
      socket.assigns.current_user

    if current_user && Ash.CiString.value(current_user.username) == username do
      profile_socket(socket, username, language, current_user, :same_profile)
    else
      profile_socket(socket, username, language, current_user)
    end
  end

  def mount(_params, %{"language" => _language}, socket) do
    current_user =
      socket.assigns.current_user

    if current_user do
      {:ok,
       socket
       |> push_navigate(to: ~p"/#{current_user.username}")}
    else
      raise Animina.Fallback
    end
  end

  def mount(_params, %{"language" => _language}, _socket) do
    raise Animina.Fallback
  end

  defp create_or_update_visited_bookmark(current_user, user) when current_user.id != nil do
    case Bookmark.by_owner_user_and_reason(
           current_user.id,
           user.id,
           :visited,
           actor: current_user
         ) do
      {:ok, bookmark} ->
        Bookmark.update_last_visit(bookmark, %{
          last_visit_at: DateTime.utc_now()
        })

      {:error, _error} ->
        if current_user.id != user.id do
          Bookmark.visit(
            %{
              owner_id: current_user.id,
              user_id: user.id,
              last_visit_at: DateTime.utc_now()
            },
            actor: current_user
          )
        end
    end
  end

  defp create_visit_log_entry_for_bookmark_and_user(current_user, user, socket) do
    if current_user.id != user.id && connected?(socket) do
      case Bookmark.by_owner_user_and_reason(
             current_user.id,
             user.id,
             :visited,
             actor: current_user
           ) do
        {:ok, bookmark} ->
          VisitLogEntry.create!(%{
            user_id: current_user.id,
            bookmark_id: bookmark.id,
            duration: 5
          })

        {:error, _error} ->
          :ok
      end
    end
  end

  defp update_visit_log_entry_for_bookmark_and_user(current_user, user) do
    if current_user.id != user.id do
      :timer.send_interval(5000, self(), :update_visit_log_entry_for_bookmark_and_user)
    end
  end

  defp redirect_if_username_is_different(socket, username, user) do
    if username != Ash.CiString.value(user.username) do
      socket
      |> push_navigate(to: ~p"/#{user.username}")
    else
      socket
    end
  end

  defp redirect_if_user_has_no_about_me_story(socket, user) do
    if user_has_an_about_me_story?(user) do
      socket
    else
      socket
      |> push_navigate(to: ~p"/my/about-me")
    end
  end

  defp subscribe(socket, current_user, user) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )

      Phoenix.PubSub.subscribe(Animina.PubSub, "user_flag:created:#{user.id}")

      Phoenix.PubSub.subscribe(Animina.PubSub, "user_flag:created:#{current_user.id}")
    end
  end

  defp deduct_points_for_first_profile_view(nil, _user) do
    :ok
  end

  defp deduct_points_for_first_profile_view(current_user, user)
       when current_user.id != user.id and user.is_private do
    case Credit.profile_view_credits_by_donor_and_user!(current_user.id, user.id) do
      [] ->
        if user_has_liked_current_user_profile(user, current_user.id) do
          deduct_points(current_user, -10)
        else
          deduct_points(current_user, -20)
        end

      _ ->
        :ok
    end
  end

  defp deduct_points_for_first_profile_view(_current_user, _user) do
    :ok
  end

  defp add_points_for_viewing_to_profile(nil, _user_id, _socket) do
    :ok
  end

  defp add_points_for_viewing_to_profile(current_user_id, user_id, socket) do
    if current_user_id != user_id && connected?(socket) do
      :timer.send_interval(5000, self(), :add_points_for_viewing)
    end
  end

  defp deduct_points(user, points) do
    Credit.create!(%{
      user_id: user.id,
      points: points,
      subject: "Profile View Deduction"
    })

    PubSub.broadcast(
      Animina.PubSub,
      "credits",
      {:credit_updated, %{"points" => get_points_for_a_user(user.id), "user_id" => user.id}}
    )
  end

  defp show_optional_404_page(nil, nil) do
    true
  end

  defp show_optional_404_page(nil, _current_user) do
    true
  end

  defp show_optional_404_page(user, nil) do
    if user.is_private do
      true
    else
      false
    end
  end

  defp show_optional_404_page(_user, _current_user) do
    false
  end

  @impl true
  def handle_event("add_like", _params, socket) do
    Reaction.like(
      %{
        sender_id: socket.assigns.current_user.id,
        receiver_id: socket.assigns.user.id
      },
      actor: socket.assigns.current_user
    )

    {:noreply,
     socket
     |> assign(
       current_user_has_liked_profile?:
         current_user_has_liked_profile(socket.assigns.current_user, socket.assigns.user.id)
     )}
  end

  @impl true
  def handle_event("remove_like", _params, socket) do
    reaction =
      get_reaction_for_sender_and_receiver(socket.assigns.current_user.id, socket.assigns.user.id)

    Reaction.unlike(reaction, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(
       current_user_has_liked_profile?:
         current_user_has_liked_profile(socket.assigns.current_user, socket.assigns.user.id)
     )}
  end

  def handle_event("redirect_to_login_with_action", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "You have to register or log in before liking a profile.")
     |> push_navigate(to: ~p"/?action=like&user=#{socket.assigns.user.username}")}
  end

  @impl true
  def handle_info(:update_visit_log_entry_for_bookmark_and_user, socket) do
    case VisitLogEntry.by_id(socket.assigns.visit_log_entry.id) do
      {:ok, visit_log_entry} ->
        VisitLogEntry.update(visit_log_entry, %{
          duration: visit_log_entry.duration + 5
        })

        {:noreply, socket}

      _ ->
        :ok
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)
      |> Points.humanized_points()

    profile_points =
      ProfileViewCredits.get_updated_credit_for_user_profile(socket.assigns.user, credits)
      |> Points.humanized_points()

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)
     |> assign(profile_points: profile_points)}
  end

  def handle_info({:user, current_user}, socket) do
    if current_user.state in user_states_to_be_auto_logged_out() do
      {:noreply,
       socket
       |> push_navigate(to: "/auth/user/sign-out?auto_log_out=#{current_user.state}")}
    else
      {:noreply,
       socket
       |> assign(
         current_user_has_liked_profile?:
           current_user_has_liked_profile(current_user, socket.assigns.user.id)
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
          filter_flags(socket.assigns.user, :white, socket.assigns.language)
        )

      intersecting_red_flags_count =
        get_intersecting_flags_count(
          filter_flags(user_flag_user, :red, socket.assigns.language),
          filter_flags(socket.assigns.user, :white, socket.assigns.language)
        )

      {:noreply,
       socket
       |> assign(
         intersecting_green_flags_count: intersecting_green_flags_count,
         intersecting_red_flags_count: intersecting_red_flags_count
       )}
    else
      intersecting_green_flags_count =
        get_intersecting_flags_count(
          filter_flags(socket.assigns.current_user, :green, socket.assigns.language),
          filter_flags(user_flag_user, :white, socket.assigns.language)
        )

      intersecting_red_flags_count =
        get_intersecting_flags_count(
          filter_flags(socket.assigns.current_user, :red, socket.assigns.language),
          filter_flags(user_flag_user, :white, socket.assigns.language)
        )

      {:noreply,
       socket
       |> assign(
         intersecting_green_flags_count: intersecting_green_flags_count,
         intersecting_red_flags_count: intersecting_red_flags_count
       )}
    end
  end

  @impl true
  def handle_info(:add_points_for_viewing, socket) do
    add_credit_on_profile_view(1, socket.assigns.user, socket.assigns.current_user)
    {:noreply, socket}
  end

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

  defp add_credit_on_profile_view(points, user, current_user) do
    Credit.create!(%{
      user_id: user.id,
      points: points,
      subject: "Profile View",
      donor_id: current_user.id
    })

    PubSub.broadcast(
      Animina.PubSub,
      "credits",
      {:credit_updated, %{"points" => get_points_for_a_user(user.id), "user_id" => user.id}}
    )
  end

  defp get_points_for_a_user(user_id) do
    {:ok, user} = BasicUser.by_id(user_id)

    user.credit_points
  end

  defp user_has_an_about_me_story?(user) do
    case get_stories_for_a_user(user) do
      [] ->
        false

      stories ->
        Enum.any?(stories, fn story ->
          story.headline.subject == "About me"
        end)
    end
  end

  defp get_stories_for_a_user(user) do
    {:ok, stories} = Story.by_user_id(user.id)

    stories
  end

  defp get_intersecting_flags_count(first_flag_array, second_flag_array) do
    first_flag_array = Enum.map(first_flag_array, fn x -> x.id end)
    second_flag_array = Enum.map(second_flag_array, fn x -> x.id end)

    Enum.count(first_flag_array, &(&1 in second_flag_array))
  end

  defp current_user_has_liked_profile(nil, _current_user_id) do
    false
  end

  defp current_user_has_liked_profile(user, current_user_id) do
    case Reaction.by_sender_and_receiver_id(user.id, current_user_id) do
      {:ok, _user} ->
        true

      {:error, _} ->
        false
    end
  end

  defp user_has_liked_current_user_profile(user, current_user_id) do
    case Reaction.by_sender_and_receiver_id(user.id, current_user_id) do
      {:ok, _user} ->
        true

      {:error, _} ->
        false
    end
  end

  defp get_reaction_for_sender_and_receiver(user_id, current_user_id) do
    {:ok, reaction} =
      Reaction.by_sender_and_receiver_id(user_id, current_user_id)

    reaction
  end

  defp user_states_not_visible_to_anonymous_users do
    [
      :under_investigation,
      :banned,
      :archived,
      :hibernate,
      :incognito
    ]
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
    <div class="px-5 pb-8">
      <.profile_details
        user={@user}
        display_chat_icon={true}
        current_user={@current_user}
        display_profile_image_next_to_name={false}
        current_user_has_liked_profile?={@current_user_has_liked_profile?}
        profile_points={@profile_points}
        intersecting_green_flags={@intersecting_green_flags}
        intersecting_red_flags={@intersecting_red_flags}
        current_user_credit_points={@current_user_credit_points}
        intersecting_green_flags_count={@intersecting_green_flags_count}
        intersecting_red_flags_count={@intersecting_red_flags_count}
        years_text={gettext("years")}
        show_intersecting_flags_count={true}
        centimeters_text={gettext("cm")}
        add_new_story_title={gettext("Add a new story")}
      />

      <%= live_render(
        @socket,
        AniminaWeb.ProfileStoriesLive,
        session: %{
          "user_id" => @user.id,
          "current_user" => @current_user,
          "language" => @language
        },
        id: "profile_stories_live"
      ) %>

      <%= live_render(
        @socket,
        AniminaWeb.ProfilePostsLive,
        session: %{
          "user" => @user,
          "current_user" => @current_user,
          "language" => @language
        },
        id: "profile_posts_live"
      ) %>

      <div :if={@current_user && @current_user.id != @user.id} class="w-[100%] py-6 flex justify-end">
        <.link
          navigate={"/#{@user.username}/report"}
          id={"report-user-#{@user.username}"}
          class="flex justify-center px-2 py-1 text-sm font-semibold leading-6 text-white bg-indigo-600 rounded-md shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
        >
          <%= gettext("Report Account") %>
        </.link>
      </div>

      <.modal
        :if={@live_action in [:report]}
        id="create_report_component"
        show
        on_cancel={JS.navigate(~p"/#{@user.username}", replace: true)}
      >
        <.live_component
          module={AniminaWeb.Live.CreateReportComponent}
          id={:create_report_component}
          action={@live_action}
          current_user={@current_user}
          language={@language}
          page_title={"Report #{@user.username}"}
          user={@user}
          patch={~p"/#{@user.username}"}
        />
      </.modal>
    </div>
    """
  end

  defp filter_flags(nil, _color, _language) do
    []
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

  def get_intersecting_flags(first_flag_array, second_flag_array) do
    Enum.filter(first_flag_array, fn x ->
      x.id in Enum.map(second_flag_array, fn x -> x.id end)
    end)
  end

  defp get_translation(translations, language) do
    language = String.split(language, "-") |> Enum.at(0)

    translation =
      Enum.find(translations, nil, fn translation -> translation.language == language end)

    translation.name
  end
end
