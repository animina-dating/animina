defmodule AniminaWeb.DashboardComponents do
  @moduledoc """
  Provides Dashboard UI components.
  """
  use Phoenix.Component
  alias Animina.Markdown
  import AniminaWeb.Gettext
  import AniminaWeb.CoreComponents
  alias AshPhoenix.Form
  import Phoenix.HTML.Form

  def dashboard_card_component(assigns) do
    ~H"""
    <div class="flex flex-col rounded-md gap-4 cursor-pointer h-[300px] bg-gray-100 dark:bg-gray-800 p-2">
      <h1 class="p-2 rounded-md dark:bg-gray-700 bg-white text-black  dark:text-white text-center">
        <%= @title %>
      </h1>
    </div>
    """
  end

  def dashboard_card_like_component(assigns) do
    ~H"""
    <div class="flex flex-col rounded-md gap-3 cursor-pointer h-[300px] bg-gray-100 dark:bg-gray-800 p-2">
      <h1 class="p-2 rounded-md dark:bg-gray-700 bg-white text-black  font-semibod text-xl  dark:text-white text-center">
        <%= @title %>
      </h1>

      <div class="flex flex-col gap-3">
        <div class="flex flex-col dark:text-white  text-black gap-1">
          <p>
            <%= gettext("You have received a total of") %> <%= @total_likes_received_by_user %> <%= gettext(
              "likes"
            ) %>
          </p>

          <p :if={@likes_received_by_user_in_seven_days > 0} class="italic">
            <%= @likes_received_by_user_in_seven_days %> <%= gettext("in the last 7 days.") %>
          </p>
        </div>

        <div class="flex flex-col dark:text-white  text-black gap-1">
          <p>
            <%= gettext("You liked") %>
            <.link navigate="/my/bookmarks/liked" class="text-blue-500">
              <%= @profiles_liked_by_user %>
              <span :if={@profiles_liked_by_user == 1}><%= gettext("profile") %></span>
              <span :if={@profiles_liked_by_user != 1}><%= gettext("profiles") %></span>
            </.link>
          </p>
        </div>
      </div>
    </div>
    """
  end

  def dashboard_card_chat_component(assigns) do
    ~H"""
    <div class="flex flex-col rounded-md gap-3 cursor-pointer h-[300px] bg-gray-100 dark:bg-gray-800 p-2">
      <h1 class="p-2 rounded-md dark:bg-gray-700 bg-white text-black  font-semibod text-xl  dark:text-white text-center">
        <%= @title %>
      </h1>

      <div class="flex flex-col  gap-3">
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
    </div>
    """
  end

  defp unread_message(assigns) do
    ~H"""
    <div>
      <div class="flex justify-start gap-4  item-start text-black">
        <.sender_user_image user={@sender} current_user={@receiver} />
        <div class="justify-start flex items-start flex-col">
          <p class="dark:text-white text-xs">
            <%= @sender.username %>
          </p>
          <div class=" w-[250px]  text-sm  dark:bg-white bg-gray-300 text-black   flex flex-col gap-2 justify-between px-1 items-end rounded-md">
            <p>
              <%= Markdown.format(@content) %>
            </p>

            <div class="text-xs  italic  flex justify-end">
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
          class="p-1 text-xs dark:bg-gray-800 bg-gray-200 text-black absolute bottom-2 right-4 rounded-md dark:text-white"
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
    <div class="flex flex-col justify-center items-center h-[100%] text-white  gap-4">
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
    <div class=" w-[100%] ">
      <.form
        :let={f}
        for={@form}
        phx-change="validate"
        phx-submit="submit"
        class="w-[100%] flex justify-between items-end"
      >
        <div phx-feedback-for={f[:content].name} class="md:w-[83%] w-[80%]">
          <%= textarea(
            f,
            :content,
            class:
              "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                unless(get_field_errors(f[:content], :content) == [],
                  do: "ring-red-600 focus:ring-red-600",
                  else: "ring-gray-300 focus:ring-indigo-600"
                ),
            placeholder: gettext("Your message here..."),
            value: f[:content].value,
            type: :text,
            required: true,
            rows: 2,
            autocomplete: :content,
            "phx-debounce": "200"
          ) %>

          <%= hidden_input(f, :sender_id, value: @sender.id) %>
          <%= hidden_input(f, :receiver_id, value: @receiver.id) %>
        </div>

        <div class="md:w-[15%] w-[18%] flex justify-center items-center">
          <%= submit(
          class:
            "flex w-full justify-center rounded-md bg-indigo-600 dark:bg-indigo-500 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
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
end
