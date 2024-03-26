defmodule AniminaWeb.ProfileLive do
  @moduledoc """
  User Profile Liveview
  """
  alias AniminaWeb.StoryComponent
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
          |> assign(stories: AsyncResult.loading())
          |> assign(flags: AsyncResult.loading())
          |> start_async(:fetch_flags, fn -> fetch_flags(user.id, :white, language) end)
          |> start_async(:fetch_stories, fn -> fetch_stories(user.id) end)

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4 px-5 pb-8">
      <div :if={@user != nil}>
        <div class="rounded-lg border border-gray-100 shadow-sm flex items-center space-x-4 px-4">
          <div class="w-24 h-24 flex flex-col items-center justify-center">
            <img
              :if={@user.profile_photo != nil}
              class="object-fit"
              src={AniminaWeb.Endpoint.url() <> "/uploads/" <> @user.profile_photo.filename}
            />
          </div>

          <div class="py-4">
            <h3 class="text-lg font-semibold"><%= @user.name %></h3>
            <p class="text-sm font-medium text-gray-500"><%= @user.username %></p>

            <div class="mt-2">
              <p class="text-gray-600">
                <%= gettext("Lives in ") %> <%= @user.city.name %>
              </p>

              <p class="text-gray-600">
                <%= gettext("I'm a ") %> <%= @user.occupation %>
              </p>
            </div>
          </div>
        </div>

        <div class="mt-8 space-y-4">
          <h2 class="font-bold text-xl">My Stories</h2>
          <.async_result :let={_stories} assign={@stories}>
            <:loading><%= gettext("Loading stories...") %></:loading>
            <:failed :let={_failure}><%= gettext("There was an error loading stories") %></:failed>

            <div class="space-y-4" id="stream_stories" phx-update="stream">
              <div :for={{dom_id, story} <- @streams.stories} id={"#{dom_id}"}>
                <.live_component
                  module={StoryComponent}
                  id={"story_#{story.id}"}
                  story={story}
                  language={@language}
                  for_current_user={@current_user.id == @user.id}
                />
              </div>
            </div>
          </.async_result>
        </div>

        <div class="mt-8 space-y-4">
          <h2 class="font-bold text-xl">My White Flags</h2>

          <.async_result :let={_flags} assign={@flags}>
            <:loading><%= gettext("Loading flags...") %></:loading>
            <:failed :let={_failure}><%= gettext("There was an error loading flags") %></:failed>

            <div class="space-y-4" id="stream_flags" phx-update="stream">
              <div :for={{dom_id, category} <- @streams.flags} class="space-y-2" id={"#{dom_id}"}>
                <h3 class="font-semibold text-gray-800 truncate">
                  <%= category.name %>
                </h3>

                <ol class="flex flex-wrap gap-2 w-full">
                  <li :for={user_flag <- category.flags}>
                    <div class="cursor-pointer text-white shadow-sm rounded-full px-3 py-1.5 text-sm font-semibold leading-6  focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 hover:bg-indigo-500  bg-indigo-600 focus-visible:outline-indigo-600 ">
                      <span :if={user_flag.flag.emoji} class="pr-1.5">
                        <%= user_flag.flag.emoji %>
                      </span>

                      <%= user_flag.flag.name %>
                    </div>
                  </li>
                </ol>
              </div>
            </div>
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
