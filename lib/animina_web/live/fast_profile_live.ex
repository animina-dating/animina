defmodule AniminaWeb.FastProfileLive do
  @moduledoc """
  Fast User Profile Liveview
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts.Bookmark
  alias Animina.Accounts.Credit
  alias Animina.Accounts.FastUser
  alias Animina.Accounts.Points
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.VisitLogEntry
  alias Animina.GenServers.ProfileViewCredits
  alias Animina.Narratives.Story
  alias Animina.Traits.UserFlags
  alias Phoenix.PubSub

  @impl true
  def mount(%{"username" => username}, %{"language" => language}, socket) do
    socket = profile_socket(socket, username, language, socket.assigns.current_user)
    {:ok, socket}
  end

  @impl true
  def mount(_params, %{"language" => _language}, socket) do
    current_user =
      socket.assigns.current_user

    if current_user do
      {:ok,
       socket
       |> push_navigate(to: ~p"/v2/#{current_user.username}")}
    else
      raise Animina.Fallback
    end
  end

  @impl true
  def mount(_params, _session, _socket) do
    raise Animina.Fallback
  end

  # for anon user
  defp profile_socket(socket, username, language, nil) do
    with {:ok, user} <- get_user_by_username(username),
         false <- show_optional_404_page(user, nil),
         false <- user.state in user_states_not_visible_to_anonymous_users(),
         false <- is_nil(user.registration_completed_at) do
      socket
      |> assign(user: user)
      |> assign(active_tab: "")
      |> assign(language: language)
      |> assign(current_user_credit_points: 0)
      |> assign(intersecting_green_flags_count: 0)
      |> assign(intersecting_red_flags_count: 0)
      |> assign(page_title: "#{user.name} - #{gettext("Animina Profile")}")
      |> assign(intersecting_green_flags: [])
      |> assign(intersecting_red_flags: [])
      |> assign(show_404_page: false)
      |> assign(profile_points: 0)
      |> assign(current_user_has_liked_profile?: false)
      |> assign(profile_points: Points.humanized_points(user.credit_points))
    else
      _ -> raise Animina.Fallback
    end
  end

  # for logged in user
  defp profile_socket(socket, username, language, current_user) do
    with {:ok, user} <- get_user_by_username(username),
         false <- show_optional_404_page(user, current_user),
         false <- is_nil(get_user_registration_completed_at(user, current_user)) do
      active_tab = if current_user.id == user.id, do: :profile, else: ""
      same_profile? = current_user.id == user.id

      # load intersecting flags
      {intersecting_green_flags, intersecting_red_flags} = intersecting_flags(user, current_user)

      intersecting_green_flags_count = Enum.count(intersecting_green_flags)
      intersecting_red_flags_count = Enum.count(intersecting_red_flags)

      intersecting_red_flags = Enum.take(intersecting_red_flags, 3)
      intersecting_green_flags = Enum.take(intersecting_green_flags, 3)

      socket =
        if connected?(socket) do
          PubSub.subscribe(Animina.PubSub, "credits")
          PubSub.subscribe(Animina.PubSub, "messages")

          PubSub.subscribe(
            Animina.PubSub,
            "#{socket.assigns.current_user.id}"
          )

          Phoenix.PubSub.subscribe(Animina.PubSub, "user_flag:created:#{user.id}")
          Phoenix.PubSub.subscribe(Animina.PubSub, "user_flag:created:#{current_user.id}")

          create_or_update_visited_bookmark(user, current_user)
          deduct_points_for_first_profile_view(user, current_user)
          add_points_for_viewing_to_profile(user, current_user)

          # visit log entry
          visit_log_entry = create_visit_log_entry_for_bookmark_and_user(user, current_user)
          update_visit_log_entry_for_bookmark_and_user(user, current_user)

          socket |> assign(visit_log_entry: visit_log_entry)
        else
          socket
        end

      socket =
        socket
        |> assign(user: user)
        |> assign(active_tab: active_tab)
        |> assign(language: language)
        |> assign(current_user_credit_points: Points.humanized_points(current_user.credit_points))
        |> assign(intersecting_green_flags: intersecting_green_flags)
        |> assign(intersecting_red_flags: intersecting_red_flags)
        |> assign(intersecting_green_flags_count: intersecting_green_flags_count)
        |> assign(intersecting_red_flags_count: intersecting_red_flags_count)
        |> assign(page_title: "#{user.name} - #{gettext("Animina Profile")}")
        |> assign(show_404_page: false)
        |> assign(profile_points: Points.humanized_points(user.credit_points))
        |> assign(
          current_user_has_liked_profile?:
            current_user_has_liked_profile(user.id, current_user.id)
        )

      if same_profile? do
        socket |> redirect_if_user_has_no_about_me_story(user)
      else
        socket
      end
    else
      _ -> raise Animina.Fallback
    end
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
  def handle_info(:add_points_for_viewing, socket) do
    add_credit_on_profile_view(1, socket.assigns.user, socket.assigns.current_user)
    {:noreply, socket}
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

  @impl true
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
           current_user_has_liked_profile(socket.assigns.user.id, current_user.id)
       )}
    end
  end

  @impl true
  def handle_info(
        %{event: "create", payload: %{data: %UserFlags{} = _user_flag}},
        socket
      ) do
    {intersecting_green_flags, intersecting_red_flags} =
      intersecting_flags(socket.assigns.user, socket.assigns.current_user)

    intersecting_green_flags_count = Enum.count(intersecting_green_flags)
    intersecting_red_flags_count = Enum.count(intersecting_red_flags)

    intersecting_red_flags = Enum.take(intersecting_red_flags, 3)
    intersecting_green_flags = Enum.take(intersecting_green_flags, 3)

    {:noreply,
     socket
     |> assign(intersecting_green_flags_count: intersecting_green_flags_count)
     |> assign(intersecting_red_flags_count: intersecting_red_flags_count)
     |> assign(intersecting_green_flags: intersecting_green_flags)
     |> assign(intersecting_red_flags: intersecting_red_flags)}
  end

  @impl true
  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
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
         current_user_has_liked_profile(socket.assigns.user.id, socket.assigns.current_user.id)
     )}
  end

  @impl true
  def handle_event("remove_like", _params, socket) do
    {:ok, reaction} =
      Reaction.by_sender_and_receiver_id(socket.assigns.current_user.id, socket.assigns.user.id)

    Reaction.unlike(reaction, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(
       current_user_has_liked_profile?:
         current_user_has_liked_profile(socket.assigns.user.id, socket.assigns.current_user.id)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class=" px-5 pb-8">
      <.profile_details
        user={@user}
        language={@language}
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
        years_text={with_locale(@language, fn -> gettext("years") end)}
        show_intersecting_flags_count={true}
        centimeters_text={with_locale(@language, fn -> gettext("cm") end)}
        add_new_story_title={with_locale(@language, fn -> gettext("Add new story") end)}
      />

      <%= live_render(
        @socket,
        AniminaWeb.ProfileStoriesLive,
        session: %{
          "user" => @user,
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
          navigate={"/v2/#{@user.username}/report"}
          id={"report-user-#{@user.username}"}
          class="flex justify-center px-2 py-1 text-sm font-semibold leading-6 text-white bg-indigo-600 rounded-md shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
        >
          <%= with_locale(@language, fn -> %>
            <%= gettext("Report Account") %>
          <% end) %>
        </.link>
      </div>

      <.modal
        :if={@live_action in [:report]}
        id="create_report_component"
        show
        on_cancel={JS.navigate(~p"/v2/#{@user.username}", replace: true)}
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

  defp get_intersecting_flags_by_color(current_user, user, current_user_color, user_color) do
    case UserFlags.intersecting_flags_by_color(
           current_user,
           user,
           current_user_color,
           user_color
         ) do
      {:ok, flags} ->
        Enum.group_by(flags, fn flag -> flag.flag_id end)
        |> Enum.map(fn {id, traits} ->
          trait = Enum.at(traits, 0)

          %{
            id: id,
            name: trait.flag.name,
            emoji: trait.flag.emoji,
            position: trait.position
          }
        end)

      _ ->
        []
    end
  end

  defp get_user_by_username(username) do
    FastUser
    |> Ash.ActionInput.for_action(:by_id_email_or_username, %{username: username})
    |> Ash.run_action()
  end

  defp create_visit_log_entry_for_bookmark_and_user(user, current_user) do
    if current_user.id != user.id do
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

  defp deduct_points_for_first_profile_view(_user, nil) do
    :ok
  end

  defp deduct_points_for_first_profile_view(user, current_user)
       when current_user.id != user.id and user.is_private do
    case Credit.profile_view_credits_by_donor_and_user!(current_user.id, user.id) do
      [] ->
        if user_has_liked_current_user_profile(user.id, current_user.id) do
          deduct_points(current_user, -10)
        else
          deduct_points(current_user, -20)
        end

      _ ->
        :ok
    end
  end

  defp deduct_points_for_first_profile_view(_user, _current_user) do
    :ok
  end

  defp deduct_points(user, points) do
    Credit.create!(%{
      user_id: user.id,
      points: points,
      subject: "Profile View Deduction"
    })
  end

  defp add_points_for_viewing_to_profile(_user, nil) do
    :ok
  end

  defp add_points_for_viewing_to_profile(user, current_user) do
    if current_user.id != user.id do
      :timer.send_interval(5000, self(), :add_points_for_viewing)
    end
  end

  defp add_credit_on_profile_view(points, user, current_user) do
    Credit.create!(%{
      user_id: user.id,
      points: points,
      subject: "Profile View",
      donor_id: current_user.id
    })
  end

  defp redirect_if_user_has_no_about_me_story(socket, user) do
    if user_has_an_about_me_story?(user.id) do
      socket
    else
      socket
      |> push_navigate(to: ~p"/my/about-me")
    end
  end

  defp user_has_an_about_me_story?(user_id) do
    {:ok, story} = Story.about_story_by_user(user_id, not_found_error?: false)

    case story do
      nil ->
        false

      _ ->
        true
    end
  end

  defp create_or_update_visited_bookmark(user, current_user) do
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

  defp user_has_liked_current_user_profile(user_id, current_user_id) do
    case Reaction.by_sender_and_receiver_id(user_id, current_user_id) do
      {:ok, _user} ->
        true

      {:error, _} ->
        false
    end
  end

  defp current_user_has_liked_profile(user_id, current_user_id) do
    case Reaction.by_sender_and_receiver_id(current_user_id, user_id) do
      {:ok, _user} ->
        true

      {:error, _} ->
        false
    end
  end

  defp update_visit_log_entry_for_bookmark_and_user(user, current_user) do
    if current_user.id != user.id do
      :timer.send_interval(5000, self(), :update_visit_log_entry_for_bookmark_and_user)
    end
  end

  defp intersecting_flags(user, current_user) do
    intersecting_green_flags =
      get_intersecting_flags_by_color(current_user.id, user.id, :green, :white)

    intersecting_red_flags =
      get_intersecting_flags_by_color(current_user.id, user.id, :red, :white)

    {intersecting_green_flags, intersecting_red_flags}
  end

  defp get_user_registration_completed_at(user, current_user) do
    # we set it to be the current time and date by default so that we can display the profile to the user if
    # the user is the same as the current user

    if current_user.id == user.id do
      DateTime.utc_now()
    else
      user.registration_completed_at
    end
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
end
