defmodule AniminaWeb.FlagsLive do
  use AniminaWeb, :live_view

  alias Animina.Traits
  alias AniminaWeb.Registration
  alias AniminaWeb.SelectFlagsComponent
  alias Phoenix.LiveView.AsyncResult

  @impl true
  def mount(_params, %{"language" => language} = session, socket) do
    current_user =
      case Registration.get_current_user(session) do
        nil ->
          redirect(socket, to: "/")

        user ->
          user
      end

    flags_config = Application.get_env(:animina, AniminaWeb.FlagsLive)

    socket =
      socket
      |> assign(current_user: current_user)
      |> assign(max_selected: flags_config[:max_selected])
      |> assign(selected: 0)
      |> assign(active_tab: :home)
      |> assign(selected_flags: [])
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
    socket
    |> assign(page_title: gettext("Select your white flags"))
    |> assign(color: :white)
    |> assign(navigate_to: "/registration/green-flags")
    |> assign(title: gettext("Choose your white flags"))
  end

  defp apply_action(socket, :red, _params) do
    socket
    |> assign(page_title: gettext("Select your red flags"))
    |> assign(color: :red)
    |> assign(navigate_to: "/registration/red-flags")
    |> assign(title: gettext("Choose your red flags"))
  end

  defp apply_action(socket, :green, _params) do
    socket
    |> assign(page_title: gettext("Select your green flags"))
    |> assign(color: :green)
    |> assign(navigate_to: "/registration/red-flags")
    |> assign(title: gettext("Choose your green flags"))
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
  def handle_info({:flag_selected, flag_id}, socket) do
    selected = socket.assigns.selected + 1
    can_select = selected < socket.assigns.max_selected
    selected_flags = List.insert_at(socket.assigns.selected_flags, -1, flag_id)

    for category_id <- socket.assigns.categories.result do
      send_update(SelectFlagsComponent,
        id: "flags_#{category_id}",
        can_select: can_select,
        user_flags: selected_flags
      )
    end

    {:noreply,
     socket
     |> assign(:selected_flags, selected_flags)
     |> assign(:selected, selected)}
  end

  @impl true
  def handle_info({:flag_unselected, flag_id}, socket) do
    selected = max(socket.assigns.selected - 1, 0)
    can_select = selected < socket.assigns.max_selected
    selected_flags = List.delete(socket.assigns.selected_flags, flag_id)

    for category_id <- socket.assigns.categories.result do
      send_update(SelectFlagsComponent,
        id: "flags_#{category_id}",
        can_select: can_select,
        user_flags: selected_flags
      )
    end

    {:noreply,
     socket
     |> assign(:selected_flags, selected_flags)
     |> assign(:selected, selected)}
  end

  @impl true
  def handle_event("add_flags", _params, socket) do
    interests =
      Enum.with_index(socket.assigns.selected_flags, fn element, index -> {index, element} end)
      |> Enum.map(fn {index, flag_id} ->
        %{
          flag_id: flag_id,
          user_id: socket.assigns.current_user.id,
          coloor: socket.assigns.color,
          position: index + 1
        }
      end)

    bulk_result =
      Traits.bulk_create(interests, Traits.UserFlags, :create, stop_on_error?: true)

    case bulk_result.status do
      :error ->
        {:noreply, socket |> put_flash(:error, gettext("Something went wrong adding your flags"))}

      _ ->
        {:noreply,
         socket
         |> assign(selected: 0)
         |> assign(selected_flags: [])
         |> put_flash(:info, gettext("Your flags have been added succesfully"))
         |> push_navigate(to: socket.assigns.navigate_to)}
    end
  end

  defp fetch_categories do
    Traits.Category
    |> Ash.Query.for_read(:read)
    |> Traits.read!()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8 px-5">
      <.notification_box
        title={gettext("Hello %{name}!", name: @current_user.name)}
        message={gettext("To complete your profile choose your flags")}
      />

      <h2 class="font-bold text-xl"><%= @title %></h2>

      <.async_result :let={_categories} assign={@categories}>
        <:loading><%= gettext("Loading interests...") %></:loading>
        <:failed :let={_failure}><%= gettext("There was an error loading interests") %></:failed>

        <div id="stream_categories" phx-update="stream">
          <div :for={{dom_id, category} <- @streams.categories} id={"#{dom_id}"}>
            <.live_component
              module={SelectFlagsComponent}
              id={"flags_#{category.id}"}
              category={category}
              language={@language}
              can_select={@selected < @max_selected}
              user_flags={@selected_flags}
              color={@color}
            />
          </div>
        </div>

        <div class="pb-8">
          <button
            phx-click="add_flags"
            class={
              "flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@selected == 0,
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                )}
            disabled={@selected == 0}
          >
            <%= gettext("Add flags") %>
          </button>
        </div>
      </.async_result>
    </div>
    """
  end
end
