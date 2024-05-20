defmodule AniminaWeb.BookmarksComponents do
  @moduledoc """
  Provides Bookmark UI components.
  """
  use Phoenix.Component
  import AniminaWeb.Gettext

  attr :bookmark, :any, required: true
  attr :dom_id, :any, required: false
  attr :reason, :any, required: true
  attr :delete_bookmark_modal_text, :string, required: true

  def bookmark(assigns) do
    ~H"""
    <div class="pb-2 px-4">
      <div class="flex items-center justify-between space-x-4 mt-4">
        <div>
          <img
            :if={@bookmark.user.profile_photo && @bookmark.user.profile_photo.state == :approved}
            class="object-cover rounded-lg aspect-square h-16 w-16"
            src={AniminaWeb.Endpoint.url() <> "/uploads/" <> @bookmark.user.profile_photo.filename}
          />

          <div
            :if={@bookmark.user.profile_photo && @bookmark.user.profile_photo.state != :approved}
            class="bg-gray-200 dark:bg-gray-800 h-16 w-16 rounded-lg  flex items-center justify-center"
          >
          </div>
        </div>

        <div class="space-y-2 flex-1">
          <h1 class="text-lg font-medium dark:text-white">
            <%= @bookmark.user.name %>
          </h1>

          <div>
            <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
              <%= @bookmark.user.age %> <%= gettext("years") %>
            </span>

            <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
              <%= @bookmark.user.height %> <%= gettext("cm") %>
            </span>

            <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
              📍 <%= @bookmark.user.city.name %>
            </span>

            <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
              <%= @bookmark.user.credit_points %>
            </span>
          </div>
        </div>
      </div>

      <div class="mt-4">
        <.bookmark_action_icons
          bookmark={@bookmark}
          reason={@reason}
          dom_id={@dom_id}
          delete_bookmark_modal_text={@delete_bookmark_modal_text}
        />
      </div>
    </div>
    """
  end

  attr :bookmark, :any, required: true
  attr :dom_id, :string, required: true
  attr :delete_bookmark_modal_text, :string, required: true
  attr :reason, :any, required: true

  def bookmark_action_icons(assigns) do
    ~H"""
    <div class="flex justify-end gap-4 pb-4 text-justify text-gray-600 cursor-pointer dark:text-gray-100">
      <.link navigate={"/#{@bookmark.user.username}" }>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class="w-6 h-6"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M13.5 6H5.25A2.25 2.25 0 0 0 3 8.25v10.5A2.25 2.25 0 0 0 5.25 21h10.5A2.25 2.25 0 0 0 18 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"
          />
        </svg>
      </.link>

      <svg
        :if={@reason == :liked}
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 20 20"
        width="25"
        height="24"
        fill="currentColor"
        aria-hidden="true"
        phx-click="destroy_bookmark"
        phx-value-id={@bookmark.id}
        phx-value-dom_id={@dom_id}
        data-confirm={@delete_bookmark_modal_text}
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
end
