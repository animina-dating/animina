defmodule AniminaWeb.ProfilePostsLive do
  @moduledoc """
  User Posts Liveview
  """

  use AniminaWeb, :live_view
  alias Animina.Narratives

  @impl true
  def mount(
        _params,
        %{"user" => user, "current_user" => current_user, "language" => language},
        socket
      ) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Animina.PubSub, "post:created:#{user.id}")
      Phoenix.PubSub.subscribe(Animina.PubSub, "story:created:#{user.id}")
    end

    socket =
      socket
      |> assign(language: language)
      |> assign(current_user: current_user)
      |> assign(user: user)
      |> assign(stories: fetch_stories(user.id))
      |> stream(:posts, fetch_posts(user.id, current_user))

    {:ok, socket, layout: false}
  end

  defp fetch_stories(user_id) do
    stories =
      Narratives.Story
      |> Ash.Query.for_read(:by_user_id, %{user_id: user_id})
      |> Ash.read!(page: [limit: 50])
      |> then(& &1.results)

    stories
  end

  @impl true
  def handle_event("destroy_post", %{"id" => id, "dom_id" => dom_id}, socket) do
    {:ok, post} = Narratives.Post.by_id(id)

    case Narratives.Post.destroy(post, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> delete_post_by_dom_id(dom_id)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("An error occurred while deleting the post"))}
    end
  end

  @impl true
  def handle_info(
        %{event: "create", payload: %{data: %Narratives.Post{} = post}},
        socket
      ) do
    {:noreply, insert_new_post(socket, post)}
  end

  @impl true
  def handle_info(
        %{event: "create", payload: %{data: %Narratives.Story{} = _story}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:stories, fetch_stories(socket.assigns.user.id))}
  end

  @impl true
  def handle_info(
        %{event: "destroy", payload: %{data: %Narratives.Story{} = _story}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:stories, fetch_stories(socket.assigns.user.id))}
  end

  @impl true
  def handle_info(
        %{event: "update", payload: %{data: %Narratives.Post{} = post}},
        socket
      ) do
    {:noreply, update_post(socket, post)}
  end

  @impl true
  def handle_info(
        %{event: "destroy", payload: %{data: %Narratives.Post{} = post}},
        socket
      ) do
    {:noreply, delete_post_by_dom_id(socket, "posts-" <> post.id)}
  end

  defp fetch_posts(user_id, current_user) do
    Narratives.Post
    |> Ash.Query.for_read(:by_user_id, %{user_id: user_id})
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read!(actor: current_user)
    |> Enum.map(fn post ->
      Phoenix.PubSub.subscribe(Animina.PubSub, "post:updated:#{post.id}")
      post
    end)
    |> Enum.take(3)
  end

  defp update_post(socket, post) do
    socket
    |> stream_insert(:posts, post, at: -1)
  end

  defp insert_new_post(socket, post) do
    socket
    |> stream_insert(:posts, post, at: 0)
  end

  defp delete_post_by_dom_id(socket, dom_id) do
    socket
    |> stream_delete_by_dom_id(:posts, dom_id)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-8 space-y-8">
      <div class="flex  justify-end w-[100%]">
        <div :if={@current_user && @current_user.id == @user.id && Enum.count(@stories) >= 3}>
          <.link
            navigate="/my/posts/new"
            class="flex justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          >
            <%= gettext("Add a new post") %>
          </.link>
        </div>
      </div>
      <%= if @streams.posts.inserts != [] do %>
        <div>
          <h1 class="text-2xl font-semibold dark:text-white">
            <%= gettext("My Posts") %>
          </h1>
        </div>

        <div
          class="grid grid-cols-1 px-6 mx-auto gap-x-8 gap-y-12 sm:gap-y-16 lg:grid-cols-2 lg:px-8"
          id="stream_posts"
          phx-update="stream"
        >
          <div :for={{dom_id, post} <- @streams.posts} class="" id={"#{dom_id}"}>
            <.post_card
              post={post}
              dom_id={dom_id}
              current_user={@current_user}
              user={@user}
              delete_post_modal_text={gettext("Do you really want to delete this post?")}
              read_post_title={gettext("Read Post")}
            />
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
