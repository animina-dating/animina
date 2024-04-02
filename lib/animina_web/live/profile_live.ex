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
    average_potential_partner_height =
      socket.assigns.current_user.minimum_partner_height +
        socket.assigns.current_user.maximum_partner_height / 2

    socket =
      Accounts.User.by_username(username)
      |> case do
        {:ok, user} ->
          socket
          |> assign(language: language)
          |> assign(active_tab: :home)
          |> assign(user: user)
          |> assign(average_potential_partner_height: average_potential_partner_height)
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
    <div class="px-5 pb-8 space-y-4">
      <div :if={@user == nil}>
        <%= gettext("There was an error loading the user's profile") %>
      </div>

      <div :if={@user != nil}>
        <div class="flex items-center px-4 space-x-4 border border-gray-100 rounded-lg shadow-sm">
          <div class="py-4">
            <h3 class="text-lg dark:text-white font-semibold"><%= @user.name %></h3>
            <p class="text-sm dark:text-gray-100 font-medium text-gray-500"><%= @user.username %></p>

            <div class="mt-2">
              <p class="dark:text-gray-100  text-gray-600">
                <%= gettext("Lives in ") %> <%= @user.city.zip_code %> <%= @user.city.name %>.
              </p>
              <p class=" dark:text-gray-100  text-gray-600">
                <%= gettext("Lives in ") %> <%= @user.city.name %>
              </p>

              <p class=" dark:text-gray-100  text-gray-600">
                <%= gettext("I'm a ") %> <%= @user.occupation %>
              </p>
            </div>
          </div>
        </div>

        <div class="flex gap-2 p-4   py-8 justify-end items-end">
          <svg width="180px"
            height="180px" fill="#000000" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <g id="SVGRepo_bgCarrier" stroke-width="0"></g>
            <g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g>
            <g id="SVGRepo_iconCarrier">
              <path d="M9.5,7H15a1,1,0,0,1,.949.684l2,6a1,1,0,0,1-1.9.632L14.5,9.662V22a1,1,0,0,1-2,0V16h-1v6a1,1,0,0,1-2,0V9.662L7.949,14.316a1,1,0,0,1-1.9-.632l2-6A1,1,0,0,1,9,7Zm0-3.5A2.5,2.5,0,1,0,12,1,2.5,2.5,0,0,0,9.5,3.5Z">
              </path>
            </g>
          </svg>
          <svg
            fill="#000000"
            width="142px"
            height="142px"
            viewBox="0 0 512 512"
            xmlns="http://www.w3.org/2000/svg"
          >
            <g id="SVGRepo_bgCarrier" stroke-width="0"></g>
            <g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g>
            <g id="SVGRepo_iconCarrier">
              <title>ionicons-v5-r</title>
              <circle cx="255.75" cy="56" r="56"></circle>
              <path d="M394.63,277.9,384.3,243.49s0-.07,0-.11l-22.46-74.86h-.05l-2.51-8.45a44.87,44.87,0,0,0-43-32.08h-120a44.84,44.84,0,0,0-43,32.08l-2.51,8.45h-.06l-22.46,74.86s0,.07,0,.11L117.88,277.9c-3.12,10.39,2.3,21.66,12.57,25.14a20,20,0,0,0,25.6-13.18l25.58-85.25h0l2.17-7.23A8,8,0,0,1,199.33,200a7.78,7.78,0,0,1-.17,1.61v0L155.43,347.4A16,16,0,0,0,170.75,368h29V482.69c0,16.46,10.53,29.31,24,29.31s24-12.85,24-29.31V368h16V482.69c0,16.46,10.53,29.31,24,29.31s24-12.85,24-29.31V368h30a16,16,0,0,0,15.33-20.6L313.34,201.59a7.52,7.52,0,0,1-.16-1.59,8,8,0,0,1,15.54-2.63l2.17,7.23h0l25.57,85.25A20,20,0,0,0,382.05,303C392.32,299.56,397.74,288.29,394.63,277.9Z">
              </path>
            </g>
          </svg>
        </div>

        <div class="mt-8 space-y-4">
          <h2 class="font-bold dark:text-white text-xl">My Stories</h2>
          <.async_result :let={_stories} assign={@stories}>
            <:loading>
              <div class="space-y-4">
                <.story_card_loading />
                <.story_card_loading />
                <.story_card_loading />
              </div>
            </:loading>
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
          <h2 class="font-bold dark:text-white text-xl">My White Flags</h2>

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

            <div class="space-y-4" id="stream_flags" phx-update="stream">
              <div :for={{dom_id, category} <- @streams.flags} class="space-y-2" id={"#{dom_id}"}>
                <h3 class="font-semibold dark:text-white text-gray-800 truncate">
                  <%= category.name %>
                </h3>

                <ol class="flex flex-wrap w-full gap-2">
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
