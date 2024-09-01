defmodule AniminaWeb.FlagsLive do
  require Ash.Query
  use AniminaWeb, :live_view

  alias Animina.Accounts.User
  alias Animina.GenServers.ProfileViewCredits
  alias Animina.Narratives.Story
  alias Animina.Traits
  alias Animina.Traits.UserFlags
  alias Phoenix.PubSub

  @max_flags Application.compile_env(:animina, AniminaWeb.FlagsLive)[:max_selected]

  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )
    end

    socket =
      socket
      |> assign(max_selected: @max_flags)
      |> assign(selected: 0)
      |> assign(active_tab: :home)
      |> assign(selected_flags: %{})
      |> assign(
        flags_for_user_with_current_color:
          filter_flags_and_return_map(socket.assigns.current_user, socket.assigns.live_action)
      )
      |> assign(can_select: true)
      |> assign(language: language)
      |> assign(categories: fetch_categories())
      |> assign(
        :opposite_color_flags_selected_already,
        get_opposite_color_flags_selected_already(
          socket.assigns.current_user,
          socket.assigns.live_action
        )
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :white, _params) do
    update_last_registration_page_visited(socket.assigns.current_user, "/my/flags/white")

    socket
    |> assign(page_title: gettext("Select your own flags"))
    |> assign(color: :white)
    |> assign(navigate_to: "/my/flags/green")
    |> assign(title: gettext("Choose Your Own Flags"))
    |> assign(
      info_text:
        gettext(
          "We use flags to match people. You can select red and green flags later. But first tell us something about yourself and select up to %{number_of_flags} flags that describe yourself. The ones selected first are the most important.",
          number_of_flags: @max_flags
        )
    )
  end

  defp apply_action(socket, :red, _params) do
    update_last_registration_page_visited(socket.assigns.current_user, "/my/flags/red")

    current_user = socket.assigns.current_user

    socket
    |> assign(page_title: gettext("Select your red flags"))
    |> assign(color: :red)
    |> assign(navigate_to: redirect_url(current_user))
    |> assign(title: gettext("Choose Your Red Flags"))
    |> assign(
      info_text:
        gettext(
          "Choose up to %{number_of_flags} flags that you don't want to have in a partner. The ones selected first are the most important.",
          number_of_flags: @max_flags
        )
    )
  end

  defp apply_action(socket, :green, _params) do
    update_last_registration_page_visited(socket.assigns.current_user, "/my/flags/green")

    socket
    |> assign(page_title: gettext("Select your green flags"))
    |> assign(color: :green)
    |> assign(navigate_to: "/my/flags/red")
    |> assign(title: gettext("Choose Your Green Flags"))
    |> assign(
      info_text:
        gettext(
          "Choose up to %{number_of_flags} flags that you want your partner to have. The ones selected first are the most important.",
          number_of_flags: @max_flags
        )
    )
  end

  defp update_last_registration_page_visited(user, page) do
    {:ok, _} =
      User.update_last_registration_page_visited(user, %{last_registration_page_visited: page})
  end

  @impl true
  def handle_event("add_flags", _params, socket) do
    interests =
      Enum.with_index(socket.assigns.flags_for_user_with_current_color, fn element, index ->
        {index, element}
      end)
      |> Enum.map(fn {index, flag_id} ->
        %{
          flag_id: flag_id,
          user_id: socket.assigns.current_user.id,
          color: socket.assigns.color,
          position: index + 1
        }
      end)

    UserFlags.by_user_id!(socket.assigns.current_user.id)
    |> Enum.filter(fn x -> x.color == socket.assigns.color end)
    |> Enum.each(fn x -> UserFlags.destroy(x) end)

    bulk_result =
      Ash.bulk_create(interests, Traits.UserFlags, :create, stop_on_error?: true)

    successful_socket =
      socket
      |> assign(:flags_for_user_with_current_color, [])
      |> assign(:selected, 0)
      |> push_navigate(to: socket.assigns.navigate_to)

    case bulk_result.status do
      :error ->
        {:noreply, socket |> put_flash(:error, gettext("Something went wrong adding your flags"))}

      _ ->
        case socket.assigns.selected do
          0 ->
            {:noreply, successful_socket}

          _ ->
            {:noreply, successful_socket}
        end
    end
  end

  @impl true
  def handle_event(
        "select_flag",
        %{
          "flag" => _flag,
          "flagid" => flag_id
        },
        socket
      ) do
    socket =
      case Enum.member?(socket.assigns.flags_for_user_with_current_color, flag_id) do
        false ->
          flags_for_user_with_current_color =
            List.insert_at(socket.assigns.flags_for_user_with_current_color, -1, flag_id)

          selected = Enum.count(flags_for_user_with_current_color)

          socket
          |> assign(:flags_for_user_with_current_color, flags_for_user_with_current_color)
          |> assign(:selected, selected)

        true ->
          flags_for_user_with_current_color =
            List.delete(socket.assigns.flags_for_user_with_current_color, flag_id)

          selected = Enum.count(flags_for_user_with_current_color)

          socket
          |> assign(:flags_for_user_with_current_color, flags_for_user_with_current_color)
          |> assign(:selected, selected)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:user, current_user}, socket) do
    flags = filter_flags(current_user, socket.assigns.color)

    if current_user.state in user_states_to_be_auto_logged_out() do
      {:noreply,
       socket
       |> push_navigate(to: "/auth/user/sign-out?auto_log_out=#{current_user.state}")}
    else
      {:noreply,
       socket
       |> assign(current_user: current_user)
       |> assign(
         :opposite_color_flags_selected,
         filter_flags(current_user, socket.assigns.color)
         |> Enum.map(fn trait -> trait.flag.id end)
       )
       |> assign(
         :color_flags_for_user,
         flags
       )
       |> assign(
         :selected,
         Enum.count(flags)
       )}
    end
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  @impl true
  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
  end

  defp fetch_categories do
    Traits.Category
    |> Ash.Query.for_read(:read)
    |> Ash.read!()
  end

  defp user_states_to_be_auto_logged_out do
    [
      :under_investigation,
      :banned,
      :archived
    ]
  end

  defp filter_flags(current_user, color) do
    case UserFlags.by_user_id(current_user.id) do
      {:ok, traits} ->
        traits
        |> Enum.filter(fn trait ->
          trait.color == color
        end)

      _ ->
        []
    end
  end

  defp filter_flags_and_return_map(current_user, color) do
    filter_flags(current_user, color)
    |> Enum.map(fn trait -> trait.flag.id end)
  end

  defp get_opposite_color_flags_selected_already(current_user, :green) do
    filter_flags_and_return_map(current_user, :red)
  end

  defp get_opposite_color_flags_selected_already(current_user, :red) do
    filter_flags_and_return_map(current_user, :green)
  end

  defp get_opposite_color_flags_selected_already(_current_user, _) do
    []
  end

  defp user_has_an_about_me_story?(user) do
    case get_stories_for_a_user(user) do
      [] ->
        false

      stories ->
        Enum.any?(stories, fn story ->
          story.headline.subject == "About me"
        end)
    end
  end

  defp get_stories_for_a_user(user) do
    {:ok, stories} = Story.by_user_id(user.id)
    stories
  end

  defp redirect_url(user) do
    if user_has_an_about_me_story?(user) do
      "/#{user.username}"
    else
      "/my/about-me"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative px-5 space-y-4">
      <div class="flex items-center justify-between">
        <h2 class="font-bold dark:text-white md:text-xl"><%= @title %></h2>

        <div>
          <button
            phx-click="add_flags"
            class={
              "flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@selected == 0,
                  do: " ",
                  else: "opacity-40  hover:bg-blue-500 active:bg-blue-500"
                )}
          >
            <%= if @selected == 0 do %>
              <%= gettext("Proceed ") %>
            <% else %>
              <%= gettext("Save flags") %>
            <% end %>
          </button>
        </div>
      </div>

      <p class="dark:text-white"><%= @info_text %></p>

      <div :for={category <- @categories}>
        <div class="py-4 space-y-2">
          <h3 class="font-semibold text-gray-800 dark:text-white truncate">
            <%= get_translation(category.category_translations, @language) %>
          </h3>

          <ol class="flex flex-wrap gap-2 w-full">
            <li :for={flag <- category.flags}>
              <div
                phx-value-flag={flag.name}
                phx-value-flagid={flag.id}
                aria-label="button"
                phx-click={
                  if(
                    get_flag_styling(
                      @selected < @max_selected,
                      @flags_for_user_with_current_color,
                      flag.id,
                      @opposite_color_flags_selected_already,
                      flag,
                      @color
                    ) != "cursor-not-allowed bg-gray-200 dark:bg-gray-100",
                    do: "select_flag",
                    else: nil
                  )
                }
                class={"rounded-full flex gap-2 items-center  px-3 py-1.5 text-sm font-semibold leading-6  focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2  #{get_flag_styling(
              @selected < @max_selected,
              @flags_for_user_with_current_color,
              flag.id,
              @opposite_color_flags_selected_already,
              flag,
              @color

            )} "

            }
              >
                <span :if={flag.emoji} class="pr-1.5"><%= flag.emoji %></span>
                <%= get_translation(flag.flag_translations, @language) %>

                <span
                  :if={Enum.member?(@flags_for_user_with_current_color, flag.id)}
                  class={"inline-flex items-center justify-center w-4 h-4 ms-2 text-xs font-semibold rounded-full " <> get_position_colors(@color)}
                >
                  <%= get_flag_index(@flags_for_user_with_current_color, flag.id) + 1 %>
                </span>

                <%= if Enum.member?(@opposite_color_flags_selected_already, flag.id) do %>
                  <p class={get_dot_for_selected_opposite_selected_flag(@color)} />
                <% end %>
              </div>
            </li>
          </ol>
        </div>
      </div>

      <button
        phx-click="add_flags"
        class={
              "flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@selected == 0,
                  do: " ",
                  else: "opacity-40  hover:bg-blue-500 active:bg-blue-500"
                )}
      >
        <%= if @selected == 0 do %>
          <%= gettext("Proceed without selecting a flag") %>
        <% else %>
          <%= gettext("Save flags") %>
        <% end %>
      </button>
    </div>
    """
  end

  defp get_translation(translations, language) when translations != [] do
    language = String.split(language, "-") |> Enum.at(0)

    translation =
      Enum.find(translations, nil, fn translation -> translation.language == language end)

    translation.name
  end

  defp get_translation(_, _) do
    nil
  end

  defp get_flag_styling(
         can_select,
         color_flags_for_user,
         flag_id,
         opposite_color_flags_selected,
         flag,
         color
       ) do
    if (can_select && !Enum.member?(opposite_color_flags_selected, flag_id)) ||
         (can_select == false && Enum.member?(color_flags_for_user, flag.id) &&
            !Enum.member?(opposite_color_flags_selected, flag_id)) do
      "cursor-pointer #{if Enum.member?(color_flags_for_user, flag.id), do: "#{get_active_button_colors(color)} text-white shadow-sm", else: "#{get_inactive_button_colors(color)} shadow-none"}"
    else
      get_styling_if_flag_is_white(color, color_flags_for_user, flag)
    end
  end

  defp get_styling_if_flag_is_white(:white, color_flags_for_user, flag) do
    "#{if Enum.member?(color_flags_for_user, flag.id), do: "#{get_active_button_colors(:white)} text-white shadow-sm", else: "#{get_inactive_button_colors(:white)} shadow-none"}"
  end

  defp get_styling_if_flag_is_white(_color, _selected_flags, _flag) do
    "cursor-not-allowed bg-gray-200 dark:bg-gray-100"
  end

  defp get_flag_index(flags, flag_id) do
    case Enum.find_index(flags, fn id -> id == flag_id end) do
      nil -> length(flags) + 1
      index -> index
    end
  end

  defp get_active_button_colors(color) do
    cond do
      color == :green -> "hover:bg-green-500  bg-green-600 focus-visible:outline-green-600"
      color == :red -> "hover:bg-rose-500  bg-rose-600 focus-visible:outline-rose-600"
      true -> "hover:bg-indigo-500  bg-indigo-600 focus-visible:outline-indigo-600"
    end
  end

  defp get_dot_for_selected_opposite_selected_flag(color) do
    cond do
      color == :green -> "w-3 h-3 bg-red-500 rounded-full"
      color == :red -> "w-3 h-3 bg-green-500 rounded-full"
      true -> ""
    end
  end

  defp get_inactive_button_colors(color) do
    cond do
      color == :green ->
        "hover:bg-green-50 bg-green-100 focus-visible:outline-green-100 text-green-600"

      color == :red ->
        "hover:bg-red-50 bg-red-100 focus-visible:outline-red-100 text-red-600"

      true ->
        "hover:bg-indigo-50 bg-indigo-100 focus-visible:outline-indigo-100 text-indigo-600"
    end
  end

  defp get_position_colors(color) do
    cond do
      color == :green -> "text-green-600 bg-green-200"
      color == :red -> "text-rose-600 bg-rose-200"
      true -> "text-indigo-600 bg-indigo-200"
    end
  end

  def filter_flags(_) do
    :white
  end
end
