defmodule AniminaWeb.PostsComponents do
  @moduledoc """
  Provides Post UI components.
  """
  use Phoenix.Component
  alias Animina.Markdown

  use Timex

  attr :post, :any, required: true
  attr :current_user, :any, required: true
  attr :user, :any, required: false
  attr :dom_id, :any, required: false
  attr :delete_post_modal_text, :string
  attr :read_post_title, :string
  attr :subtitle, :string

  def post_card(assigns) do
    ~H"""
    <div class="h-full flex flex-col justify-between">
      <div class="space-y-4">
        <h1 class="text-lg dark:text-white font-semibold"><%= @post.title %></h1>

        <p class="dark:text-white">
          <span class="font-medium"><%= @subtitle %></span>
        </p>
      </div>

      <div class="flex items-center justify-between mt-4">
        <.link
          navigate={@post.url}
          class="flex justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
        >
          <%= @read_post_title %>
        </.link>

        <.post_action_icons
          post={@post}
          current_user={@current_user}
          user={@user}
          dom_id={@dom_id}
          delete_post_modal_text={@delete_post_modal_text}
        />
      </div>
    </div>
    """
  end

  attr :post, :any, required: true
  attr :current_user, :any, required: true
  attr :user, :any, required: false
  attr :dom_id, :any, required: false
  attr :delete_post_modal_text, :string

  def post_action_icons(assigns) do
    ~H"""
    <div
      :if={@current_user && @user.id == @current_user.id}
      class="flex justify-end gap-4 pb-1 text-justify text-gray-600 cursor-pointer dark:text-gray-100"
    >
      <.link navigate={"/my/posts/#{@post.id}/edit" }>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="25"
          height="24"
          viewBox="0 0 20 20"
          fill="currentColor"
          aria-hidden="true"
        >
          <path d="M2.695 14.763l-1.262 3.154a.5.5 0 00.65.65l3.155-1.262a4 4 0 001.343-.885L17.5 5.5a2.121 2.121 0 00-3-3L3.58 13.42a4 4 0 00-.885 1.343z" />
        </svg>
      </.link>

      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 20 20"
        width="25"
        height="24"
        fill="currentColor"
        aria-hidden="true"
        phx-click="destroy_post"
        phx-value-id={@post.id}
        phx-value-dom_id={@dom_id}
        data-confirm={@delete_post_modal_text}
      >
        <path
          fill-rule="evenodd"
          d="M8.75 1A2.75 2.75 0 006 3.75v.443c-.795.077-1.584.176-2.365.298a.75.75 0 10.23 1.482l.149-.022.841 10.518A2.75 2.75 0 007.596 19h4.807a2.75 2.75 0 002.742-2.53l.841-10.52.149.023a.75.75 0 00.23-1.482A41.03 41.03 0 0014 4.193V3.75A2.75 2.75 0 0011.25 1h-2.5zM10 4c.84 0 1.673.025 2.5.075V3.75c0-.69-.56-1.25-1.25-1.25h-2.5c-.69 0-1.25.56-1.25 1.25v.325C8.327 4.025 9.16 4 10 4zM8.58 7.72a.75.75 0 00-1.5.06l.3 7.5a.75.75 0 101.5-.06l-.3-7.5zm4.34.06a.75.75 0 10-1.5-.06l-.3 7.5a.75.75 0 101.5.06l.3-7.5z"
          clip-rule="evenodd"
        />
      </svg>
    </div>
    """
  end

  attr :content, :string, required: true

  def post_body(assigns) do
    ~H"""
    <div class="pb-2 text-justify text-gray-600 text-ellipsis dark:text-gray-100">
      <%= Markdown.format(@content) %>
    </div>
    """
  end

  attr :post, :any, required: true
  attr :current_user, :any, required: true
  attr :edit_post_title, :string
  attr :subtitle, :string

  def post_header(assigns) do
    ~H"""
    <div class="pb-4 flex justify-between items-center">
      <div class="w-4/5">
        <h1 class="text-2xl md:text-3xl lg:text-4xl font-semibold dark:text-white">
          <%= @post.title %>
        </h1>

        <div class="flex mt-4">
          <p class="dark:text-white">
            <span class="font-medium"><%= @subtitle %></span>
          </p>
        </div>
      </div>

      <div :if={@current_user && @current_user.id == @post.user.id}>
        <.link
          navigate={"/my/posts/#{@post.id}/edit" }
          class="flex justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
        >
          <%= @edit_post_title %>
        </.link>
      </div>
    </div>
    """
  end
end
