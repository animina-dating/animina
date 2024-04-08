defmodule AniminaWeb.ProfileLive do
  @moduledoc """
  User Profile Liveview
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Narratives
  alias Animina.Traits
  alias Phoenix.LiveView.AsyncResult

  @impl true
  def mount(%{"username" => username}, %{"language" => language} = _session, socket) do
    socket =
      Accounts.User.by_username(username)
      |> case do
        {:ok, user} ->
          socket
          |> assign(language: language)
          |> assign(active_tab: :home)
          |> assign(user: user)
          |> assign(profile_user_height_for_figure: (user.height / 2) |> trunc())
          |> assign(
            :current_user_height_for_figure,
            (socket.assigns.current_user.height / 2) |> trunc()
          )
          |> assign(stories: fetch_stories(user.id))
          |> assign(flags: AsyncResult.loading())
          |> start_async(:fetch_flags, fn -> fetch_flags(user.id, :white, language) end)

        _ ->
          socket
          |> assign(language: language)
          |> assign(active_tab: :home)
          |> assign(user: nil)
      end

    {:ok, socket}
  end

  @impl true
  def handle_async(:fetch_flags, {:ok, fetched_flags}, socket) do
    %{flags: flags} = socket.assigns

    {:noreply,
     socket
     |> assign(
       :flags,
       AsyncResult.ok(flags, fetched_flags)
     )
     |> stream(:flags, fetched_flags)}
  end

  @impl true
  def handle_async(:fetch_flags, {:exit, reason}, socket) do
    %{flags: flags} = socket.assigns

    {:noreply, assign(socket, :flags, AsyncResult.failed(flags, {:exit, reason}))}
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

  defp fetch_about_story(user_id) do
    fetch_stories(user_id)
    |> Enum.filter(fn story -> story.headline.subject == "About me" end)
    |> List.first()
  end

  def fetch_non_about_me_stories(user_id) do
    fetch_stories(user_id)
    |> Enum.filter(fn story -> story.headline.subject != "About me" end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-5">
      <div :if={@user == nil}>
        <%= gettext("There was an error loading the user's profile") %>
      </div>

      <div :if={@user} class="pb-4">
        <h1 class="text-2xl font-semibold dark:text-white"><%= @user.name %></h1>
        <div class="pt-2">
          <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
            @<%= @user.username %>
          </span>
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

      <.stories_display stories={@stories} current_user={@current_user} />

      <div class="mt-8 space-y-4">
        <h2 class="text-xl font-bold dark:text-white"><%= gettext("Flags") %></h2>

        <.async_result :let={_flags} assign={@flags}>
          <:loading>
            <div class="pt-4 space-y-4">
              <.flag_card_loading />
              <.flag_card_loading />
              <.flag_card_loading />
              <.flag_card_loading />
            </div>
          </:loading>
          <:failed :let={_failure}><%= gettext("There was an error loading flags") %></:failed>
          <.flags_card streams={@streams} />
        </.async_result>
      </div>
    </div>

    <div>
      <.height_visualization_card
        user={@user}
        current_user={@current_user}
        title={gettext("Height")}
        measurement_unit={gettext("cm")}
        current_user_height_for_figure={@current_user_height_for_figure}
        profile_user_height_for_figure={@profile_user_height_for_figure}
      />
    </div>
    """
  end

  defp get_translation(translations, language) do
    language = String.split(language, "-") |> Enum.at(0)

    translation =
      Enum.find(translations, nil, fn translation -> translation.language == language end)

    translation.name
  end
end
