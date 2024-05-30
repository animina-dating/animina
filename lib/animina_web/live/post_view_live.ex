defmodule AniminaWeb.PostViewLive do
  use AniminaWeb, :live_view

  alias Animina.Narratives.Post

  @impl true
  def mount(%{"slug" => slug}, %{"language" => language} = _session, socket) do
    post = Post.by_slug!(slug, not_found_error?: false)

    socket =
      socket
      |> assign(language: language)
      |> assign(post: post)
      |> assign(active_tab: :home)
      |> assign(error: nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      case socket.assigns.post do
        nil ->
          socket
          |> assign(page_title: gettext("Post not found"))

        _ ->
          socket
          |> assign(page_title: "#{socket.assigns.post.user.name} | #{socket.assigns.post.title}")
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div :if={@post == nil} class="px-12 pb-8">
        <h1 class="text-2xl font-semibold dark:text-white">
          <%= gettext("Something went wrong. We couldn't find this post") %>
        </h1>
      </div>

      <div :if={@post != nil} class="px-12 pb-8 space-y-4">
        <.post_header
          post={@post}
          current_user={@current_user}
          edit_post_title={gettext("Edit post")}
        />

        <.post_body content={@post.content} />
      </div>
    </div>
    """
  end
end
