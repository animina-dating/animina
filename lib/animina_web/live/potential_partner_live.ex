defmodule AniminaWeb.PotentialPartnerLive do
  use AniminaWeb, :live_view
  require Ash.Query

  alias Animina.Accounts.Credit
  alias Animina.Accounts.User
  alias Animina.GeoData.City
  alias AshPhoenix.Form

  @impl true
  def mount(_params, _session, socket) do
    add_registration_bonus(socket, socket.assigns.current_user)

    user =
      if socket.assigns.current_user.maximum_partner_height == nil do
        socket.assigns.current_user
        |> Map.put(
          :maximum_partner_height,
          cal_maximum_partner_height(socket.assigns.current_user)
        )
        |> Map.put(
          :minimum_partner_height,
          cal_minimum_partner_height(socket.assigns.current_user)
        )
        |> Map.put(:maximum_partner_age, cal_maximum_partner_age(socket.assigns.current_user))
        |> Map.put(:minimum_partner_age, cal_minimum_partner_age(socket.assigns.current_user))
        |> Map.put(:partner_gender, guess_partner_gender(socket.assigns.current_user))
        |> Map.put(:search_range, 50)
      else
        socket.assigns.current_user
      end

    socket =
      socket
      |> assign(update_form: AshPhoenix.Form.for_update(user, :update) |> to_form())
      |> assign(city_name: City.by_zip_code!(user.zip_code))
      |> assign(current_user: user)
      |> assign(active_tab: :home)
      |> assign(page_title: gettext("Preferences for your future partner"))

    {:ok, socket}
  end

  defp add_registration_bonus(socket, user) do
    if !connected?(socket) && is_nil(user) == false do
      # Make sure that a user gets one but only one registration bonus.
      case Credit
           |> Ash.Query.filter(user_id: user.id)
           |> Ash.Query.filter(subject: "Registration bonus")
           |> Animina.Accounts.read!() do
        [] ->
          Credit.create!(%{
            user_id: user.id,
            points: 100,
            subject: "Registration bonus"
          })

        _ ->
          nil
      end
    end
  end

  @impl true
  def handle_event("validate_user", %{"form" => form_params}, socket) do
    form = Form.validate(socket.assigns.update_form, form_params, errors: true)

    {:noreply, socket |> assign(update_form: form)}
  end

  @impl true
  def handle_event("update_user", %{"form" => form_params}, socket) do
    form = Form.validate(socket.assigns.update_form, form_params)

    case Form.errors(form) do
      [] ->
        current_user =
          User.by_id!(socket.assigns.current_user.id)
          |> User.update!(form_params)

        {:noreply,
         socket
         |> assign(current_user: current_user)
         |> push_navigate(to: "/profile/profile-photo")}

      _ ->
        {:noreply, assign(socket, update_form: form)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-5 dark:text-white px-5">
      <h2 class="font-bold  text-xl"><%= gettext("Criteria for your new partner") %></h2>
      <p>
        <%= gettext("We will use this information to find suitable partners for you.") %>
      </p>
      <.form
        :let={f}
        for={@update_form}
        phx-submit="update_user"
        phx-change="validate_user"
        class="space-y-6"
      >
        <div>
          <div class="flex items-center justify-between">
            <label for="user_partner_gender" class="block text-sm font-medium leading-6 dark:text-white text-gray-900">
              <%= gettext("Gender") %>
            </label>
          </div>
          <div class="mt-2" phx-no-format>

        <%
          item_code = "male"
          item_title = gettext("Male")
        %>
        <div class="flex items-center mb-4">
          <%= radio_button(f, :partner_gender, item_code,
            id: "partner_gender_" <> item_code,
            class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500",
            checked: true
          ) %>
          <%= label(f, :partner_gender, item_title,
            for: "partner_gender_" <> item_code,
            class: "ml-3 block text-sm font-medium dark:text-white text-gray-700"
          ) %>
        </div>

        <%
          item_code = "female"
          item_title = gettext("Female")
        %>
        <div class="flex items-center mb-4">
          <%= radio_button(f, :partner_gender, item_code,
            id: "partner_gender_" <> item_code,
            class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
          ) %>
          <%= label(f, :partner_gender, item_title,
            for: "partner_gender_" <> item_code,
            class: "ml-3 block text-sm font-medium dark:text-white text-gray-700"
          ) %>
        </div>

        <%
          item_code = "diverse"
          item_title = gettext("Diverse")
        %>
        <div class="flex items-center mb-4">
          <%= radio_button(f, :partner_gender, item_code,
            id: "partner_gender_" <> item_code,
            class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
          ) %>
          <%= label(f, :partner_gender, item_title,
            for: "partner_gender_" <> item_code,
            class: "ml-3 block text-sm dark:text-white font-medium text-gray-700"
          ) %>
        </div>
      </div>
        </div>
        <div>
          <label
            for="form_minimum_partner_height"
            class="block text-sm font-medium leading-6 dark:text-white text-gray-900"
          >
            <%= gettext("Minimum height") %>
          </label>
          <div phx-feedback-for={f[:minimum_partner_height].name} class="mt-2">
            <%= select(f, :minimum_partner_height, Enum.map(140..210, &{"#{&1} cm", &1}),
              prompt: gettext("doesn't matter"),
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset focus:ring-2 dark:bg-gray-700 dark:text-white focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
                  unless(get_field_errors(f[:minimum_partner_height], :minimum_partner_height) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              autofocus: true
            ) %>

            <.error :for={
              msg <- get_field_errors(f[:minimum_partner_height], :minimum_partner_height)
            }>
              <%= gettext("Minimum height") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <label
            for="form_maximum_partner_height"
            class="block text-sm font-medium leading-6 dark:text-white text-gray-900"
          >
            <%= gettext("Maximum height") %>
          </label>
          <div phx-feedback-for={f[:maximum_partner_height].name} class="mt-2">
            <%= select(f, :maximum_partner_height, Enum.map(140..210, &{"#{&1} cm", &1}),
              prompt: gettext("doesn't matter"),
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset focus:ring-2 focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
                  unless(get_field_errors(f[:maximum_partner_height], :maximum_partner_height) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  )
            ) %>

            <.error :for={
              msg <- get_field_errors(f[:maximum_partner_height], :maximum_partner_height)
            }>
              <%= gettext("Maximum height") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <label
            for="form_minimum_partner_age"
            class="block text-sm font-medium leading-6 dark:text-white text-gray-900"
          >
            <%= gettext("Minimum age") %>
          </label>
          <div phx-feedback-for={f[:minimum_partner_age].name} class="mt-2">
            <%= select(f, :minimum_partner_age, Enum.map(18..110, &{&1, &1}),
              prompt: gettext("doesn't matter"),
              value: f[:minimum_partner_age].value,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset focus:ring-2 focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
                  unless(get_field_errors(f[:minimum_partner_age], :minimum_partner_age) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  )
            ) %>

            <.error :for={msg <- get_field_errors(f[:minimum_partner_age], :minimum_partner_age)}>
              <%= gettext("Minimum age") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <label
            for="form_maximum_partner_age"
            class="block text-sm font-medium leading-6 dark:text-white text-gray-900"
          >
            <%= gettext("Maximum age") %>
          </label>
          <div phx-feedback-for={f[:maximum_partner_age].name} class="mt-2">
            <%= select(f, :maximum_partner_age, Enum.map(18..110, &{&1, &1}),
              prompt: gettext("doesn't matter"),
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset focus:ring-2 focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
                  unless(get_field_errors(f[:maximum_partner_age], :maximum_partner_age) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  )
            ) %>

            <.error :for={msg <- get_field_errors(f[:maximum_partner_age], :maximum_partner_age)}>
              <%= gettext("Maximum age") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <label for="form_search_range" class="block text-sm font-medium dark:text-white leading-6 text-gray-900">
            <%= gettext("Search range") %>
            <span class="text-gray-400">
              (<%= gettext("around") %> <%= @current_user.zip_code %> <%= @city_name.name %>)
            </span>
          </label>
          <div phx-feedback-for={f[:search_range].name} class="mt-2">
            <%= select(
              f,
              :search_range,
              [
                {"2 km", 2},
                {"5 km", 5},
                {"10 km", 10},
                {"20 km", 20},
                {"30 km", 30},
                {"50 km", 50},
                {"75 km", 75},
                {"100 km", 100},
                {"150 km", 150},
                {"200 km", 200},
                {"300 km", 300}
              ],
              prompt: gettext("doesn't matter"),
              class:
                "block w-full rounded-md border-0 py-1.5 dark:bg-gray-700 dark:text-white text-gray-900 shadow-sm ring-1 ring-inset focus:ring-2 focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
                  unless(get_field_errors(f[:search_range], :search_range) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  )
            ) %>

            <.error :for={msg <- get_field_errors(f[:search_range], :search_range)}>
              <%= gettext("Search range") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <%= submit(gettext("Save"),
            class:
              "flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          ) %>
        </div>
      </.form>
    </div>
    """
  end

  def cal_minimum_partner_height(user) do
    # This is not a scientific method. Don't start to argue with me
    # about this. The assumption is that women prefer taller men and
    # vice versa. Obviously, this is not true for everyone. But a good
    # 80% solution.
    case user.gender do
      "female" -> user.height
      _ -> nil
    end
  end

  def cal_maximum_partner_height(user) do
    case user.gender do
      "male" -> user.height
      _ -> nil
    end
  end

  def cal_minimum_partner_age(user) do
    user.age - 7
  end

  def cal_maximum_partner_age(user) do
    user.age + 7
  end

  def guess_partner_gender(user) do
    case user.gender do
      "male" -> "female"
      "female" -> "male"
      _ -> "diverse"
    end
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
  end
end
