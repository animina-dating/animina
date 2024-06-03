defmodule AniminaWeb.ChatComponents do
  @moduledoc """
  Provides Chat UI components.
  """
  use Phoenix.Component
  alias Animina.Markdown
  alias AniminaWeb.ProfileComponents
  import AniminaWeb.Gettext

  def send_message_button(assigns) do
    ~H"""
    <div>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        width="20"
        height="20"
        stroke="currentColor"
        aria-hidden="true"
        class="-rotate-12"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5"
        />
      </svg>
    </div>
    """
  end

  def chat_messages_component(assigns) do
    ~H"""
    <div class="h-[80vh]  w-[100%] ">
      <div class="w-[100%] h-[100%] flex flex-col justify-between">
        <div class=" w-[100%] z-50">
          <.link navigate={"/#{@receiver.username}"}>
            <ProfileComponents.profile_details
              user={@receiver}
              current_user={@sender}
              current_user_has_liked_profile?={@current_user_has_liked_profile?}
              profile_points={@profile_points}
              intersecting_green_flags_count={@intersecting_green_flags_count}
              intersecting_red_flags_count={@intersecting_red_flags_count}
              years_text={@years_text}
              display_chat_icon={false}
              display_profile_image_next_to_name={true}
              show_intersecting_flags_count={false}
              centimeters_text={@centimeters_text}
            />

            <div class="flex items-center flex-wrap mb-2  w-[100%]">
              <.intersecting_green_flags
                green_flags={@intersecting_green_flags}
                count={@intersecting_green_flags_count}
              />
              <.intersecting_red_flags
                red_flags={@intersecting_red_flags}
                count={@intersecting_red_flags_count}
              />
            </div>
          </.link>
        </div>
        <div class="h-[85%] z-0  w-[100%]">
          <.messages_box messages={@messages} sender={@sender} receiver={@receiver} />
        </div>
      </div>
    </div>
    """
  end

  def messages_box(assigns) do
    ~H"""
    <div class="flex h-[100%] ">
      <div
        id="ChatMessagesBox"
        phx-hook="ScrollToBottom"
        class="flex flex-col w-[100%]  flex-col-reverse  py-12 transition-all duration-500  overflow-y-scroll  gap-2"
      >
        <%= for message <-@messages do %>
          <div class="w-[100%]">
            <.sent_message
              message={message}
              content={message.content}
              sender={@sender}
              receiver={@receiver}
            />
            <.received_message
              message={message}
              content={message.content}
              sender={@sender}
              receiver={@receiver}
            />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def sent_message(assigns) do
    ~H"""
    <%= if @sender.id == @message.sender_id do %>
      <div class="flex justify-end items-start  gap-4 text-white  ">
        <div class="justify-end flex items-end flex-col">
          <p>
            You
          </p>
          <div class="md:w-[300px] w-[250px] bg-blue-500 flex text-white p-1 items-end flex flex-col gap-2  rounded-md">
            <p>
              <%= Markdown.format(@content) %>
            </p>

            <div :if={@message.read_at != nil} class="text-xs px-2 flex justify-end">
              <%= format_time(@message.read_at) %>
              <.already_read_ticks />
            </div>
            <div :if={@message.read_at == nil} class="text-xs px-2 flex justify-end">
              <%= format_time(@message.created_at) %>
            </div>
          </div>
        </div>
        <.sender_user_image user={@sender} />
      </div>
    <% end %>
    """
  end

  def received_message(assigns) do
    ~H"""
    <%= if @sender.id != @message.sender_id do %>
      <div class="flex justify-start gap-4  item-start text-black">
        <.receiver_user_image user={@receiver} current_user={@sender} />
        <div class="justify-start flex items-start flex-col">
          <p class="dark:text-white">
            <%= @receiver.name %>
          </p>
          <div class="md:w-[300px w-[250px]   dark:bg-white bg-gray-300 text-black   flex flex-col gap-2 justify-between p-1 items-end rounded-md">
            <p>
              <%= Markdown.format(@content) %>
            </p>

            <div :if={@message.read_at != nil} class="text-xs px-2 flex justify-end">
              <%= format_time(@message.created_at) %>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def sender_user_image(assigns) do
    ~H"""
    <%= if @user && @user.profile_photo  do %>
      <div class="flex flex-col justify-center items-center gap-1">
        <img
          class="object-cover w-8 h-8 rounded-full"
          src={"/uploads/#{@user.profile_photo.filename}"}
        />

        <p
          :if={@user && @user.profile_photo.state != :approved}
          class={"p-1 text-[10px] #{get_photo_state_styling(@user.profile_photo.state)}  rounded-md "}
        >
          <%= get_photo_state_name(@user.profile_photo.state) %>
        </p>
      </div>
    <% else %>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-6 h-6 dark:text-white text-black"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z"
        />
      </svg>
    <% end %>
    """
  end

  def receiver_user_image(assigns) do
    ~H"""
    <%= if @user && @user.profile_photo && display_image(@user.profile_photo.state, @current_user, @user) do %>
      <div class="flex flex-col gap-1 justify-center items-center">
        <img
          class="object-cover w-8 h-8 rounded-full"
          src={"/uploads/#{@user.profile_photo.filename}"}
        />

        <p
          :if={@user.profile_photo.state != :approved}
          class={"p-1 text-[10px] #{get_photo_state_styling(@user.profile_photo.state)}  rounded-md "}
        >
          <%= get_photo_state_name(@user.profile_photo.state) %>
        </p>
      </div>
    <% else %>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-6 h-6 dark:text-white text-black"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z"
        />
      </svg>
    <% end %>
    """
  end

  defp get_photo_state_styling(:error) do
    "bg-red-500 text-white"
  end

  defp get_photo_state_styling(:nsfw) do
    "bg-red-500 text-white"
  end

  defp get_photo_state_styling(:rejected) do
    "bg-red-500 text-white"
  end

  defp get_photo_state_styling(:pending_review) do
    "bg-yellow-500 text-white"
  end

  defp get_photo_state_styling(:in_review) do
    "bg-blue-500 text-white"
  end

  defp get_photo_state_name(:error) do
    gettext("Error")
  end

  defp get_photo_state_name(:nsfw) do
    gettext("NSFW")
  end

  defp get_photo_state_name(:rejected) do
    gettext("Rejected")
  end

  defp get_photo_state_name(:pending_review) do
    gettext("Pending review")
  end

  defp get_photo_state_name(:in_review) do
    gettext("In review")
  end

  defp get_photo_state_name(_) do
    gettext("Error")
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

  def display_image(:nsfw, current_user, receiver) do
    if current_user.id == receiver.id || admin_user?(current_user) do
      true
    else
      false
    end
  end

  def display_image(:error, current_user, receiver) do
    if current_user.id == receiver.id || admin_user?(current_user) do
      true
    else
      false
    end
  end

  def display_image(_, _, _) do
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

  def already_read_ticks(assigns) do
    ~H"""
    <div class="flex  gap-0 relative">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 20 20"
        class="text-green-500"
        aria-hidden="true"
        width="12"
        height="12"
        fill="#52A35D"
      >
        <path
          fill-rule="evenodd"
          d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
          clip-rule="evenodd"
        />
      </svg>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 20 20"
        aria-hidden="true"
        width="12"
        height="12"
        fill="#52A35D"
        class="absolute  left-1/2"
      >
        <path
          fill-rule="evenodd"
          d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
          clip-rule="evenodd"
        />
      </svg>
    </div>
    """
  end

  def format_time(time) do
    NaiveDateTime.from_erl!({{2000, 1, 1}, Time.to_erl(time)}) |> Timex.format!("{h12}:{0m} {am}")
  end

  def intersecting_red_flags(assigns) do
    ~H"""
    <div class="flex flex-wrap relative ">
      <%= for flag <- @red_flags do %>
        <span
          :if={flag != %{}}
          class="inline-flex items-center px-2 py-1 mx-1 my-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md"
        >
          <%= flag.emoji %> <%= flag.name %>

          <div class="pl-2">
            <p class="w-2 h-2 bg-red-500 rounded-full" />
          </div>
        </span>
      <% end %>

      <div
        :if={@count > 5}
        class="text-blue-700 flex flex-row text-[10px]  justify-center items-center bg-blue-100 h-4 w-4 rounded-full"
      >
        <span> + </span> <%= @count - 5 %>
      </div>
    </div>
    """
  end

  def intersecting_green_flags(assigns) do
    ~H"""
    <div class="flex flex-wrap relative ">
      <%= for flag <- @green_flags do %>
        <span
          :if={flag != %{}}
          class="inline-flex items-center px-2 py-1 mx-1 my-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md"
        >
          <%= flag.emoji %> <%= flag.name %>

          <div class="pl-2">
            <p class="w-2 h-2 bg-green-500 rounded-full" />
          </div>
        </span>
      <% end %>

      <div
        :if={@count > 5}
        class="text-blue-700 flex flex-row text-[10px]  justify-center items-center bg-blue-100 h-4 w-4 rounded-full"
      >
        <span> + </span> <%= @count - 5 %>
      </div>
    </div>
    """
  end
end
