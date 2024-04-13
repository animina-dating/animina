defmodule AniminaWeb.ProfileLive do
  @moduledoc """
  User Profile Liveview
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Credit
  alias Animina.Narratives
  alias Animina.Traits

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
            setup_points_timer(user, current_user)
          end

          stories_and_flags = fetch_stories_and_flags(user, language)

          {current_user_green_flags, current_user_red_flags} =
            fetch_current_user_flags(current_user, language)

          socket
          |> assign(user: user)
          |> assign(current_user_green_flags: current_user_green_flags)
          |> assign(current_user_red_flags: current_user_red_flags)
          |> assign(profile_user_height_for_figure: (user.height / 2) |> trunc())
          |> assign(
            :current_user_height_for_figure,
            (current_user.height / 2) |> trunc()
          )
          |> assign(stories_and_flags: stories_and_flags)

        _ ->
          socket
          |> assign(user: nil)
      end

    {:ok, socket}
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
          <%= @user.name %> <span class="text-base">@<%= @user.username %></span>
        </h1>

        <div class="pt-2">
          <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
            <%= @user.age %> <%= gettext("years") %>
          </span>
          <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
            <%= @user.height %> cm
          </span>
          <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
            <%= @user.city.name %>
          </span>
          <span
            :if={@user.occupation}
            class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md"
          >
            <%= @user.occupation %>
          </span>
        </div>
      </div>

      <.stories_display
        stories_and_flags={@stories_and_flags}
        current_user={@current_user}
        current_user_green_flags={@current_user_green_flags}
        current_user_red_flags={@current_user_red_flags}
      />
    </div>

    <.height_visualization_card
      user={@user}
      current_user={@current_user}
      title={gettext("Height")}
      measurement_unit={gettext("cm")}
      current_user_height_for_figure={@current_user_height_for_figure}
      profile_user_height_for_figure={@profile_user_height_for_figure}
    />
    """
  end

  @impl true
  def handle_info(:add_points_for_viewing, socket) do
    add_viewing_credits(socket.assigns.user, socket.assigns.current_user)
    {:noreply, socket}
  end

  defp add_viewing_credits(user, current_user, points \\ 1) do
    Credit.create!(%{
      user_id: user.id,
      donor_id: current_user.id,
      points: points,
      subject: "Profile View by #{current_user.username}"
    })
  end

  defp setup_points_timer(current_user, current_user), do: nil

  defp setup_points_timer(_user, _current_user) do
    :timer.send_interval(2000, self(), :add_points_for_viewing)
  end

  defp fetch_current_user_flags(current_user, language) do
    green_flags =
      fetch_flags(current_user.id, :green, language)
      |> Enum.map(& &1.flag.id)

    red_flags =
      fetch_flags(current_user.id, :red, language)
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

  defp fetch_stories(user_id) do
    Narratives.Story
    |> Ash.Query.for_read(:by_user_id, %{user_id: user_id})
    |> Narratives.read!(page: [limit: 20])
    |> then(& &1.results)
  end

  defp fetch_stories_and_flags(user, language) do
    stories = fetch_stories(user.id)

    chunks_flags =
      fetch_flags(user.id, :white, language)
      |> Enum.chunk_every(5)

    Enum.zip(stories, chunks_flags)
  end

  defp get_translation(translations, language) do
    language = String.split(language, "-") |> Enum.at(0)

    translation =
      Enum.find(translations, nil, fn translation -> translation.language == language end)

    translation.name
  end
end
