defmodule AniminaWeb.TopNavigationCompontents do
  @moduledoc """
  Provides animina UI components.
  """
  use Phoenix.Component

  import AniminaWeb.Gettext

  # -------------------------------------------------------------
  @doc """
  Top navigation bar.

  ## Examples

      <.top_navigation current_user={@current_user} />
  """
  attr :current_user, :any, default: nil, doc: "current user"
  attr :active_tab, :atom, default: nil, doc: "active tab"

  def top_navigation(assigns) do
    ~H"""
    <div class="border-y md:border-r md:border-l border-brand-silver-100">
      <nav class="grid grid-cols-4 gap-1">
        <.home_nav_item active_tab={@active_tab} />
        <.bookmarks_nav_item active_tab={@active_tab} />
        <.chat_nav_item current_user={@current_user} active_tab={@active_tab} />
        <.user_profile_item current_user={@current_user} active_tab={@active_tab} />
      </nav>
    </div>
    """
  end

  # -------------------------------------------------------------
  @doc """
  Top navigation bar entry.

  ## Examples

      <.top_navigation_entry>
        test
      </.top_navigation_entry>
  """
  attr :is_active, :boolean, default: false, doc: "active state of the item"
  attr :current_user, :any, default: nil, doc: "current user"
  slot :inner_block

  def top_navigation_entry(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "relative text-xs font-medium flex flex-col items-center justify-center gap-1.5 py-3 shadow-none drop-shadow-none",
        if(@is_active, do: "bg-blue-100 text-blue-600 cursor-auto", else: ""),
        unless(@current_user && @is_active, do: "text-gray-400")
      ]}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  # -------------------------------------------------------------
  @doc """
  User profile menu entry.

  ## Examples

      <.user_profile_item />
  """
  attr :active_tab, :atom, default: nil, doc: "active tab"
  attr :current_user, :any, default: nil, doc: "current user"

  def user_profile_item(assigns) do
    ~H"""
    <.top_navigation_entry phx-no-format is_active={@active_tab == :profile}>
      <%= if @current_user do %>
        <img alt="Avatar" class="w-6 h-6 rounded-full object-cover" src={"https://www.gravatar.com/avatar/#{@current_user.gravatar_hash}"} />
      <% else %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="stroke-current w-6 h-6 shrink-0"
          width="25" height="24" viewBox="0 0 25 24"
          fill="none"
        >
          <path
            d="M20.125 21V19C20.125 17.9391 19.7036 16.9217 18.9534 16.1716C18.2033 15.4214 17.1859 15 16.125 15H8.125C7.06413 15 6.04672 15.4214 5.29657 16.1716C4.54643 16.9217 4.125 17.9391 4.125 19V21M16.125 7C16.125 9.20914 14.3341 11 12.125 11C9.91586 11 8.125 9.20914 8.125 7C8.125 4.79086 9.91586 3 12.125 3C14.3341 3 16.125 4.79086 16.125 7Z"
            stroke="stroke-current" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round"
          />
        </svg>
      <% end %>
        <span class="flex items-center gap-0.5" aria-hidden="true">
        <%= if @current_user do %>
          <%= gettext("Points") %>: <%= humanized_points(@current_user.credit_points) %>
        <% else %>
          <%= gettext("Points") %>: 0
        <% end %>
        </span>
      </.top_navigation_entry>
    """
  end

  # -------------------------------------------------------------
  @spec home_nav_item(map()) :: Phoenix.LiveView.Rendered.t()
  @doc """
  Home menu entry.

  ## Examples

      <.home_nav_item />
  """
  attr :active_tab, :atom, default: nil, doc: "active tab"

  def home_nav_item(assigns) do
    ~H"""
    <.top_navigation_entry phx-no-format is_active={@active_tab == :home}>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="fill-current w-6 h-6 shrink-0"
        width="25" height="24" viewBox="0 0 25 24"
        fill="none"
      >
        <path
          fill-rule="evenodd" clip-rule="evenodd"
          d="M12.2611 1.21065C12.6222 0.929784 13.1278 0.929784 13.4889 1.21065L22.4889 8.21065C22.7325 8.4001 22.875 8.69141 22.875 9V20C22.875 20.7957 22.5589 21.5587 21.9963 22.1213C21.4337 22.6839 20.6707 23 19.875 23H5.875C5.07935 23 4.31629 22.6839 3.75368 22.1213C3.19107 21.5587 2.875 20.7957 2.875 20V9C2.875 8.69141 3.01747 8.4001 3.26106 8.21065L12.2611 1.21065ZM4.875 9.48908V20C4.875 20.2652 4.98036 20.5196 5.16789 20.7071C5.35543 20.8946 5.60978 21 5.875 21H19.875C20.1402 21 20.3946 20.8946 20.5821 20.7071C20.7696 20.5196 20.875 20.2652 20.875 20V9.48908L12.875 3.26686L4.875 9.48908Z"
          fill="fill-current"
        />
        <path
          fill-rule="evenodd" clip-rule="evenodd"
          d="M8.875 12C8.875 11.4477 9.32272 11 9.875 11H15.875C16.4273 11 16.875 11.4477 16.875 12V22C16.875 22.5523 16.4273 23 15.875 23C15.3227 23 14.875 22.5523 14.875 22V13H10.875V22C10.875 22.5523 10.4273 23 9.875 23C9.32272 23 8.875 22.5523 8.875 22V12Z"
          fill="fill-current"
        />
      </svg>
      <span>Home</span>
    </.top_navigation_entry>
    """
  end

  # -------------------------------------------------------------
  @doc """
  Chat menu entry.

  ## Examples

      <.chat_nav_item />
  """
  attr :active_tab, :atom, default: nil, doc: "active tab"
  attr :current_user, :any, default: nil, doc: "current user"

  def chat_nav_item(assigns) do
    ~H"""
    <.top_navigation_entry phx-no-format is_active={@active_tab == :chat}>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="stroke-current w-6 h-6 shrink-0"
        width="25" height="24" viewBox="0 0 25 24"
        fill="none"
      >
        <path
          d="M21.375 15C21.375 15.5304 21.1643 16.0391 20.7892 16.4142C20.4141 16.7893 19.9054 17 19.375 17H7.375L3.375 21V5C3.375 4.46957 3.58571 3.96086 3.96079 3.58579C4.33586 3.21071 4.84457 3 5.375 3H19.375C19.9054 3 20.4141 3.21071 20.7892 3.58579C21.1643 3.96086 21.375 4.46957 21.375 5V15Z"
          stroke="stroke-current" stroke-width="2"
          stroke-linecap="round" stroke-linejoin="round"
        />
      </svg>
      <span>Chat</span>
      <div class="flex -space-x-1.5 absolute top-2 left-1/2">
        <div
          class="w-4 h-4 shrink-0 rounded-full overflow-hidden"
          aria-hidden="true"
        >
          <img
            class="w-full h-full object-cover"
            alt=" "
            src="https://www.wintermeyer.de/assets/images/avatar.jpg"
          />
        </div>
        <div class="rounded-full bg-blue-600 w-4 h-4 text-[9px] text-white flex items-center justify-center font-medium">
          +1
        </div>
      </div>
    </.top_navigation_entry>
    """
  end

  # -------------------------------------------------------------

  @doc """
  Chat menu entry.

  ## Examples

      <.chat_nav_item />
  """
  attr :active_tab, :atom, default: nil, doc: "active tab"
  attr :current_user, :any, default: nil, doc: "current user"

  def bookmarks_nav_item(assigns) do
    ~H"""
    <.top_navigation_entry phx-no-format is_active={if @active_tab == :chat, do: true, else: false}>
    <svg xmlns="http://www.w3.org/2000/svg" width="25" height="24" viewBox="0 0 384 512" style="fill: currentColor;">
    <!--!Font Awesome Free 6.5.1 by @fontawesome - https://fontawesome.com
        License - https://fontawesome.com/license/free Copyright 2024
        Fonticons, Inc.-->
    <path d="M0 48C0 21.5 21.5 0 48 0l0 48V441.4l130.1-92.9c8.3-6 19.6-6 27.9 0L336 441.4V48H48V0H336c26.5 0 48 21.5 48 48V488c0 9-5 17.2-13 21.3s-17.6 3.4-24.9-1.8L192 397.5 37.9 507.5c-7.3 5.2-16.9 5.9-24.9 1.8S0 497 0 488V48z" />
    </svg>
    <span>Bookmarks</span>
    </.top_navigation_entry>
    """
  end

  defp humanized_points(nil) do
    "0"
  end

  defp humanized_points(points) when is_integer(points) and points < 1_000 do
    Integer.to_string(points)
  end

  defp humanized_points(points) when is_integer(points) and points < 1_000_000 do
    Integer.to_string(div(points, 1_000)) <> "\u{00a0}k"
  end

  defp humanized_points(points) when is_integer(points) do
    Integer.to_string(div(points, 1_000_000)) <> "\u{00a0}M"
  end
end
