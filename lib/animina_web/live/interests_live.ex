defmodule AniminaWeb.InterestsLive do
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

    socket =
      socket
      |> assign(current_user: current_user)
      |> assign(max_selected: 20)
      |> assign(selected: 0)
      |> assign(active_tab: :home)
      |> assign(selected_flags: [])
      |> assign(language: language)
      |> assign(page_title: gettext("Select your interests"))
      |> assign(categories: AsyncResult.loading())
      |> stream(:categories, [])
      |> start_async(:fetch_categories, fn -> fetch_categories() end)

    {:ok, socket}
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

    for category_id <- socket.assigns.categories.result do
      send_update(SelectFlagsComponent, id: "flags_#{category_id}", can_select: can_select)
    end

    {:noreply,
     socket
     |> assign(:selected_flags, List.insert_at(socket.assigns.selected_flags, -1, flag_id))
     |> assign(:selected, selected)}
  end

  @impl true
  def handle_info({:flag_unselected, flag_id}, socket) do
    selected = max(socket.assigns.selected - 1, 0)
    can_select = selected < socket.assigns.max_selected

    for category_id <- socket.assigns.categories.result do
      send_update(SelectFlagsComponent, id: "flags_#{category_id}", can_select: can_select)
    end

    {:noreply,
     socket
     |> assign(:selected_flags, List.delete(socket.assigns.selected_flags, flag_id))
     |> assign(:selected, selected)}
  end

  @impl true
  def handle_event("add_interests", _params, socket) do
    interests =
      Enum.map(socket.assigns.selected_flags, fn flag_id ->
        %{
          flag_id: flag_id,
          user_id: socket.assigns.current_user.id
        }
      end)

    bulk_result =
      Traits.bulk_create(interests, Traits.UserInterests, :create, stop_on_error?: true)

    case bulk_result.status do
      :error ->
        {:noreply,
         socket |> put_flash(:error, gettext("Something went wrong adding your interests"))}

      _ ->
        {:noreply,
         socket
         |> assign(selected: 0)
         |> assign(selected_flags: [])
         |> put_flash(:info, gettext("Your interests have been added succesfully"))
         |> push_navigate(to: "/registration/interests")}
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
        message={gettext("To complete your profile choose topics you are interested in")}
      />

      <h2 class="font-bold text-xl"><%= gettext("Choose your interests") %></h2>

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
            />
          </div>
        </div>

        <div class="pb-8">
          <button
            phx-click="add_interests"
            class={
              "flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@selected == 0,
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                )}
            disabled={@selected == 0}
          >
            <%= gettext("Add interests") %>
          </button>
        </div>
      </.async_result>
    </div>
    """
  end
end
