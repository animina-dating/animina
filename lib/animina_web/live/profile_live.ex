defmodule AniminaWeb.ProfileLive do
  @moduledoc """
  User Profile Liveview
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Credit
  alias Animina.Narratives
  alias Animina.Traits
  alias Phoenix.PubSub
  alias Animina.Accounts.BasicUser

  @impl true
  def mount(%{"username" => username}, %{"language" => language} = _session, socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(active_tab: :home)

    socket =
      case Accounts.User.by_username(username) do
        {:ok, user} ->
          socket
          |> assign(:user, user)

          # prevent the points to be added when a user is viewing this or her own profile

          if connected?(socket) do
            PubSub.subscribe(Animina.PubSub, "credits")

            if user.id != socket.assigns.current_user.id do
              :timer.send_interval(5000, self(), :add_points_for_viewing)
            end
          end

          stories = fetch_stories(user.id)

          chunks_flags =
            fetch_flags(user.id, :white, language)
            |> Enum.chunk_every(5)

          stories_and_flags = Enum.zip(stories, chunks_flags)

          current_user_green_flags =
            fetch_flags(socket.assigns.current_user.id, :green, language)
            |> Enum.map(& &1.flag.id)

          current_user_red_flags =
            fetch_flags(socket.assigns.current_user.id, :red, language)
            |> Enum.map(& &1.flag.id)

          socket
          |> assign(user: user)
          |> assign(credit: user.credit_points)
          |> assign(current_user_green_flags: current_user_green_flags)
          |> assign(current_user_red_flags: current_user_red_flags)
          |> assign(profile_user_height_for_figure: (user.height / 2) |> trunc())
          |> assign(
            :current_user_height_for_figure,
            (socket.assigns.current_user.height / 2) |> trunc()
          )
          |> assign(stories_and_flags: stories_and_flags)

        _ ->
          socket
          |> assign(user: nil)
      end

    {:ok, socket}
  end

  @impl true
  def handle_info({:added, credits}, socket) do
    credit =
      case Enum.find(credits, fn credit -> credit["user_id"] == socket.assigns.user.id end) do
        nil -> socket.assigns.user.credit_points
        credit -> credit["points"]
      end

    {:noreply,
     socket
     |> assign(credit: credit)}
  end

  def handle_info(:add_points_for_viewing, socket) do
    add_credit_on_profile_view(1, socket.assigns.user)
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

  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
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

  defp get_points_for_a_user(user_id) do
    {:ok, user} = Accounts.User.by_id(user_id)
    user.credit_points
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-5">
      <div :if={@user == nil}>
        <%= gettext("There was an error loading the user's profile") %>
      </div>

      <p class="text-white"><%= @credit %></p>
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

  defp get_translation(translations, language) do
    language = String.split(language, "-") |> Enum.at(0)

    translation =
      Enum.find(translations, nil, fn translation -> translation.language == language end)

    translation.name
  end
end
