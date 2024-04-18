defmodule AniminaWeb.ProfileLive do
  @moduledoc """
  User Profile Liveview
  """

  use AniminaWeb, :live_view
  alias Animina.Accounts
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Photo
  alias Animina.Accounts.Points
  alias Animina.GenServers.ProfileViewCredits
  alias Animina.Narratives
  alias Animina.Traits
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
          end

          if connected?(socket) && socket.assigns.current_user.id != user.id do
            # prevent the points to be added when a user is viewing this or her own profile
            :timer.send_interval(5000, self(), :add_points_for_viewing)
          end

          stories_and_flags = fetch_stories_and_flags(user, language)

          {current_user_green_flags, current_user_red_flags} =
            fetch_green_and_red_flags(current_user.id, language)

          intersecting_green_flags_count =
            get_intersecting_flags(
              fetch_flags(current_user.id, :green, language),
              fetch_flags(user.id, :white, language)
            )

          intersecting_red_flags_count =
            get_intersecting_flags(
              fetch_flags(current_user.id, :red, language),
              fetch_flags(user.id, :white, language)
            )

          socket
          |> assign(user: user)
          |> assign(intersecting_green_flags_count: intersecting_green_flags_count)
          |> assign(intersecting_red_flags_count: intersecting_red_flags_count)
          |> assign(profile_points: Points.humanized_points(user.credit_points))
          |> assign(current_user_green_flags: current_user_green_flags)
          |> assign(current_user_red_flags: current_user_red_flags)
          |> assign(stories_and_flags: stories_and_flags)

        _ ->
          socket
          |> assign(user: nil)
      end

    {:ok, socket}
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

  defp get_intersecting_flags(first_flag_array, second_flag_array) do
    first_flag_array = Enum.map(first_flag_array, fn x -> x.flag.id end)
    second_flag_array = Enum.map(second_flag_array, fn x -> x.flag.id end)

    Enum.count(first_flag_array, fn x -> Enum.member?(second_flag_array, x) end)
  end

  @impl true

  def render(assigns) do
    ~H"""
    <div class="px-5">
      <div :if={@user == nil}>
        <%= gettext("There was an error loading the user's profile") %>
      </div>

      <div :if={@user} class="pb-4">
        <h1 class="text-2xl font-semibold dark:text-white">
          <%= @user.name %>
        </h1>

        <div class="pt-2">
          <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
            <%= @user.age %> <%= gettext("years") %>
          </span>
          <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
            <%= @user.height %>   <%= gettext("cm") %>
          </span>
          <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
            📍 <%= @user.city.name %>
          </span>
          <span
            :if={@user.occupation}
            class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md"
          >
            🔧 <%= @user.occupation %>
          </span>
          <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
            <%= @profile_points %>
          </span>
          <span :if={@current_user != @user}>
            <span
              :if={@intersecting_green_flags_count != 0}
              class="inline-flex items-center gap-2 px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md"
            >
              <%= @intersecting_green_flags_count %> <p class="w-3 h-3 bg-green-500 rounded-full" />
            </span>
            <span
              :if={@intersecting_red_flags_count != 0}
              class="inline-flex items-center gap-2 px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md"
            >
              <%= @intersecting_red_flags_count %> <p class="w-3 h-3 bg-red-500 rounded-full" />
            </span>
          </span>
        </div>
      </div>

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

  defp fetch_green_and_red_flags(user_id, language) do
    green_flags =
      fetch_flags(user_id, :green, language)
      |> Enum.map(& &1.flag.id)

    red_flags =
      fetch_flags(user_id, :red, language)
      |> Enum.map(& &1.flag.id)

    {green_flags, red_flags}
  end

  defp fetch_flags(user_id, color, language) do
    user_flags =
      Traits.UserFlags
      |> Ash.Query.for_read(:by_user_id, %{id: user_id, color: color})
      |> Ash.Query.load(flag: [:category])
      |> Traits.read!()

    Enum.map(user_flags, fn user_flag ->
      %{
        id: user_flag.id,
        position: user_flag.position,
        flag: %{
          id: user_flag.flag.id,
          name: get_translation(user_flag.flag.flag_translations, language),
          emoji: user_flag.flag.emoji
        },
        category: %{
          id: user_flag.flag.category.id,
          name: get_translation(user_flag.flag.category.category_translations, language)
        }
      }
    end)
  end

  defp fetch_stories_and_flags(user, language) do
    stories = fetch_stories(user.id)

    flags =
      fetch_flags(user.id, :white, language)

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

  defp fetch_stories(user_id) do
    Narratives.Story
    |> Ash.Query.for_read(:by_user_id, %{user_id: user_id})
    |> Narratives.read!(page: [limit: 20])
    |> then(& &1.results)
  end
end
