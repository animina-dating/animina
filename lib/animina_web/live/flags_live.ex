defmodule AniminaWeb.FlagsLive do
  require Ash.Query
  use AniminaWeb, :live_view

  alias Animina.Accounts.User
  alias Animina.GenServers.ProfileViewCredits
  alias Animina.Traits
  alias Animina.Traits.UserFlags
  alias AniminaWeb.SelectFlagsComponent
  alias Phoenix.LiveView.AsyncResult
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
      |> assign(user_flags: [])
      |> assign(language: language)
      |> assign(color: :white)
      |> assign(categories: AsyncResult.loading())
      |> stream(:categories, [])
      |> start_async(:fetch_categories, fn -> fetch_categories() end)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :white, _params) do
    update_last_registration_page_visited(socket.assigns.current_user, "/my/flags/white")

    current_user = socket.assigns.current_user

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
    |> assign(
      :opposite_color_flags_selected,
      filter_flags(socket.assigns.current_user, :white)
      |> Enum.map(fn trait -> trait.flag.id end)
    )
    |> start_async(:filter_flags, fn -> filter_flags(current_user, :white) end)
  end

  defp apply_action(socket, :red, _params) do
    update_last_registration_page_visited(socket.assigns.current_user, "/my/flags/red")

    current_user = socket.assigns.current_user

    socket
    |> assign(page_title: gettext("Select your red flags"))
    |> assign(color: :red)
    |> assign(navigate_to: "/my/about-me")
    |> assign(title: gettext("Choose Your Red Flags"))
    |> assign(
      info_text:
        gettext(
          "Choose up to %{number_of_flags} flags that you don't want to have in a partner. The ones selected first are the most important.",
          number_of_flags: @max_flags
        )
    )
    |> assign(
      :opposite_color_flags_selected,
      filter_flags(socket.assigns.current_user, :green)
      |> Enum.map(fn trait -> trait.flag.id end)
    )
    |> start_async(:filter_flags, fn -> filter_flags(current_user, :red) end)
  end

  defp apply_action(socket, :green, _params) do
    update_last_registration_page_visited(socket.assigns.current_user, "/my/flags/green")
    current_user = socket.assigns.current_user

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
    |> assign(
      :opposite_color_flags_selected,
      filter_flags(socket.assigns.current_user, :red)
      |> Enum.map(fn trait -> trait.flag.id end)
    )
    |> start_async(:filter_flags, fn -> filter_flags(current_user, :green) end)
  end

  defp update_last_registration_page_visited(user, page) do
    {:ok, _} =
      User.update_last_registration_page_visited(user, %{last_registration_page_visited: page})
  end

  @impl true
  def handle_async(:filter_flags, {:ok, flags}, socket) do
    flags = Enum.map(flags, fn trait -> trait.flag.id end)

    {:noreply, socket |> assign(user_flags: flags) |> assign(selected: Enum.count(flags))}
  end

  @impl true
  def handle_async(:filter_flags, {:exit, _reason}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_async(:fetch_categories, {:ok, fetched_categories}, socket) do
    %{categories: categories} = socket.assigns

    {:noreply,
     socket
     |> assign(
       :categories,
       AsyncResult.ok(categories, Enum.map(fetched_categories, fn category -> category.id end))
     )
     |> stream(:categories, fetched_categories)}
  end

  @impl true
  def handle_async(:fetch_categories, {:exit, reason}, socket) do
    %{categories: categories} = socket.assigns
    {:noreply, assign(socket, :categories, AsyncResult.failed(categories, {:exit, reason}))}
  end

  @impl true
  def handle_event("add_flags", _params, socket) do
    interests =
      Enum.with_index(socket.assigns.user_flags, fn element, index -> {index, element} end)
      |> Enum.map(fn {index, flag_id} ->
        %{
          flag_id: flag_id,
          user_id: socket.assigns.current_user.id,
          color: socket.assigns.color,
          position: index + 1
        }
      end)

    socket.assigns.current_user.traits
    |> Enum.filter(fn x -> x.color == socket.assigns.color end)
    |> Enum.each(fn x -> UserFlags.destroy(x) end)

    bulk_result =
      Traits.bulk_create(interests, Traits.UserFlags, :create, stop_on_error?: true)

    successful_socket =
      socket
      |> assign(:user_flags, [])
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
  def handle_info({:user, current_user}, socket) do
    flags = current_user.flags |> Enum.map(fn x -> x.id end)

    {:noreply,
     socket
     |> assign(current_user: current_user)
     |> assign(
       :opposite_color_flags_selected,
       filter_flags(current_user, socket.assigns.color)
       |> Enum.map(fn trait -> trait.flag.id end)
     )
     |> assign(
       :user_flags,
       flags
     )
     |> assign(
       :selected,
       Enum.count(flags)
     )}
  end

  @impl true
  def handle_info({:flag_selected, flag_id}, socket) do
    selected = socket.assigns.selected + 1
    can_select = selected < socket.assigns.max_selected
    user_flags = List.insert_at(socket.assigns.user_flags, -1, flag_id)

    for category_id <- socket.assigns.categories.result do
      send_update(SelectFlagsComponent,
        id: "flags_#{category_id}",
        can_select: can_select,
        user_flags: user_flags
      )
    end

    {:noreply,
     socket
     |> assign(:user_flags, user_flags)
     |> assign(:selected, selected)}
  end

  @impl true
  def handle_info({:flag_unselected, flag_id}, socket) do
    selected = max(socket.assigns.selected - 1, 0)
    can_select = selected < socket.assigns.max_selected
    user_flags = List.delete(socket.assigns.user_flags, flag_id)

    for category_id <- socket.assigns.categories.result do
      send_update(SelectFlagsComponent,
        id: "flags_#{category_id}",
        can_select: can_select,
        user_flags: user_flags
      )
    end

    {:noreply,
     socket
     |> assign(:user_flags, user_flags)
     |> assign(:selected, selected)}
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
    |> Traits.read!()
  end

  defp filter_flags(current_user, color) do
    current_user.traits
    |> Enum.filter(fn trait ->
      trait.color == color
    end)
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

      <.async_result :let={_categories} assign={@categories}>
        <:loading>
          <div class="pt-4 space-y-4">
            <.flag_card_loading />
            <.flag_card_loading />
            <.flag_card_loading />
            <.flag_card_loading />
          </div>
        </:loading>
        <:failed :let={_failure}><%= gettext("There was an error loading flags") %></:failed>

        <div id="stream_categories" phx-update="stream">
          <div :for={{dom_id, category} <- @streams.categories} id={"#{dom_id}"}>
            <.live_component
              module={SelectFlagsComponent}
              id={"flags_#{category.id}"}
              category={category}
              language={@language}
              can_select={@selected < @max_selected}
              user_flags={@user_flags}
              opposite_color_flags_selected={@opposite_color_flags_selected}
              color={@color}
            />
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
      </.async_result>
    </div>
    """
  end
end
