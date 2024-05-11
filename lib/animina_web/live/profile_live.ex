defmodule AniminaWeb.ProfileLive do
  @moduledoc """
  User Profile Liveview
  """

  use AniminaWeb, :live_view
  alias Animina.Accounts
  alias Animina.Accounts.BasicUser
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Points
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.User
  alias Animina.GenServers.ProfileViewCredits
  alias Phoenix.PubSub

  require Ash.Query

  @impl true
  def mount(%{"username" => username}, %{"language" => language, "user" => _} , socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(active_tab: :home)

    current_user =
      socket.assigns.current_user

    socket =
      case Accounts.User.by_username_as_an_actor(username, actor: current_user) do
        {:ok, user} ->
          socket
          |> assign(:user, user)

          subscribe(socket, current_user, user)

          if connected?(socket) do
            deduct_points_for_first_profile_view(current_user, user)
          end

          add_points_for_viewing_to_profile(current_user.id, user.id, socket)

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
          |> assign(
            current_user_credit_points:
              Points.humanized_points(socket.assigns.current_user.credit_points)
          )
          |> assign(show_404_page: show_optional_404_page(user, current_user))
          |> assign(intersecting_green_flags_count: intersecting_green_flags_count)
          |> assign(intersecting_red_flags_count: intersecting_red_flags_count)
          |> assign(profile_points: Points.humanized_points(user.credit_points))
          |> assign(
            current_user_has_liked_profile?:
              current_user_has_liked_profile(socket.assigns.current_user, user.id)
          )
          |> redirect_if_username_is_different(username, user)

        _ ->
          socket
          |> assign(show_404_page: true)
      end

    {:ok, socket}
  end

  def mount(%{"username" => username}, %{"language" => language} , socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(active_tab: :home)

    socket =
      case Accounts.User.by_username(username) do
        {:ok, user} ->
          socket
          |> assign(user: user)
          |> assign(current_user_credit_points: 0)
          |> assign(show_404_page: show_optional_404_page(user, nil))
          |> assign(intersecting_green_flags_count: 0)
          |> assign(intersecting_red_flags_count: 0)
          |> assign(profile_points: Points.humanized_points(user.credit_points))
          |> assign(current_user_has_liked_profile?: current_user_has_liked_profile(nil, user.id))
          |> redirect_if_username_is_different(username, user)

        _ ->
          socket
          |> assign(show_404_page: true)
      end

    {:ok, socket}
  end

  defp redirect_if_username_is_different(socket, username, user) do
    if username != Ash.CiString.value(user.username) do
      socket
      |> push_redirect(to: ~p"/#{user.username}")
    else
      socket
    end
  end

  defp subscribe(socket, _current_user, _user) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.username}"
      )
    end
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

    broadcast_user(socket)

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
    broadcast_user(socket)

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
     |> push_redirect(to: ~p"/?action=like&user=#{socket.assigns.user.username}")}
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
    if current_user.id == socket.assigns.user.id do
      {:noreply,
       socket
       |> assign(current_user: current_user)
       |> assign(user: current_user)
       |> assign(
         intersecting_green_flags_count:
           get_intersecting_flags_count(
             filter_flags(current_user, :green, socket.assigns.language),
             filter_flags(current_user, :white, socket.assigns.language)
           )
       )
       |> assign(
         intersecting_red_flags_count:
           get_intersecting_flags_count(
             filter_flags(current_user, :red, socket.assigns.language),
             filter_flags(current_user, :white, socket.assigns.language)
           )
       )
       |> assign(
         current_user_has_liked_profile?:
           current_user_has_liked_profile(current_user, current_user.id)
       )}
    else
      {:noreply,
       socket
       |> assign(
         intersecting_green_flags_count:
           get_intersecting_flags_count(
             filter_flags(current_user, :green, socket.assigns.language),
             filter_flags(socket.assigns.user, :white, socket.assigns.language)
           )
       )
       |> assign(
         intersecting_red_flags_count:
           get_intersecting_flags_count(
             filter_flags(current_user, :red, socket.assigns.language),
             filter_flags(socket.assigns.user, :white, socket.assigns.language)
           )
       )
       |> assign(
         current_user_has_liked_profile?:
           current_user_has_liked_profile(current_user, socket.assigns.user.id)
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

  defp broadcast_user(socket) do
    current_user = User.by_id!(socket.assigns.current_user.id)

    PubSub.broadcast(
      Animina.PubSub,
      "#{current_user.username}",
      {:user, current_user}
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-5">
      <%= if @show_404_page  do %>
        <.error_profile_component
          text={gettext("This profile either doesn't exist or you don't have enough points to access it. You need 20 points to access a profile page.")}
        />
      <% else %>
        <.profile_details
          user={@user}
          current_user={@current_user}
          current_user_has_liked_profile?={@current_user_has_liked_profile?}
          profile_points={@profile_points}
          current_user_credit_points={@current_user_credit_points}
          intersecting_green_flags_count={@intersecting_green_flags_count}
          intersecting_red_flags_count={@intersecting_red_flags_count}
          years_text={gettext("years")}
          centimeters_text={gettext("cm")}
          add_new_story_title={gettext("Add a new story")}
        />

        <%!-- <.stories_display
          stories_and_flags={@stories_and_flags}
          current_user={@current_user}
          current_user_green_flags={@current_user_green_flags}
          current_user_red_flags={@current_user_red_flags}
          add_new_story_title={gettext("Add a new story")}
          delete_story_modal_text={gettext("Are you sure?")}
          user={@user}
        /> --%>

        <%= live_render(
          @socket,
          AniminaWeb.ProfileStoriesLive,
          session: %{
            "user_id" => @user.id,
            "current_user_id" => @current_user.id,
            "language" => @language
          },
          id: "profile_stories_live:#{@user.id}",
          sticky: true
        ) %>
      <% end %>
    </div>
    """
  end

  defp filter_flags(nil, _color, _language) do
    []
  end

  defp filter_flags(user, color, language) do
    traits =
      user.traits
      |> Enum.filter(fn trait ->
        trait.color == color and trait.flag != nil
      end)

    Enum.map(traits, fn trait ->
      %{
        id: trait.flag.id,
        name: get_translation(trait.flag.flag_translations, language),
        emoji: trait.flag.emoji
      }
    end)
  end

  defp get_translation(translations, language) do
    language = String.split(language, "-") |> Enum.at(0)

    translation =
      Enum.find(translations, nil, fn translation -> translation.language == language end)

    translation.name
  end
end
