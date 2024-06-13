defmodule AniminaWeb.TopNavigationCompontents do
  @moduledoc """
  Provides animina UI components.
  """
  use Phoenix.Component

  import AniminaWeb.Gettext
  alias Animina.Accounts.Points
  alias Animina.Accounts.User
  alias Animina.StringHelper

  # -------------------------------------------------------------
  @doc """
  Top navigation bar.

  ## Examples

      <.top_navigation current_user={@current_user} />
  """

  def top_navigation(assigns) do
    ~H"""
    <div class="w-[100%] dark:bg-gray-900 text-base bg-white border-[1px] dark:border-gray-800 border-gray-200  flex md:justify-end justify-between items-center py-2 px-4 gap-5  z-50  fixed top-0">
      <div class="md:hidden block" x-data="{ open: false }" @click="open = !open">
        <p class="dark:text-white text-black">
          <.menu_bar />
        </p>
        <div
          x-show="open"
          class=" absolute top-0 w-[100vw] h-[100vh] flex gap-4 items-start border-none  bg-black/60 left-0 "
        >
          <div
            @click.outside="open = false"
            @keydown.escape.window="open = false"
            x-show="open"
            x-transition
            x-cloak
            class="w-[75%]  h-[100%] dark:bg-gray-900 bg-white "
          >
            <.mobile_navigation
              active_tab={@active_tab}
              current_user={@current_user}
              current_user_credit_points={@current_user_credit_points}
              number_of_unread_messages={@number_of_unread_messages}
            />
          </div>

          <div class="text-white p-4" @click="open = false" x-show="open" x-transition x-cloak>
            <.close_icon />
          </div>
        </div>
      </div>
      <div :if={@current_user} class="flex items-center md:gap-5 gap-3">
        <div>
          <.top_notification_bell
            current_user={@current_user}
            number_of_unread_messages={@number_of_unread_messages}
          />
        </div>
        <div
          x-data="{ open: false }"
          @click="open = !open"
          class="flex cursor-pointer dark:text-white  gap-2 items-center"
        >
          <.user_avatar_image current_user={@current_user} />
          <p :if={@current_user} class="md:block hidden">
            <%= StringHelper.truncate_name(@current_user.name) %>
          </p>

          <button class="dark:text-white md:block hidden" type="button">
            <.arrow_down />
          </button>
          <div
            @click.outside="open = false"
            @keydown.escape.window="open = false"
            x-show="open"
            x-transition
            x-cloak
            class=" absolute top-8  right-2 py-3"
          >
            <.dropdown_items current_user={@current_user} active_tab={@active_tab} />
          </div>
        </div>
      </div>

      <div :if={@current_user == nil} class="flex items-center md:gap-5 gap-3">
        <div :if={@active_tab == :sign_in}>
          <p class="dark:text-gray-500 text-gray-400 cursor-not-allowed">
            <%= gettext("Login") %>
          </p>
        </div>

        <div :if={@active_tab != :sign_in}>
          <.link class=" dark:text-white cursor-pointer  text-gray-700" navigate="/sign-in">
            <%= gettext("Login") %>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp arrow_down(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      class="size-6"
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="m19.5 8.25-7.5 7.5-7.5-7.5" />
    </svg>
    """
  end

  defp menu_bar(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      class="size-6"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
      />
    </svg>
    """
  end

  defp close_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      class="size-6"
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
    </svg>
    """
  end

  defp dropdown_items(assigns) do
    ~H"""
    <div>
      <%= if @current_user  do %>
        <div class="dark:bg-gray-900    text-gray-700 block w-[80%] ml-[20%]  py-2 text-sm bg-white shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none flex flex-col rounded-md gap-2  dark:text-white">
          <div class="border-gray-100 border-b-[1px]  py-1">
            <p class="text-sm px-2 " role="none"><%= gettext("Signed in as") %></p>
            <p class="truncate text-sm px-2 font-medium dark:text-gray-400 text-gray-900">
              <%= StringHelper.truncate_username(@current_user.username) %>
            </p>
          </div>
          <.link class="px-2" navigate="/my/flags/white">
            <%= gettext("Edit White Flags") %>
          </.link>
          <.link class="px-2" navigate="/my/flags/green">
            <div class="flex gap-2 items-center">
              <%= gettext("Edit Green Flags") %> <p class="bg-green-500 w-2 h-2 rounded-full" />
            </div>
          </.link>
          <.link class="px-2" navigate="/my/flags/red">
            <div class="flex gap-2 items-center">
              <%= gettext("Edit Red Flags") %> <p class="bg-red-500 w-2 h-2 rounded-full" />
            </div>
          </.link>
          <.link class="px-2" navigate="/my/potential-partner">
            <%= gettext("Edit Potential Partner Preferences") %>
          </.link>
          <p class=" h-[1px] bg-gray-100 my-1 w-[100%]"></p>
          <.link class="px-2" navigate="/auth/user/sign-out">
            <%= gettext("Sign Out") %>
          </.link>
        </div>
      <% else %>
        <div class="dark:bg-gray-900 text-gray-700  text-sm bg-white shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none flex flex-col rounded-md gap-2 dark:text-white  p-4 ">
          <.link :if={@active_tab != :register} navigate="/">
            <%= gettext("Register") %>
          </.link>
          <.link navigate="/sign-in">
            <%= gettext("Login") %>
          </.link>
        </div>
      <% end %>
    </div>
    """
  end

  def mobile_navigation(assigns) do
    ~H"""
    <div class="flex flex-col p-4 gap-2">
      <div :if={@current_user} class="flex flex-col gap-2">
        <.home_nav_item current_user={@current_user} active_tab={@active_tab} />
        <.profile_nav_item current_user={@current_user} active_tab={@active_tab} />
        <.bookmarks_nav_item current_user={@current_user} active_tab={@active_tab} />

        <.user_profile_item
          current_user={@current_user}
          active_tab={@active_tab}
          current_user_credit_points={@current_user_credit_points}
        />
      </div>
      <div class="flex w-[100%]  flex-col gap-2">
        <p class=" dark:text-white"><%= gettext("Could Interest You") %></p>

        <div class="flex w-[100%] flex-col gap-2">
          <.random_interests
            current_user={@current_user}
            interests={six_random_public_users(@current_user)}
          />
        </div>
      </div>
    </div>
    """
  end

  def desktop_sidebar_navigation(assigns) do
    ~H"""
    <div class="w-[20%] md:block hidden z-40 h-[100vh] fixed top-0 pt-[60px] dark:bg-gray-900 bg-white border-[1px] dark:border-gray-800 border-gray-200">
      <div :if={@current_user} class="flex flex-col p-4 gap-2">
        <.home_nav_item current_user={@current_user} active_tab={@active_tab} />
        <.profile_nav_item current_user={@current_user} active_tab={@active_tab} />
        <.bookmarks_nav_item current_user={@current_user} active_tab={@active_tab} />

        <.user_profile_item
          current_user={@current_user}
          active_tab={@active_tab}
          current_user_credit_points={@current_user_credit_points}
        />
      </div>

      <div class="flex w-[100%]  p-4 flex-col gap-2">
        <p class=" dark:text-white"><%= gettext("Could Interest You") %></p>

        <div class="flex w-[100%] flex-col gap-2">
          <.random_interests
            interests={six_random_public_users(@current_user)}
            current_user={@current_user}
          />
        </div>
      </div>
    </div>
    """
  end

  defp random_interests(assigns) do
    ~H"""
    <div class="w-[100%]">
      <%= for interest <- @interests do %>
        <.random_interest interest={interest} current_user={@current_user} />
      <% end %>
    </div>
    """
  end

  defp random_interest(assigns) do
    ~H"""
    <.top_navigation_entry phx-no-format is_active={false}>
    <.link navigate={"/#{@interest.username}"} >
    <div class="flex gap-2 w-[100%] flex-row items-center" >
    <%= if @interest.profile_photo && display_image(@interest.profile_photo.state , @current_user, @interest.profile_photo) do %>
    <div class="relative">
    <.user_avatar_image  current_user={@interest} />
    <p :if={@interest.profile_photo.state != :approved} class={"absolute top-0 right-0 #{get_photo_state_styling(@interest.profile_photo.state)}"}/>

    </div>
    <%else %>

    <.error_or_nsfw_profile_image />
    <%end %>
    <p>
        <%= StringHelper.truncate_name(@interest.name) %>
    </p>

    </div>
    </.link>


    </.top_navigation_entry>
    """
  end

  defp get_photo_state_styling(:error) do
    "bg-red-500 text-white w-2 h-2 rounded-full"
  end

  defp get_photo_state_styling(:nsfw) do
    "bg-red-500 text-white w-2 h-2 rounded-full"
  end

  defp get_photo_state_styling(:rejected) do
    "bg-red-500 text-white w-2 h-2 rounded-full"
  end

  defp get_photo_state_styling(:pending_review) do
    "bg-yellow-500 text-white w-2 h-2 rounded-full"
  end

  defp get_photo_state_styling(:in_review) do
    "bg-blue-500 text-white w-4 h-4 rounded-full"
  end

  defp get_photo_state_styling(_) do
    "bg-green-500 text-white w-4 h-4 rounded-full"
  end

  def display_image(:pending_review, _, _) do
    true
  end

  def display_image(:approved, _, _) do
    true
  end

  def display_image(:in_review, _, _) do
    true
  end

  def display_image(:nsfw, current_user, photo) do
    if current_user && (current_user.id == photo.user_id || admin_user?(current_user)) do
      true
    else
      false
    end
  end

  def display_image(:error, current_user, photo) do
    if current_user && (current_user.id == photo.user_id || admin_user?(current_user)) do
      true
    else
      false
    end
  end

  def display_image(_, _, _) do
    false
  end

  def admin_user?(nil) do
    false
  end

  def admin_user?(current_user) do
    case current_user.roles do
      [] ->
        false

      roles ->
        roles
        |> Enum.map(fn x -> x.name end)
        |> Enum.any?(fn x -> x == :admin end)
    end
  end

  defp error_or_nsfw_profile_image(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="w-6 h-6 stroke-current shrink-0"
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
      class={"relative  #{if @is_active do "bg-blue-100 text-blue-600" else "text-gray-400" end} text-base hover:bg-blue-100 hover:text-blue-600 transition-all ease-in-out duration-500 w-[100%]   flex flex-row items-center justify-start  rounded-md  gap-1.5 py-3 px-3   shadow-none drop-shadow-none"}
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
  attr :current_user_credit_points, :integer, doc: "current user credit points"

  def user_profile_item(assigns) do
    ~H"""
    <.top_navigation_entry phx-no-format is_active={@active_tab == :profile_points}>
      <%= if @current_user && @current_user.profile_photo  do %>
        <img class="object-cover w-6 h-6 rounded-full"  src={"/uploads/#{@current_user.profile_photo.filename}"} />
      <% else %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-6 h-6 stroke-current shrink-0"
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
          <%= gettext("Points") %>: <span id="current-user-credit-points"> <%= if is_number @current_user_credit_points  do  Points.humanized_points(@current_user_credit_points) else    @current_user_credit_points end  %> </span>
        <% else %>
          <%= gettext("Points") %>: 0
        <% end %>
        </span>
      </.top_navigation_entry>
    """
  end

  def user_avatar_image(assigns) do
    ~H"""
    <div>
      <%= if @current_user && @current_user.profile_photo  do %>
        <img
          class="object-cover w-8 h-8 rounded-full"
          src={"/uploads/#{@current_user.profile_photo.filename}"}
        />
      <% else %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-6 h-6 stroke-current shrink-0"
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
      <% end %>
    </div>
    """
  end

  def top_notification_bell(assigns) do
    ~H"""
    <div class="flex dark:text-white gap-1">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="size-6"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M14.857 17.082a23.848 23.848 0 0 0 5.454-1.31A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6 9v.75a8.967 8.967 0 0 1-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 0 1-5.714 0m5.714 0a3 3 0 1 1-5.714 0"
        />
      </svg>
      <%= if (@current_user && @number_of_unread_messages > 0) do %>
        <div class="rounded-full bg-blue-600 w-4 h-4 text-[9px] text-white flex items-center justify-center ">
          <%= @number_of_unread_messages %>
        </div>
      <% end %>
    </div>
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
  attr :current_user, :any, doc: "current user"

  def home_nav_item(assigns) do
    ~H"""
    <.top_navigation_entry phx-no-format is_active={@active_tab == :home}>
    <div :if={@current_user == nil}>
    <.link navigate={"/sign-in/"} class="flex gap-2 flex-row items-center" >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="w-6 h-6 fill-current shrink-0"
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
      <span><%= gettext("Home") %></span>
      </.link>
      </div>


     <div :if={@current_user != nil}>
     <.link navigate={"/my/dashboard"} class="flex gap-2 flex-row items-center" >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="w-6 h-6 fill-current shrink-0"
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
      <span><%= gettext("Home") %></span>
      </.link>
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
  attr :number_of_unread_messages, :integer, doc: "number of unread messages"

  def chat_nav_item(assigns) do
    ~H"""
    <.top_navigation_entry phx-no-format is_active={@active_tab == :chat}>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="w-6 h-6 stroke-current shrink-0"
        width="25" height="24" viewBox="0 0 25 24"
        fill="none"
      >
        <path
          d="M21.375 15C21.375 15.5304 21.1643 16.0391 20.7892 16.4142C20.4141 16.7893 19.9054 17 19.375 17H7.375L3.375 21V5C3.375 4.46957 3.58571 3.96086 3.96079 3.58579C4.33586 3.21071 4.84457 3 5.375 3H19.375C19.9054 3 20.4141 3.21071 20.7892 3.58579C21.1643 3.96086 21.375 4.46957 21.375 5V15Z"
          stroke="stroke-current" stroke-width="2"
          stroke-linecap="round" stroke-linejoin="round"
        />
      </svg>
      <span><%= gettext("Chat") %></span>
      <div class="flex -space-x-1.5 absolute top-2 left-1/2">
        <div
          class="w-4 h-4 overflow-hidden rounded-full shrink-0"
          aria-hidden="true"
        >
        <%= if @current_user && @current_user.profile_photo  do %>
        <img class="object-cover w-full h-full rounded-full"  src={"/uploads/#{@current_user.profile_photo.filename}"} />
      <% else %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-full h-full stroke-current shrink-0"
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
        </div>
        <div class="rounded-full bg-blue-600 w-4 h-4 text-[9px] text-white flex items-center justify-center">
          <%= @number_of_unread_messages %>
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
    <.top_navigation_entry
      phx-no-format
      is_active={if @active_tab == :bookmarks, do: true, else: false}
    >

    <div class="flex gap-2 flex-row items-center" :if={@current_user == nil}>

    <svg xmlns="http://www.w3.org/2000/svg" width="25" height="24" viewBox="0 0 384 512" style="fill: currentColor;">
    <!--!Font Awesome Free 6.5.1 by @fontawesome - https://fontawesome.com
        License - https://fontawesome.com/license/free Copyright 2024
        Fonticons, Inc.-->
    <path d="M0 48C0 21.5 21.5 0 48 0l0 48V441.4l130.1-92.9c8.3-6 19.6-6 27.9 0L336 441.4V48H48V0H336c26.5 0 48 21.5 48 48V488c0 9-5 17.2-13 21.3s-17.6 3.4-24.9-1.8L192 397.5 37.9 507.5c-7.3 5.2-16.9 5.9-24.9 1.8S0 497 0 488V48z" />
    </svg>
    <span><%= gettext("Bookmarks") %></span>

    </div>

    <div :if={@current_user != nil}>
     <.link navigate={"/my/bookmarks"} class="flex gap-2 flex-row items-center" >
    <svg xmlns="http://www.w3.org/2000/svg" width="25" height="24" viewBox="0 0 384 512" style="fill: currentColor;">
    <!--!Font Awesome Free 6.5.1 by @fontawesome - https://fontawesome.com
    License - https://fontawesome.com/license/free Copyright 2024
    Fonticons, Inc.-->
     <path d="M0 48C0 21.5 21.5 0 48 0l0 48V441.4l130.1-92.9c8.3-6 19.6-6 27.9 0L336 441.4V48H48V0H336c26.5 0 48 21.5 48 48V488c0 9-5 17.2-13 21.3s-17.6 3.4-24.9-1.8L192 397.5 37.9 507.5c-7.3 5.2-16.9 5.9-24.9 1.8S0 497 0 488V48z" />
    </svg>
       <span><%= gettext("Bookmarks") %></span>

    </.link>
    </div>

    </.top_navigation_entry>
    """
  end

  @doc """
  Profile Entry

  ## Examples

      <.profile_nav_item />
  """
  attr :active_tab, :atom, default: nil, doc: "active tab"
  attr :current_user, :any, default: nil, doc: "current user"

  def profile_nav_item(assigns) do
    ~H"""
    <.top_navigation_entry phx-no-format is_active={if @active_tab == :profile, do: true, else: false}>


    <div class="flex gap-2 flex-row items-center" :if={@current_user == nil}>



    <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-6 h-6 stroke-current shrink-0"
          width="25" height="24" viewBox="0 0 25 24"
          fill="none"
        >
          <path
            d="M17.982 18.725A7.488 7.488 0 0012 15.75a7.488 7.488 0 00-5.982 2.975m11.963 0a9 9 0 10-11.963 0m11.963 0A8.966 8.966 0 0112 21a8.966 8.966 0 01-5.982-2.275M15 9.75a3 3 0 11-6 0 3 3 0 016 0z"
            stroke="stroke-current" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round"
          />
        </svg>
    <span><%= gettext("Profile") %></span>

    </div>

    <div :if={@current_user != nil}>
     <.link navigate={"/#{@current_user.username}"} class="flex gap-2 flex-row items-center" >
     <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-6 h-6 stroke-current shrink-0"
          width="25" height="24" viewBox="0 0 25 24"
          fill="none"
        >
          <path
            d="M17.982 18.725A7.488 7.488 0 0012 15.75a7.488 7.488 0 00-5.982 2.975m11.963 0a9 9 0 10-11.963 0m11.963 0A8.966 8.966 0 0112 21a8.966 8.966 0 01-5.982-2.275M15 9.75a3 3 0 11-6 0 3 3 0 016 0z"
            stroke="stroke-current" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round"
          />
        </svg>
       <span><%= gettext("Profile") %></span>

    </.link>
    </div>

    </.top_navigation_entry>
    """
  end

  defp six_random_public_users(nil) do
    (three_random_public_male_users() ++ three_random_public_female_users())
    |> Enum.shuffle()
  end

  defp six_random_public_users(current_user) do
    AniminaWeb.PotentialPartner.potential_partners(current_user, limit: 6)
  end

  defp three_random_public_female_users do
    case User.female_public_users_who_created_an_account_in_the_last_60_days() do
      {:ok, users} ->
        Enum.take_random(users, 3)

      {:error, _reason} ->
        []
    end
  end

  defp three_random_public_male_users do
    case User.male_public_users_who_created_an_account_in_the_last_60_days() do
      {:ok, users} ->
        Enum.take_random(users, 3)

      {:error, _reason} ->
        []
    end
  end
end
