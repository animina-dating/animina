defmodule AniminaWeb.ChatComponents do
  @moduledoc """
  Provides Chat UI components.
  """
  use Phoenix.Component

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
        <div class="h-[5%] w-[100%]">
          <.receiver_profile_box receiver={@receiver} />
        </div>
        <div class="h-[95%]  w-[100%]">
          <.messages_box messages={@messages} sender={@sender} />
        </div>
      </div>
    </div>
    """
  end

  def messages_box(assigns) do
    ~H"""
    <div class="flex h-[100%] flex-col-reverse">
      <div class="flex flex-col w-[100%] md:p-4 p-2    overflow-y-scroll  gap-2">
        <%= for message <-@messages do %>
          <div class="w-[100%]">
            <div class={get_message_box_styling(@sender.id, message)}>
              <p class={get_each_message_styling(@sender.id, message)}>
                <%= message.content %>
              </p>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def receiver_profile_box(assigns) do
    ~H"""
    <div class="bg-indigo-500 text-white h-[100%] flex gap-4 items-center">
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
      <img class="object-cover w-6 h-6 rounded-full" src={"/uploads/#{@user.profile_photo.filename}"} />
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
    """
  end

  defp get_message_box_styling(sender_id, message) do
    if sender_id == message.sender_id do
      "flex justify-end   text-white  "
    else
      "flex justify-start   text-black "
    end
  end

  defp get_each_message_styling(sender_id, message) do
    if sender_id == message.sender_id do
      " w-[300px] bg-blue-500 flex text-white p-2 items-end  rounded-md "
    else
      " w-[300px]   bg-white text-black  flex p-2 items-end rounded-md"
    end
  end
end
