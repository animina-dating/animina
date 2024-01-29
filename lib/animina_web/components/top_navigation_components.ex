defmodule AniminaWeb.TopNavigationCompontents do
  @moduledoc """
  Provides animina UI components.
  """
  use Phoenix.Component

  @doc """
  Top navigation bar.

  ## Examples

      <.top_navigation points={10_000} />
  """
  attr :points, :integer, default: 0, doc: "number of points the user has"

  def top_navigation(assigns) do
    ~H"""
    <div class="border-y border-brand-silver-100">
      <nav class="grid grid-cols-3 gap-1">
        <.home_nav_item is_active={true} />
        <.chat_nav_item />
        <.user_profile_item points={@points} />
      </nav>
    </div>
    """
  end

  @doc """
  Top navigation bar entry.

  ## Examples

      <.top_navigation_entry>
        test
      </.top_navigation_entry>
  """
  attr :is_active, :boolean, default: false, doc: "active state of the item"
  slot :inner_block

  def top_navigation_entry(assigns) do
    ~H"""
    <button
      type="button"
      <div
      class={[
        "relative text-xs font-medium flex flex-col items-center justify-center gap-1.5 py-3",
        if(@is_active, do: "bg-blue-100 text-blue-600 cursor-auto", else: "")
      ]}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  User profile menu entry.

  ## Examples

      <.user_profile_item />
  """
  attr :is_active, :boolean, default: false, doc: "active state of the navigation item"
  attr :points, :integer, default: 0, doc: "number of points the user has"

  def user_profile_item(assigns) do
    ~H"""
    <.top_navigation_entry>
      <svg
        class="stroke-current w-6 h-6 shrink-0"
        xmlns="http://www.w3.org/2000/svg"
        width="25"
        height="24"
        viewBox="0 0 25 24"
        fill="none"
      >
        <path
          d="M20.125 21V19C20.125 17.9391 19.7036 16.9217 18.9534 16.1716C18.2033 15.4214 17.1859 15 16.125 15H8.125C7.06413 15 6.04672 15.4214 5.29657 16.1716C4.54643 16.9217 4.125 17.9391 4.125 19V21M16.125 7C16.125 9.20914 14.3341 11 12.125 11C9.91586 11 8.125 9.20914 8.125 7C8.125 4.79086 9.91586 3 12.125 3C14.3341 3 16.125 4.79086 16.125 7Z"
          stroke="stroke-current"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
        </path>
      </svg>
      <span class="flex items-center gap-0.5">
        <%= humanized_points(@points) %>
        <svg
          class="w-3 h-3 -mt-0.5 shrink-0 stroke-current"
          xmlns="http://www.w3.org/2000/svg"
          width="11"
          height="10"
          viewBox="0 0 11 10"
          fill="none"
        >
          <g clip-path="url(#clip0_67_391)">
            <path
              d="M5.62516 0.833374L6.91266 3.44171L9.79183 3.86254L7.7085 5.89171L8.20016 8.75837L5.62516 7.40421L3.05016 8.75837L3.54183 5.89171L1.4585 3.86254L4.33766 3.44171L5.62516 0.833374Z"
              stroke="stroke-current"
              stroke-width="0.861021"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
            </path>
          </g>
          <defs>
            <clipPath id="clip0_67_391">
              <rect width="10" height="10" fill="white" transform="translate(0.625)"></rect>
            </clipPath>
          </defs>
        </svg>
      </span>
    </.top_navigation_entry>
    """
  end

  @doc """
  Home menu entry.

  ## Examples

      <.home_nav_item />
  """
  attr :is_active, :boolean, default: false, doc: "active state of the navigation item"

  def home_nav_item(assigns) do
    ~H"""
    <.top_navigation_entry is_active={true}>
      <svg
        class="fill-current w-6 h-6 shrink-0"
        xmlns="http://www.w3.org/2000/svg"
        width="25"
        height="24"
        viewBox="0 0 25 24"
        fill="none"
      >
        <path
          fill-rule="evenodd"
          clip-rule="evenodd"
          d="M12.2611 1.21065C12.6222 0.929784 13.1278 0.929784 13.4889 1.21065L22.4889 8.21065C22.7325 8.4001 22.875 8.69141 22.875 9V20C22.875 20.7957 22.5589 21.5587 21.9963 22.1213C21.4337 22.6839 20.6707 23 19.875 23H5.875C5.07935 23 4.31629 22.6839 3.75368 22.1213C3.19107 21.5587 2.875 20.7957 2.875 20V9C2.875 8.69141 3.01747 8.4001 3.26106 8.21065L12.2611 1.21065ZM4.875 9.48908V20C4.875 20.2652 4.98036 20.5196 5.16789 20.7071C5.35543 20.8946 5.60978 21 5.875 21H19.875C20.1402 21 20.3946 20.8946 20.5821 20.7071C20.7696 20.5196 20.875 20.2652 20.875 20V9.48908L12.875 3.26686L4.875 9.48908Z"
          fill="fill-current"
        >
        </path>
        <path
          fill-rule="evenodd"
          clip-rule="evenodd"
          d="M8.875 12C8.875 11.4477 9.32272 11 9.875 11H15.875C16.4273 11 16.875 11.4477 16.875 12V22C16.875 22.5523 16.4273 23 15.875 23C15.3227 23 14.875 22.5523 14.875 22V13H10.875V22C10.875 22.5523 10.4273 23 9.875 23C9.32272 23 8.875 22.5523 8.875 22V12Z"
          fill="fill-current"
        >
        </path>
      </svg>
      <span>Home</span>
    </.top_navigation_entry>
    """
  end

  @doc """
  Chat menu entry.

  ## Examples

      <.chat_nav_item />
  """
  attr :is_active, :boolean, default: false, doc: "active state of the navigation item"

  def chat_nav_item(assigns) do
    ~H"""
    <.top_navigation_entry>
      <svg
        class="stroke-current w-6 h-6 shrink-0"
        xmlns="http://www.w3.org/2000/svg"
        width="25"
        height="24"
        viewBox="0 0 25 24"
        fill="none"
      >
        <path
          d="M21.375 15C21.375 15.5304 21.1643 16.0391 20.7892 16.4142C20.4141 16.7893 19.9054 17 19.375 17H7.375L3.375 21V5C3.375 4.46957 3.58571 3.96086 3.96079 3.58579C4.33586 3.21071 4.84457 3 5.375 3H19.375C19.9054 3 20.4141 3.21071 20.7892 3.58579C21.1643 3.96086 21.375 4.46957 21.375 5V15Z"
          stroke="stroke-current"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
        </path>
      </svg>
      <span>Chat</span>
      <div class="flex -space-x-1.5 absolute top-2 left-1/2">
        <div class="w-4 h-4 shrink-0 rounded-full  overflow-hidden">
          <img
            class="w-full h-full object-cover"
            alt="image"
            src="https://www.wintermeyer.de/assets/images/avatar.jpg"
          />
        </div>
        <div class="rounded-full bg-blue-600 w-4 h-4  text-[9px] text-white flex items-center justify-center font-medium">
          +1
        </div>
      </div>
    </.top_navigation_entry>
    """
  end

  def old_top_navigation(assigns) do
    ~H"""
    <div class="border-y border-brand-silver-100">
      <nav class="grid grid-cols-4 gap-1">
        <button
          type="button"
          class="text-xs text-brand-silver-200 font-medium flex flex-col items-center justify-center gap-1.5 py-3"
        >
          <svg
            class="fill-current w-6 h-6 shrink-0"
            xmlns="http://www.w3.org/2000/svg"
            width="25"
            height="24"
            viewBox="0 0 25 24"
            fill="none"
          >
            <path
              fill-rule="evenodd"
              clip-rule="evenodd"
              d="M12.2611 1.21065C12.6222 0.929784 13.1278 0.929784 13.4889 1.21065L22.4889 8.21065C22.7325 8.4001 22.875 8.69141 22.875 9V20C22.875 20.7957 22.5589 21.5587 21.9963 22.1213C21.4337 22.6839 20.6707 23 19.875 23H5.875C5.07935 23 4.31629 22.6839 3.75368 22.1213C3.19107 21.5587 2.875 20.7957 2.875 20V9C2.875 8.69141 3.01747 8.4001 3.26106 8.21065L12.2611 1.21065ZM4.875 9.48908V20C4.875 20.2652 4.98036 20.5196 5.16789 20.7071C5.35543 20.8946 5.60978 21 5.875 21H19.875C20.1402 21 20.3946 20.8946 20.5821 20.7071C20.7696 20.5196 20.875 20.2652 20.875 20V9.48908L12.875 3.26686L4.875 9.48908Z"
              fill="fill-current"
            />
            <path
              fill-rule="evenodd"
              clip-rule="evenodd"
              d="M8.875 12C8.875 11.4477 9.32272 11 9.875 11H15.875C16.4273 11 16.875 11.4477 16.875 12V22C16.875 22.5523 16.4273 23 15.875 23C15.3227 23 14.875 22.5523 14.875 22V13H10.875V22C10.875 22.5523 10.4273 23 9.875 23C9.32272 23 8.875 22.5523 8.875 22V12Z"
              fill="fill-current"
            />
          </svg>
          <span>Home</span>
        </button>
        <button
          type="button"
          class="text-xs text-brand-silver-200 font-medium flex flex-col items-center justify-center gap-1.5 py-3"
        >
          <svg
            class="stroke-current w-6 h-6 shrink-0"
            xmlns="http://www.w3.org/2000/svg"
            width="25"
            height="24"
            viewBox="0 0 25 24"
            fill="none"
          >
            <g clip-path="url(#clip0_67_382)">
              <path
                d="M21.4651 4.60999C20.9544 4.099 20.3479 3.69364 19.6805 3.41708C19.013 3.14052 18.2976 2.99817 17.5751 2.99817C16.8526 2.99817 16.1372 3.14052 15.4698 3.41708C14.8023 3.69364 14.1959 4.099 13.6851 4.60999L12.6251 5.66999L11.5651 4.60999C10.5334 3.5783 9.13415 2.9987 7.67512 2.9987C6.21609 2.9987 4.81681 3.5783 3.78512 4.60999C2.75343 5.64169 2.17383 7.04096 2.17383 8.49999C2.17383 9.95903 2.75343 11.3583 3.78512 12.39L4.84512 13.45L12.6251 21.23L20.4051 13.45L21.4651 12.39C21.9761 11.8792 22.3815 11.2728 22.658 10.6053C22.9346 9.93789 23.0769 9.22248 23.0769 8.49999C23.0769 7.77751 22.9346 7.0621 22.658 6.39464C22.3815 5.72718 21.9761 5.12075 21.4651 4.60999V4.60999Z"
                stroke="stroke-current"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </g>
            <defs>
              <clipPath id="clip0_67_382">
                <rect width="24" height="24" fill="white" transform="translate(0.625)" />
              </clipPath>
            </defs>
          </svg>
          <span>Likes</span>
        </button>

        <button
          type="button"
          class="text-xs text-brand-silver-200 font-medium flex flex-col items-center justify-center gap-1.5 py-3"
        >
          <svg
            class="stroke-current w-6 h-6 shrink-0"
            xmlns="http://www.w3.org/2000/svg"
            width="25"
            height="24"
            viewBox="0 0 25 24"
            fill="none"
          >
            <path
              d="M21.375 15C21.375 15.5304 21.1643 16.0391 20.7892 16.4142C20.4141 16.7893 19.9054 17 19.375 17H7.375L3.375 21V5C3.375 4.46957 3.58571 3.96086 3.96079 3.58579C4.33586 3.21071 4.84457 3 5.375 3H19.375C19.9054 3 20.4141 3.21071 20.7892 3.58579C21.1643 3.96086 21.375 4.46957 21.375 5V15Z"
              stroke="stroke-current"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
          <span>Chat</span>
        </button>
        <button
          type="button"
          class="text-xs text-brand-silver-200 font-medium flex flex-col items-center justify-center gap-1.5 py-3"
        >
          <svg
            class="stroke-current w-6 h-6 shrink-0"
            xmlns="http://www.w3.org/2000/svg"
            width="25"
            height="24"
            viewBox="0 0 25 24"
            fill="none"
          >
            <path
              d="M20.125 21V19C20.125 17.9391 19.7036 16.9217 18.9534 16.1716C18.2033 15.4214 17.1859 15 16.125 15H8.125C7.06413 15 6.04672 15.4214 5.29657 16.1716C4.54643 16.9217 4.125 17.9391 4.125 19V21M16.125 7C16.125 9.20914 14.3341 11 12.125 11C9.91586 11 8.125 9.20914 8.125 7C8.125 4.79086 9.91586 3 12.125 3C14.3341 3 16.125 4.79086 16.125 7Z"
              stroke="stroke-current"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
          <span class="flex items-center gap-px">
            <%= humanized_points(@points) %>
            <svg
              class="w-2.5 h-2.5 shrink-0 stroke-current"
              xmlns="http://www.w3.org/2000/svg"
              width="11"
              height="10"
              viewBox="0 0 11 10"
              fill="none"
            >
              <g clip-path="url(#clip0_67_391)">
                <path
                  d="M5.62516 0.833374L6.91266 3.44171L9.79183 3.86254L7.7085 5.89171L8.20016 8.75837L5.62516 7.40421L3.05016 8.75837L3.54183 5.89171L1.4585 3.86254L4.33766 3.44171L5.62516 0.833374Z"
                  stroke="stroke-current"
                  stroke-width="0.861021"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </g>
              <defs>
                <clipPath id="clip0_67_391">
                  <rect width="10" height="10" fill="white" transform="translate(0.625)" />
                </clipPath>
              </defs>
            </svg>
          </span>
        </button>
      </nav>
    </div>
    """
  end

  defp humanized_points(points) when points < 1_000 do
    Integer.to_string(points)
  end

  defp humanized_points(points) when points < 1_000_000 do
    Integer.to_string(div(points, 1_000)) <> "K"
  end

  defp humanized_points(points) do
    Integer.to_string(div(points, 1_000_000)) <> "M"
  end
end
