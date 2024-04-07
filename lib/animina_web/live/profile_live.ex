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
          |> assign(:about_story, fetch_about_story(user.id))
          |> assign(stories: AsyncResult.loading())
          |> assign(flags: AsyncResult.loading())
          |> start_async(:fetch_flags, fn -> fetch_flags(user.id, :white, language) end)
          |> start_async(:fetch_stories, fn ->
            fetch_all_stories_apart_from_about_story(user.id)
          end)

        _ ->
          socket
          |> assign(language: language)
          |> assign(active_tab: :home)
          |> assign(user: nil)
      end

    {:ok, socket}
  end

  @impl true
  def handle_async(:fetch_stories, {:ok, fetched_stories}, socket) do
    %{stories: stories} = socket.assigns

    {:noreply,
     socket
     |> assign(
       :stories,
       AsyncResult.ok(stories, fetched_stories)
     )
     |> stream(:stories, fetched_stories)}
  end

  @impl true
  def handle_async(:fetch_stories, {:exit, reason}, socket) do
    %{stories: stories} = socket.assigns
    {:noreply, assign(socket, :stories, AsyncResult.failed(stories, {:exit, reason}))}
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
    |> Enum.group_by(fn flag -> {flag.category.id, flag.category.name} end)
    |> Enum.map(fn {{category_id, category_name}, v} ->
      %{id: category_id, name: category_name, flags: v}
    end)
  end

  defp fetch_stories(user_id) do
    Narratives.Story
    |> Ash.Query.for_read(:by_user_id, %{user_id: user_id})
    |> Narratives.read!(page: [limit: 20])
    |> then(& &1.results)
  end

  def fetch_all_stories_apart_from_about_story(user_id) do
    fetch_stories(user_id)
    |> Enum.filter(fn story -> story.headline.subject != "About me" end)
  end

  def fetch_about_story(user_id) do
    fetch_stories(user_id)
    |> Enum.filter(fn story -> story.headline.subject == "About me" end)
    |> List.first()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-5 pb-8 space-y-4">
      <div :if={@user == nil}>
        <%= gettext("There was an error loading the user's profile") %>
      </div>

      <div :if={@user != nil}>
        <div class="flex  w-[100%] flex xl:flex-row flex-col justify-between ">
          <.square_user_profile_photo user={@user} />
          <div class="p-4 flex flex-col gap-2  w-[100%] xl:w-[65%]">
            <h3 class="text-lg font-semibold dark:text-white"><%= @user.name %></h3>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-100">@<%= @user.username %></p>
            <div class="w-[100%] flex md:flex-row flex-col gap-4 justify-between ">
              <div class="flex xl:w-[48%] w-[100%] flex-col gap-4">
                <div class="flex flex-col gap-1">
                  <.profile_location_card user={@user} />
                  <.profile_occupation_card user={@user} />
                  <.profile_age_card user={@user} />
                  <.profile_gender_card user={@user} />
                </div>

                <.height_visualization_card
                  user={@user}
                  current_user={@current_user}
                  title={gettext("Height")}
                  measurement_unit={gettext("cm")}
                  current_user_height_for_figure={@current_user_height_for_figure}
                  profile_user_height_for_figure={@profile_user_height_for_figure}
                />
              </div>
              <div class="xl:w-[48%] w-[100%]">
                <.profile_about_story_card title={gettext("About Me")} about_story={@about_story} />
              </div>
            </div>
          </div>
        </div>

        <div class="mt-8 space-y-4">
          <h2 class="text-xl font-bold dark:text-white"><%= gettext("My Stories") %></h2>
          <.async_result :let={_stories} assign={@stories}>
            <:loading>
              <div class="space-y-4">
                <.story_card_loading />
                <.story_card_loading />
                <.story_card_loading />
              </div>
            </:loading>
            <:failed :let={_failure}><%= gettext("There was an error loading stories") %></:failed>

            <.stories_component
              streams={@streams}
              language={@language}
              current_user={@current_user}
              user={@user}
            />
          </.async_result>
        </div>

        <div class="mt-8 space-y-4">
          <h2 class="text-xl font-bold dark:text-white"><%= gettext("My White Flags") %></h2>

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
