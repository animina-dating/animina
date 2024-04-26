defmodule AniminaWeb.ProfileLive do
  @moduledoc """
  User Profile Liveview
  """

  use AniminaWeb, :live_view
  alias Animina.Accounts
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Photo
  alias Animina.Accounts.Points
  alias Animina.Accounts.Reaction
  alias Animina.GenServers.ProfileViewCredits
  alias Animina.Narratives
  alias Phoenix.PubSub

  @impl true
  def mount(%{"username" => username}, %{"language" => language} = _session, socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(active_tab: :home)

    current_user =
      case socket.assigns.current_user do
        nil -> nil
        _ -> socket.assigns.current_user
      end

    socket =
      case Accounts.User.by_username(username) do
        {:ok, user} ->
          socket
          |> assign(:user, user)

          if connected?(socket) do
            PubSub.subscribe(Animina.PubSub, "credits")
            PubSub.subscribe(Animina.PubSub, "messages")
          end

          if connected?(socket) && socket.assigns.current_user.id != user.id do
            # prevent the points to be added when a user is viewing this or her own profile
            :timer.send_interval(5000, self(), :add_points_for_viewing)
          end

          stories_and_flags = fetch_stories_and_flags(user, language)

          {current_user_green_flags, current_user_red_flags} =
            fetch_green_and_red_flags_ids(current_user, language)

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

          socket
          |> assign(user: user)
          |> assign(intersecting_green_flags_count: intersecting_green_flags_count)
          |> assign(intersecting_red_flags_count: intersecting_red_flags_count)
          |> assign(profile_points: Points.humanized_points(user.credit_points))
          |> assign(current_user_green_flags: current_user_green_flags)
          |> assign(current_user_red_flags: current_user_red_flags)
          |> assign(stories_and_flags: stories_and_flags)
          |> assign(
            current_user_has_liked_profile?:
              current_user_has_liked_profile(socket.assigns.current_user.id, user.id)
          )

        _ ->
          socket
          |> assign(user: nil)
      end

    if username != Ash.CiString.value(socket.assigns.user.username) do
      {:ok,
       socket
       |> push_redirect(to: ~p"/#{socket.assigns.user.username}")}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("destroy_story", %{"id" => id}, socket) do
    {:ok, story} = Narratives.Story.by_id(id)

    case Narratives.Story.destroy(story) do
      :ok ->
        {:noreply,
         socket
         |> assign(
           :stories_and_flags,
           fetch_stories_and_flags(socket.assigns.user, socket.assigns.language)
         )}

      {:error, %Ash.Error.Invalid{} = changeset} ->
        case changeset.errors do
          [%Ash.Error.Changes.InvalidAttribute{message: message}]
          when message == "would leave records behind" ->
            Photo.destroy(story.photo)
            Narratives.Story.destroy(story)

            {:noreply,
             socket
             |> assign(
               :stories_and_flags,
               fetch_stories_and_flags(socket.assigns.user, socket.assigns.language)
             )}

          _ ->
            {:noreply,
             socket
             |> put_flash(:error, gettext("An error occurred while deleting the story"))}
        end
    end
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
         current_user_has_liked_profile(socket.assigns.current_user.id, socket.assigns.user.id)
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
         current_user_has_liked_profile(socket.assigns.current_user.id, socket.assigns.user.id)
     )}
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_user(socket, credits)

    {:ok, profile} = Accounts.User.by_id(socket.assigns.user.id)

    profile_points =
      ProfileViewCredits.get_updated_credit_for_profile(profile, credits)

    {:noreply,
     socket
     |> assign(profile_points: Points.humanized_points(profile_points))
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  @impl true
  def handle_info(:add_points_for_viewing, socket) do
    add_credit_on_profile_view(1, socket.assigns.user)
    {:noreply, socket}
  end

  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  def handle_info(:create_credit_for_viewing, socket) do
    user = socket.assigns.user
    current_user = socket.assigns.current_user

    Credit.create(%{
      user_id: user.id,
      donor_id: current_user.id,
      points: 1,
      subject: "Profile view by #{current_user.username}"
    })

    {:noreply, socket}
  end

  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
  end

  defp add_credit_on_profile_view(points, user) do
    Credit.create!(%{
      user_id: user.id,
      points: points,
      subject: "Profile View"
    })

    PubSub.broadcast(
      Animina.PubSub,
      "credits",
      {:credit_updated, %{"points" => get_points_for_a_user(user.id), "user_id" => user.id}}
    )
  end

  defp get_points_for_a_user(user_id) do
    {:ok, user} = Accounts.User.by_id(user_id)
    user.credit_points
  end

  defp get_intersecting_flags_count(first_flag_array, second_flag_array) do
    first_flag_array = Enum.map(first_flag_array, fn x -> x.id end)
    second_flag_array = Enum.map(second_flag_array, fn x -> x.id end)

    Enum.filter(first_flag_array, &(&1 in second_flag_array))
    |> Enum.count()
  end

  defp current_user_has_liked_profile(user_id, current_user_id) do
    case Reaction.by_sender_and_receiver_id(user_id, current_user_id) do
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

  @impl true

  def render(assigns) do
    ~H"""
    <div class="px-5">
      <div :if={@user == nil}>
        <%= gettext("There was an error loading the user's profile") %>
      </div>

      <.profile_details
        user={@user}
        current_user={@current_user}
        current_user_has_liked_profile?={@current_user_has_liked_profile?}
        profile_points={@profile_points}
        intersecting_green_flags_count={@intersecting_green_flags_count}
        intersecting_red_flags_count={@intersecting_red_flags_count}
        years_text={gettext("years")}
        centimeters_text={gettext("cm")}
      />

      <.stories_display
        stories_and_flags={@stories_and_flags}
        current_user={@current_user}
        current_user_green_flags={@current_user_green_flags}
        current_user_red_flags={@current_user_red_flags}
        add_new_story_title={gettext("Add a new story")}
        delete_story_modal_text={gettext("Are you sure?")}
        user={@user}
      />
    </div>
    """
  end

  defp fetch_green_and_red_flags_ids(user, language) do
    green_flags =
      filter_flags(user, :green, language)
      |> Enum.map(fn x -> x.id end)

    red_flags =
      filter_flags(user, :red, language)
      |> Enum.map(fn x -> x.id end)

    {green_flags, red_flags}
  end

  defp filter_flags(user, color, language) do
    user_flags =
      user.flags
      |> Enum.filter(fn x ->
        find_user_flag_for_a_flag(user.flags_join_assoc, x).color == color
      end)

    Enum.map(user_flags, fn user_flag ->
      %{
        id: user_flag.id,
        name: get_translation(user_flag.flag_translations, language),
        emoji: user_flag.emoji
      }
    end)
  end

  defp find_user_flag_for_a_flag(user_flags, flag) do
    Enum.find(user_flags, fn x -> x.flag_id == flag.id end)
  end

  defp fetch_stories_and_flags(user, language) do
    stories = user.stories

    flags =
      filter_flags(user, :white, language)

    array = Enum.map(1..(5 * length(stories)), fn _ -> %{} end)

    flags =
      (flags ++ array)
      |> Enum.chunk_every(5)

    Enum.zip(stories, flags)
  end

  defp get_translation(translations, language) do
    language = String.split(language, "-") |> Enum.at(0)

    translation =
      Enum.find(translations, nil, fn translation -> translation.language == language end)

    translation.name
  end
end
