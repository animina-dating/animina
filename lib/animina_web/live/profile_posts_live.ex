defmodule AniminaWeb.ProfilePostsLive do
  @moduledoc """
  User Posts Liveview
  """

  use AniminaWeb, :live_view
  alias Animina.Accounts
  alias Animina.Narratives

  @impl true
  def mount(
        _params,
        %{"user_id" => user_id, "current_user" => current_user, "language" => language},
        socket
      ) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Animina.PubSub, "post:created:#{user_id}")
    end

    socket =
      socket
      |> assign(language: language)
      |> assign(current_user: current_user)
      |> assign(user: Accounts.BasicUser.by_id!(user_id))
      |> stream(:posts, fetch_posts(user_id, current_user))

    {:ok, socket, layout: false}
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
    |> Narratives.read!(actor: current_user)
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
      <div>
        <h1 class="text-2xl font-semibold dark:text-white">
          My Posts
        </h1>
      </div>
      <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-8" id="stream_posts" phx-update="stream">
        <div :for={{dom_id, post} <- @streams.posts} class="break-inside-avoid pb-2" id={"#{dom_id}"}>
          <.post_card
            post={post}
            dom_id={dom_id}
            current_user={@current_user}
            user={@user}
            delete_post_modal_text={gettext("Are you sure?")}
            read_post_title={gettext("Read Post")}
          />
        </div>
      </div>
    </div>
    """
  end
end
