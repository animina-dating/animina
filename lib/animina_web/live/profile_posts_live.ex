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
    |> Enum.map(fn post ->
      Phoenix.PubSub.subscribe(Animina.PubSub, "post:updated:#{post.id}")
      post
    end)
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
      <div class="grid grid-cols-2">
        <div>
          <h1 class="text-2xl font-semibold dark:text-white">
            <%= gettext("My Posts") %>
          </h1>
        </div>
        <div>
          <.link
            navigate="/my/posts/new"
            class="flex justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          >
            <%= gettext("Add a new post") %>
          </.link>
        </div>
      </div>

      <div class="grid grid-cols-1 mx-auto max-w-7xl gap-x-8 gap-y-12 sm:gap-y-16 lg:grid-cols-2 ">
        <article class="w-full max-w-2xl mx-auto lg:mx-0 lg:max-w-lg">
          <time datetime="2020-03-16" class="block text-sm leading-6 text-gray-600">
            23.12.2023
          </time>
          <h2
            id="featured-post"
            class="mt-4 text-2xl font-bold tracking-tight text-gray-900 sm:text-3xl"
          >
            <a href="#">
              We’re incredibly proud to announce we have secured $75m in Series B
            </a>
          </h2>
          <p class="mt-4 text-lg leading-8 text-gray-600">
            <a href="#">
              Libero neque aenean tincidunt nec consequat tempor. Viverra odio id velit adipiscing id. Nisi vestibulum orci eget bibendum dictum. Velit viverra posuere vulputate volutpat nunc. Nunc netus sit faucibus. [...]
            </a>
          </p>
          <div class="flex flex-col justify-between gap-6 mt-4 sm:mt-8 sm:flex-row-reverse sm:gap-8 lg:mt-4 lg:flex-col">
            <div class="flex">
              <a
                href="#"
                class="text-sm font-semibold leading-6 text-indigo-600"
                aria-describedby="featured-post"
              >
                Continue reading <span aria-hidden="true">&rarr;</span>
              </a>
            </div>
          </div>
        </article>
        <div class="w-full max-w-2xl pt-12 mx-auto border-t border-gray-900/10 sm:pt-16 lg:mx-0 lg:max-w-none lg:border-t-0 lg:pt-0">
          <div class="-my-12 divide-y divide-gray-900/10">
            <article class="py-12">
              <div class="relative max-w-xl group">
                <time datetime="2020-03-16" class="block text-sm leading-6 text-gray-600">
                  23.12.2023
                </time>
                <h2 class="mt-2 text-lg font-semibold text-gray-900 group-hover:text-gray-600">
                  <a href="#">
                    <span class="absolute inset-0"></span> Boost your conversion rate
                  </a>
                </h2>
                <p class="mt-4 text-sm leading-6 text-gray-600">
                  Illo sint voluptas. Error voluptates culpa eligendi. Hic vel totam vitae illo. Non aliquid explicabo necessitatibus unde. Sed exercitationem placeat consectetur nulla deserunt vel iusto corrupti dicta laboris incididunt. [...]
                </p>
              </div>
              <div class="flex flex-col justify-between gap-6 mt-4 sm:mt-8 sm:flex-row-reverse sm:gap-8 lg:mt-4 lg:flex-col">
                <div class="flex">
                  <a
                    href="#"
                    class="text-sm font-semibold leading-6 text-indigo-600"
                    aria-describedby="featured-post"
                  >
                    Continue reading <span aria-hidden="true">&rarr;</span>
                  </a>
                </div>
              </div>
            </article>
            <article class="py-12">
              <div class="relative max-w-xl group">
                <time datetime="2020-03-16" class="block text-sm leading-6 text-gray-600">
                  23.12.2023
                </time>
                <h2 class="mt-2 text-lg font-semibold text-gray-900 group-hover:text-gray-600">
                  <a href="#">
                    <span class="absolute inset-0"></span> Boost your conversion rate
                  </a>
                </h2>
                <p class="mt-4 text-sm leading-6 text-gray-600">
                  Illo sint voluptas. Error voluptates culpa eligendi. Hic vel totam vitae illo. Non aliquid explicabo necessitatibus unde. Sed exercitationem placeat consectetur nulla deserunt vel iusto corrupti dicta laboris incididunt. [...]
                </p>
              </div>
              <div class="flex flex-col justify-between gap-6 mt-4 sm:mt-8 sm:flex-row-reverse sm:gap-8 lg:mt-4 lg:flex-col">
                <div class="flex">
                  <a
                    href="#"
                    class="text-sm font-semibold leading-6 text-indigo-600"
                    aria-describedby="featured-post"
                  >
                    Continue reading <span aria-hidden="true">&rarr;</span>
                  </a>
                </div>
              </div>
            </article>
          </div>
        </div>
      </div>

      <div
        class="grid gap-8 md:grid-cols-2 auto-rows-fr lg:grid-cols-3"
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
    </div>
    """
  end
end
