defmodule AniminaWeb.DashboardComponents do
  @moduledoc """
  Provides Dashboard UI components.
  """
  use Phoenix.Component
  alias Animina.Markdown
  import AniminaWeb.Gettext
  import AniminaWeb.CoreComponents
  import Phoenix.HTML.Form

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :inner_block

  def dashboard_card_component(assigns) do
    ~H"""
    <div class="overflow-hidden bg-white dark:bg-gray-800 divide-y divide-gray-200 rounded-lg shadow">
      <div class="px-4  dark:bg-gray-800 py-5 sm:px-6 bg-gray-50">
        <h3 class="text-base font-semibold leading-7 dark:text-gray-300 text-gray-900">
          <%= @title %>
        </h3>
        <p :if={@subtitle} class="max-w-2xl mt-1 text-sm leading-6 text-gray-500">
          <%= @subtitle %>
        </p>
      </div>
      <div class="px-4 py-5 sm:p-6">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def dashboard_card_like_component(assigns) do
    ~H"""
    <.dashboard_card_component title={@title}>
      <div class="flex flex-col gap-3">
        <div class="flex flex-col gap-1 text-black dark:text-white">
          <div class="overflow-hidden border-b dark:border-gray-700 border-gray-200 rounded shadow">
            <table class="min-w-full text-left bg-white table-auto ">
              <thead>
                <tr class="text-white dark:bg-gray-700 bg-gray-800">
                  <th class="px-4 py-3"><%= gettext("Type") %></th>
                  <th class="px-4 py-3"><%= gettext("Period of Time") %></th>
                  <th class="px-4 py-3"><%= gettext("Count") %></th>
                </tr>
              </thead>
              <tbody class="text-gray-700 dark:bg-gray-300">
                <tr>
                  <td class="px-4 py-3"><%= gettext("Received") %></td>
                  <td class="px-4 py-3"><%= gettext("Last 7 days") %></td>
                  <td class="px-4 py-3"><%= @likes_received_by_user_in_seven_days %></td>
                </tr>
                <tr class="dark:bg-gray-200 bg-gray-100">
                  <td class="px-4 py-3"><%= gettext("Received") %></td>
                  <td class="px-4 py-3"><%= gettext("Forever") %></td>
                  <td class="px-4 py-3"><%= @total_likes_received_by_user %></td>
                </tr>
                <tr>
                  <td class="px-4 py-3">
                    <.link navigate="/my/bookmarks/liked" class="text-blue-500">
                      <%= gettext("Given") %>
                    </.link>
                  </td>
                  <td class="px-4 py-3"><%= gettext("Forever") %></td>
                  <td class="px-4 py-3">
                    <.link navigate="/my/bookmarks/liked" class="text-blue-500">
                      <%= @profiles_liked_by_user %>
                    </.link>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </.dashboard_card_component>
    """
  end

  def dashboard_card_chat_component(assigns) do
    ~H"""
    <.dashboard_card_component title={@title}>
      <div class="flex flex-col gap-3">
        <%= if @last_unread_message do %>
          <div class="relative h-[200px]">
            <.unread_message
              sender={@last_unread_message.sender}
              content={@last_unread_message.content}
              language={@language}
              message={@last_unread_message}
              receiver={@current_user}
            />

            <div class="w-[100%]  absolute bottom-0">
              <.send_message_from_dashboard_box
                sender={@current_user}
                receiver={@last_unread_message.sender}
                form={@form}
              />
            </div>
          </div>
        <% else %>
          <div class="h-[200px]">
            <.no_unread_messages_component />
          </div>
        <% end %>
      </div>
    </.dashboard_card_component>
    """
  end

  def dashboard_card_messages_component(assigns) do
    ~H"""
    <.dashboard_card_component title={@title}>
      <div class="flex flex-col gap-3">
        <%= if @unread_messages != [] do %>
          <div class="h-[230px] overflow-y-scroll flex flex-col gap-1 py-1">
            <%= for message <- @unread_messages do %>
              <div>
                <.link navigate={"/my/messages/#{message.sender.username}"} class="mx-auto w-[100%]">
                  <.unread_message
                    sender={message.sender}
                    content={message.content}
                    language={@language}
                    message={message}
                    receiver={@current_user}
                  />
                </.link>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="h-[200px]">
            <.no_unread_messages_component />
          </div>
        <% end %>
      </div>
    </.dashboard_card_component>
    """
  end

  defp unread_message(assigns) do
    ~H"""
    <div class="w-[100%]">
      <div class="flex justify-start gap-2  m-auto w-[95%] item-start text-black">
        <.sender_user_image user={@sender} current_user={@receiver} />
        <div class="justify-start w-[100%] flex items-start flex-col">
          <p class="text-xs dark:text-white">
            <%= @sender.name %>
          </p>
          <div class=" w-[100%]  text-xs   dark:bg-gray-100 bg-gray-300 text-black   flex flex-col gap-1 justify-between px-1 items-start rounded-md">
            <p class="px-1">
              <%= Markdown.format(@content) %>
            </p>

            <div class="flex justify-end px-1 text-xs italic">
              <%= Timex.from_now(@message.created_at, @language) %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def sender_user_image(assigns) do
    ~H"""
    <%= if @current_user && @user.profile_photo && display_image(@user.profile_photo.state, @current_user, @user) do %>
      <div class="relative">
        <img
          class="object-cover w-6 h-6 rounded-full"
          src={"/uploads/#{@user.profile_photo.filename}"}
        />

        <p
          :if={@user.profile_photo.state == :nsfw}
          class="absolute p-1 text-xs text-black bg-gray-200 rounded-md dark:bg-gray-800 bottom-2 right-4 dark:text-white"
        >
          nsfw
        </p>
      </div>
    <% else %>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-6 h-6 text-black dark:text-white"
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

  def display_image(:nsfw, current_user, _receiver) do
    if admin_user?(current_user) do
      true
    else
      false
    end
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

  def format_time(time) do
    NaiveDateTime.from_erl!({{2000, 1, 1}, Time.to_erl(time)}) |> Timex.format!("{h12}:{0m} {am}")
  end

  defp no_unread_messages_component(assigns) do
    ~H"""
    <div class="flex flex-col justify-center items-center h-[100%] dark:text-white text-black gap-4">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="currentColor"
        aria-hidden="true"
        width="40"
        height="40"
      >
        <path
          fill-rule="evenodd"
          d="M4.848 2.771A49.144 49.144 0 0112 2.25c2.43 0 4.817.178 7.152.52 1.978.292 3.348 2.024 3.348 3.97v6.02c0 1.946-1.37 3.678-3.348 3.97a48.901 48.901 0 01-3.476.383.39.39 0 00-.297.17l-2.755 4.133a.75.75 0 01-1.248 0l-2.755-4.133a.39.39 0 00-.297-.17 48.9 48.9 0 01-3.476-.384c-1.978-.29-3.348-2.024-3.348-3.97V6.741c0-1.946 1.37-3.68 3.348-3.97z"
          clip-rule="evenodd"
        />
      </svg>
      <p>
        No Unread Messages
      </p>
    </div>
    """
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
  end

  def send_message_from_dashboard_box(assigns) do
    ~H"""
    <div class=" w-[95%] m-auto ">
      <.form
        :let={f}
        for={@form}
        phx-change="validate"
        phx-submit="submit"
        class="w-[100%] flex justify-between items-end"
      >
        <div phx-feedback-for={f[:content].name} class="w-[85%] ">
          <%= textarea(
            f,
            :content,
            class:
              "block w-full h-[50px] rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                unless(get_field_errors(f[:content], :content) == [],
                  do: "ring-red-600 focus:ring-red-600",
                  else: "ring-gray-300 focus:ring-indigo-600"
                ),
            placeholder: gettext("Your message here..."),
            value: f[:content].value,
            type: :text,
            required: true,
            autocomplete: :content,
            "phx-debounce": "200"
          ) %>

          <%= hidden_input(f, :sender_id, value: @sender.id) %>
          <%= hidden_input(f, :receiver_id, value: @receiver.id) %>
        </div>

        <div class="h-[50px] w-[10%] flex justify-center items-center">
          <%= submit(
          class:
            "flex w-full justify-center rounded-md bg-indigo-600 h-[100%] items-center dark:bg-indigo-500 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
              unless(@form.source.valid? == false,
                do: "",
                else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
              ),
          disabled: @form.source.valid? == false
        ) do %>
            <.send_message_from_dashboard_button />
          <% end %>
        </div>
      </.form>
    </div>
    """
  end

  def send_message_from_dashboard_button(assigns) do
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

  def potential_users_intersecting_green_flags(assigns) do
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
    </div>
    """
  end
end
