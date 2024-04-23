defmodule AniminaWeb.ChatComponents do
  @moduledoc """
  Provides Chat UI components.
  """
  use Phoenix.Component
  alias Animina.Markdown

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
        <div class="h-[7%] w-[100%]">
          <.receiver_profile_box receiver={@receiver} />
        </div>
        <div class="h-[93%]  w-[100%]">
          <.messages_box messages={@messages} sender={@sender} receiver={@receiver} />
        </div>
      </div>
    </div>
    """
  end

  def messages_box(assigns) do
    ~H"""
    <div class="flex h-[100%] flex-col-reverse">
      <div
        id="ChatMessagesBox"
        phx-hook="ScrollToBottom"
        class="flex flex-col w-[100%] md:p-4 p-2  py-8 transition-all duration-500  overflow-y-scroll  gap-2"
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
          <div class="md:w-[300px] w-[250px] bg-blue-500 flex text-white p-2 items-end  rounded-md">
            <p>
              <%= Markdown.format(@content) %>
            </p>
          </div>
        </div>
        <.user_image user={@sender} />
      </div>
    <% end %>
    """
  end

  def received_message(assigns) do
    ~H"""
    <%= if @sender.id != @message.sender_id do %>
      <div class="flex justify-start gap-4  item-start text-black">
        <.user_image user={@receiver} />
        <div class="justify-start flex items-start flex-col">
          <p class="dark:text-white">
            <%= @receiver.username %>
          </p>
          <div class="md:w-[300px w-[250px]   dark:bg-white bg-gray-300 text-black  flex p-2 items-end rounded-md">
            <p>
              <%= Markdown.format(@content) %>
            </p>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def receiver_profile_box(assigns) do
    ~H"""
    <div class="bg-indigo-500 p-4 text-white h-[100%] flex gap-4 items-center">
      <div class="flex items-center gap-2">
        <.user_image user={@receiver} />
        <p>
          <%= @receiver.username %>
        </p>
      </div>
    </div>
    """
  end

  def user_image(assigns) do
    ~H"""
    <%= if @user && @user.profile_photo  do %>
      <img class="object-cover w-8 h-8 rounded-full" src={"/uploads/#{@user.profile_photo.filename}"} />
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
end
