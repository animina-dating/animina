defmodule AniminaWeb.ProfileStoriesLive do
  @moduledoc """
  User Stories Liveview
  """

  use AniminaWeb, :live_view
  alias Animina.Accounts
  alias Animina.Narratives
  alias Animina.Traits

  require Ash.Query

  @impl true
  def mount(
        _params,
        %{"user" => user, "current_user" => current_user, "language" => language},
        socket
      ) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Animina.PubSub, "story:created:#{user.id}")
      Phoenix.PubSub.subscribe(Animina.PubSub, "user_flag:created:#{user.id}")
    end

    current_user_green_flags =
      if current_user do
        fetch_flags(current_user.id, :green) |> filter_flags(:green)
      else
        []
      end

    current_user_red_flags =
      if current_user do
        fetch_flags(current_user.id, :red) |> filter_flags(:red)
      else
        []
      end

    flags = fetch_flags(user.id, :white) |> filter_flags(:white)

    {count, stories} = fetch_stories(user.id)

    socket =
      socket
      |> assign(count: count)
      |> assign(language: language)
      |> assign(flags: flags)
      |> assign(current_user: current_user)
      |> assign(user: user)
      |> assign(current_user_green_flags: current_user_green_flags)
      |> assign(current_user_red_flags: current_user_red_flags)
      |> stream(:stories, stories)

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_event("destroy_story", %{"id" => id, "dom_id" => dom_id}, socket) do
    {:ok, story} = Narratives.Story.by_id(id)

    case Narratives.Story.destroy(story) do
      :ok ->
        {:noreply,
         socket
         |> delete_story_by_dom_id(dom_id)}

      {:error, %Ash.Error.Invalid{} = changeset} ->
        case changeset.errors do
          [%Ash.Error.Changes.InvalidAttribute{message: message}]
          when message == "would leave records behind" ->
            Accounts.Photo.destroy(story.photo)
            Narratives.Story.destroy(story)

            {:noreply,
             socket
             |> delete_story_by_dom_id(dom_id)}

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
        %{event: "create", payload: %{data: %Narratives.Story{} = story}},
        socket
      ) do
    item = %{
      id: story.id,
      photo: story.photo,
      story: story
    }

    {:noreply,
     socket
     |> assign(:count, socket.assigns.count + 1)
     |> stream_insert(:stories, item, at: 0)}
  end

  @impl true
  def handle_info(
        %{event: "create", payload: %{data: %Traits.UserFlags{} = _user_flag}},
        socket
      ) do
    current_user_green_flags =
      if socket.assigns.current_user do
        fetch_flags(socket.assigns.current_user.id, :green) |> filter_flags(:green)
      else
        []
      end

    current_user_red_flags =
      if socket.assigns.current_user do
        fetch_flags(socket.assigns.urrent_user.id, :red) |> filter_flags(:red)
      else
        []
      end

    flags = fetch_flags(socket.assigns.user.id, :white) |> filter_flags(:white)

    {:noreply,
     socket
     |> assign(current_user_green_flags: current_user_green_flags)
     |> assign(current_user_red_flags: current_user_red_flags)
     |> assign(flags: flags)}
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
    {:noreply,
     socket
     |> delete_story_by_dom_id("stories-" <> story.id)}
  end

  defp update_photo(socket, photo) do
    {:ok, story} = Narratives.Story.by_id(photo.story_id)

    item = %{
      id: story.id,
      photo: photo,
      story: story
    }

    socket
    |> stream_insert(:stories, item, at: -1)
  end

  defp update_story(socket, story) do
    item = %{
      id: story.id,
      photo: story.photo,
      story: story
    }

    socket
    |> stream_insert(:stories, item, at: -1)
  end

  defp delete_story_by_dom_id(socket, dom_id) do
    socket
    |> stream_delete_by_dom_id(:stories, dom_id)
    |> assign(:count, socket.assigns.count - 1)
  end

  defp fetch_flags(user_id, _color) do
    Traits.UserFlags
    |> Ash.Query.for_read(:by_user_id, %{id: user_id})
    |> Ash.Query.load([:flag])
    |> Ash.read!()
  end

  defp fetch_stories(user_id) do
    {:ok, offset} =
      Narratives.FastStory
      |> Ash.ActionInput.for_action(:by_user_id, %{id: user_id, limit: 50})
      |> Ash.run_action()

    stories =
      offset.results
      |> Enum.map(fn story ->
        %{
          id: story.id,
          photo: story.photo,
          story: story
        }
      end)

    {offset.count, stories}
  end

  defp filter_flags(nil, _color) do
    []
  end

  defp filter_flags(flags, color) do
    flags =
      flags
      |> Enum.filter(fn trait ->
        trait.color == color and trait.flag != nil
      end)

    Enum.map(flags, fn trait ->
      %{
        id: trait.flag.id,
        name: trait.flag.name,
        emoji: trait.flag.emoji
      }
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-4 w-[100%]">
      <div class={"gap-8 columns  #{if @count > 0 do "md:columns-2 lg:columns-3 " else "columns-1" end } "}>
        <div id="stream_stories" phx-update="stream">
          <div
            :for={{dom_id, %{story: story, photo: photo}} <- @streams.stories}
            class="pb-2 break-inside-avoid"
            id={"#{dom_id}"}
          >
            <.live_component
              module={AniminaWeb.StoryComponent}
              id={"story_#{story.id}"}
              story={story}
              photo={photo}
              user={@user}
              dom_id={dom_id}
              language={@language}
              current_user={@current_user}
              current_user_green_flags={@current_user_green_flags}
              current_user_red_flags={@current_user_red_flags}
            />
          </div>
        </div>

        <div
          :if={
            @current_user && @current_user.id == @user.id &&
              @current_user.registration_completed_at == nil
          }
          class="pb-2"
        >
          <div class="p-4 rounded-md bg-blue-50">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg
                  class="w-5 h-5 text-blue-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z"
                    clip-rule="evenodd"
                  />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-blue-800">
                  <%= gettext("Tell us more about yourself!") %>
                </h3>
                <div class="mt-2 text-sm text-blue-700">
                  <p>
                    <%= with_locale(@language, fn -> %>
                      <%= gettext(
                        "To activate your profile you have to have at least an about me story and a profile picture uploaded. A story can contain just a photo, just a text or both combined. You can add, edit and delete stories anytime. With stories you present yourself to others. You have more success with at least three of them in your profile."
                      ) %>
                    <% end) %>
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="flex flex-wrap bg-gray-100 w-[100%] rounded-md justify-center p-2 space-x-2 space-y-2">
        <span />
        <%= for flag <- @flags do %>
          <span
            :if={flag != %{}}
            class="inline-flex items-center px-3 py-2 text-base font-medium text-gray-900 bg-white rounded-md ring-1 ring-inset ring-gray-200"
          >
            <%= flag.emoji %>

            <%= with_locale(@language, fn -> %>
              <%= Gettext.gettext(AniminaWeb.Gettext, Ash.CiString.value(flag.name)) %>
            <% end) %>

            <.get_styling_for_matching_flags
              flag={flag}
              current_user_green_flags={@current_user_green_flags}
              current_user_red_flags={@current_user_red_flags}
            />
          </span>
        <% end %>
      </div>
    </div>
    """
  end
end
