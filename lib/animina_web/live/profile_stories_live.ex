defmodule AniminaWeb.ProfileStoriesLive do
  @moduledoc """
  User Stories Liveview
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Narratives
  alias Animina.Traits
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.PubSub

  require Ash.Query

  @impl true
  def mount(
        _params,
        %{"user_id" => user_id, "current_user" => current_user, "language" => language},
        socket
      ) do
    socket =
      socket
      |> assign(stories_and_flags: AsyncResult.loading())
      |> assign(language: language)
      |> assign(current_user: current_user)
      |> assign(user: Accounts.BasicUser.by_id!(user_id))
      |> start_async(:fetch_stories_and_flags, fn ->
        fetch_stories_and_flags(user_id, language)
      end)

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_async(:fetch_stories_and_flags, {:ok, data}, socket) do
    %{stories_and_flags: stories_and_flags, current_user: current_user, language: language} =
      socket.assigns

    current_user_green_flags =
      if current_user do
        fetch_flags(current_user.id, :green) |> filter_flags(:green, language)
      else
        []
      end

    current_user_red_flags =
      if current_user do
        fetch_flags(current_user.id, :red) |> filter_flags(:red, language)
      else
        []
      end

    {:noreply,
     socket
     |> assign(
       :stories_and_flags,
       AsyncResult.ok(stories_and_flags, data)
     )
     |> assign(stories_and_flags_items: data)
     |> assign(current_user_green_flags: current_user_green_flags)
     |> assign(current_user_red_flags: current_user_red_flags)
     |> stream(:stories_and_flags, data)}
  end

  @impl true
  def handle_async(:fetch_stories_and_flags, {:exit, reason}, socket) do
    %{stories_and_flags: stories_and_flags} = socket.assigns

    {:noreply,
     assign(socket, :stories_and_flags, AsyncResult.failed(stories_and_flags, {:exit, reason}))}
  end

  @impl true
  def handle_event("destroy_story", %{"id" => id, "dom_id" => dom_id}, socket) do
    {:ok, story} = Narratives.Story.by_id(id)

    case Narratives.Story.destroy(story) do
      :ok ->
        broadcast_user(socket)

        {:noreply,
         socket
         |> delete_story_by_dom_id(dom_id)}

      {:error, %Ash.Error.Invalid{} = changeset} ->
        case changeset.errors do
          [%Ash.Error.Changes.InvalidAttribute{message: message}]
          when message == "would leave records behind" ->
            Accounts.Photo.destroy(story.photo)
            Narratives.Story.destroy(story)

            broadcast_user(socket)

            {:noreply,
             socket
             |> delete_story_by_dom_id(dom_id)

            }

          _ ->
            {:noreply,
             socket
             |> put_flash(:error, gettext("An error occurred while deleting the story"))}
        end
    end
  end

  @impl true
  def handle_info(
        %{event: "update", payload: %{data: %Accounts.Photo{} = photo}},
        socket
      ) do
    {:noreply, update_photo(socket, photo)}
  end

  @impl true
  def handle_info(
        %{event: "approve", payload: %{data: %Accounts.Photo{} = photo}},
        socket
      ) do
    {:noreply, update_photo(socket, photo)}
  end

  @impl true
  def handle_info(
        %{event: "reject", payload: %{data: %Accounts.Photo{} = photo}},
        socket
      ) do
    {:noreply, update_photo(socket, photo)}
  end

  @impl true
  def handle_info(
        %{event: "update", payload: %{data: %Narratives.Story{} = story}},
        socket
      ) do
    {:noreply, update_story(socket, story)}
  end

  @impl true
  def handle_info(
        %{event: "destroy", payload: %{data: %Narratives.Story{} = story}},
        socket
      ) do
    {:noreply, delete_story_by_dom_id(socket, "stories_and_flags-" <> story.id)}
  end

  defp update_photo(socket, photo) do
    item =
      Enum.find(socket.assigns.stories_and_flags_items, fn item ->
        item.photo != nil && item.photo.id == photo.id
      end)

    item = Map.merge(item, %{photo: photo, story: %{item.story | photo: photo}})

    socket
    |> stream_insert(:stories_and_flags, item, at: -1)
  end

  defp update_story(socket, story) do
    item =
      Enum.find(socket.assigns.stories_and_flags_items, fn item ->
        item.story.id == story.id
      end)

    item = Map.merge(item, %{story: story})

    socket
    |> stream_insert(:stories_and_flags, item, at: -1)
  end

  defp delete_story_by_dom_id(socket, dom_id) do
    socket
    |> stream_delete_by_dom_id(:stories_and_flags, dom_id)
    |> stream(:stories_and_flags, fetch_stories_and_flags(socket.assigns.user.id, socket.assigns.language))
  end

  defp fetch_flags(user_id, color) do
    Traits.UserFlags
    |> Ash.Query.for_read(:by_user_id, %{id: user_id, color: color})
    |> Ash.Query.load([:flag])
    |> Traits.read!()
  end

  defp fetch_stories(user_id) do
    stories =
      Narratives.Story
      |> Ash.Query.for_read(:by_user_id, %{user_id: user_id})
      |> Narratives.read!(page: [limit: 50])
      |> then(& &1.results)

    stories
  end

  defp fetch_stories_and_flags(nil, _language) do
    []
  end

  defp fetch_stories_and_flags(user_id, language) do
    flags = fetch_flags(user_id, :white)

    stories = fetch_stories(user_id)

    flags =
      filter_flags(flags, :white, language)

    stories_and_flags = group_flags_with_stories(stories, flags)

    Enum.reduce(stories_and_flags, [], fn {story_flags, story}, acc ->
      acc ++ [%{id: story.id, story: story, photo: story.photo, flags: story_flags}]
    end)
  end

  def group_flags_with_stories(stories, flags) do
    flags_per_story =
      if length(stories) > 0 do
        div(length(flags), length(stories))
      else
        0
      end

    extra_flags = length(flags) - flags_per_story * length(stories)

    chunks = chunk(flags, flags_per_story, extra_flags)

    Enum.zip(chunks, stories)
    |> Enum.map(fn {flag_chunk, story} -> {flag_chunk, story} end)
  end

  defp chunk(flags, _count, 0) when length(flags) == 0, do: []

  defp chunk(flags, count, extra) do
    if extra > 0 do
      extra = extra - 1
      [Enum.take(flags, count + 1) | chunk(Enum.drop(flags, count + 1), count, extra)]
    else
      [Enum.take(flags, count) | chunk(Enum.drop(flags, count), count, extra)]
    end
  end

  defp get_amount_to_chunk(stories, flags) do
    length_of_stories = length(stories)
    length_of_flags = length(flags)

    if 5 * length_of_stories >= length_of_flags do
      5
    else
      5 + length_of_flags
    end
  end

  defp filter_flags(nil, _color, _language) do
    []
  end

  defp filter_flags(flags, color, language) do
    flags =
      flags
      |> Enum.filter(fn trait ->
        trait.color == color and trait.flag != nil
      end)

    Enum.map(flags, fn trait ->
      %{
        id: trait.flag.id,
        name: get_translation(trait.flag.flag_translations, language),
        emoji: trait.flag.emoji
      }
    end)
  end

  defp broadcast_user(socket) do
    current_user = Accounts.User.by_id!(socket.assigns.current_user.id)

    PubSub.broadcast(
      Animina.PubSub,
      "#{current_user.username}",
      {:user, current_user}
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.async_result :let={_stories} assign={@stories_and_flags}>
        <:loading>
          <div class="columns md:columns-2 lg:columns-3">
            <div class="break-inside-avoid mb-4"><.story_card_loading /></div>
            <div class="break-inside-avoid mb-4 px-4 py-4 dark:bg-gray-800 bg-gray-200  rounded-md">
              <.story_flags_loading />
            </div>
            <div class="break-inside-avoid mb-4"><.story_card_loading /></div>

            <div class="break-inside-avoid mb-4"><.story_card_loading /></div>

            <div class="break-inside-avoid mb-4"><.story_card_loading /></div>

            <div class="break-inside-avoid mb-4 px-4 py-4 dark:bg-gray-800 bg-gray-200  rounded-md">
              <.story_flags_loading />
            </div>

            <div class="break-inside-avoid mb-4 px-4 py-4 dark:bg-gray-800 bg-gray-200  rounded-md">
              <.story_flags_loading />
            </div>
            <div class="break-inside-avoid mb-4"><.story_card_loading /></div>
            <div class="break-inside-avoid mb-4"><.story_card_loading /></div>
          </div>
        </:loading>
        <:failed :let={_failure}><%= gettext("There was an error loading stories") %></:failed>

        <div class="columns md:columns-2 lg:columns-3 gap-8" id="stream_stories" phx-update="stream">
          <div
            :for={{dom_id, %{story: story, photo: photo, flags: flags}} <- @streams.stories_and_flags}
            class="break-inside-avoid pb-2"
            id={"#{dom_id}"}
          >
            <.live_component
              module={AniminaWeb.StoryComponent}
              id={"story_#{story.id}"}
              story={story}
              photo={photo}
              flags={flags}
              user={@user}
              dom_id={dom_id}
              current_user={@current_user}
              current_user_green_flags={@current_user_green_flags}
              current_user_red_flags={@current_user_red_flags}
            />
          </div>
        </div>
      </.async_result>
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
