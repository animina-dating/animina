defmodule AniminaWeb.PotentialPartnerLive do
  use AniminaWeb, :live_view
  require Ash.Query

  alias Animina.Accounts.Credit
  alias Animina.Accounts.User
  alias AniminaWeb.Registration

  @impl true
  def mount(_params, session, socket) do
    current_user =
      case Registration.get_current_user(session) do
        nil ->
          redirect(socket, to: "/")

        user ->
          user
      end

    add_registration_bonus(socket, current_user)

    socket =
      case current_user do
        nil ->
          socket

        _ ->
          user =
            current_user
            |> Map.put(:maximum_partner_height, cal_maximum_partner_height(current_user))
            |> Map.put(:minimum_partner_height, cal_minimum_partner_height(current_user))
            |> Map.put(:maximum_partner_age, cal_maximum_partner_age(current_user))
            |> Map.put(:minimum_partner_age, cal_minimum_partner_age(current_user))

          socket
          |> assign(update_form: AshPhoenix.Form.for_update(user, :update) |> to_form())
      end
      |> assign(current_user: current_user)
      |> assign(active_tab: :home)
      |> assign(page_title: gettext("Preferences for your future partner"))

    {:ok, socket}
  end

  defp add_registration_bonus(socket, user) do
    if !connected?(socket) && user do
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
  def handle_event("update_user", %{"form" => form_params}, socket) do
    current_user =
      User.by_id!(socket.assigns.current_user.id)
      |> User.update!(form_params)

    {:noreply, assign(socket, current_user: current_user)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-10 px-5">
      <.notification_box
        title={gettext("Hello %{name}!", name: @current_user.name)}
        message={
          gettext(
            "You can always check your points in the top navigation bar. You just received 100 for the registration."
          )
        }
      />

      <h2 class="font-bold text-xl"><%= gettext("Criteria for your new partner") %></h2>
      <.form :let={f} for={@update_form} phx-submit="update_user" class="space-y-6">
        <div>
          <label
            for="minimum_partner_height"
            class="block text-sm font-medium leading-6 text-gray-900"
          >
            <%= gettext("Minimum height") %>
          </label>
          <div class="mt-2">
            <%= select(f, :minimum_partner_height, Enum.map(140..210, &{"#{&1} cm", &1}),
              prompt: gettext("doesn't matter"),
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              autofocus: true
            ) %>
          </div>
        </div>

        <div>
          <label
            for="maximum_partner_height"
            class="block text-sm font-medium leading-6 text-gray-900"
          >
            <%= gettext("Maximum height") %>
          </label>
          <div class="mt-2">
            <%= select(f, :maximum_partner_height, Enum.map(140..210, &{"#{&1} cm", &1}),
              prompt: gettext("doesn't matter"),
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
            ) %>
          </div>
        </div>

        <div>
          <label for="minimum_partner_age" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("Minimum age") %>
          </label>
          <div class="mt-2">
            <%= select(f, :minimum_partner_age, Enum.map(18..110, &{&1, &1}),
              prompt: gettext("doesn't matter"),
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
            ) %>
          </div>
        </div>

        <div>
          <label for="maximum_partner_age" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("Maximum age") %>
          </label>
          <div class="mt-2">
            <%= select(f, :maximum_partner_age, Enum.map(18..110, &{&1, &1}),
              prompt: gettext("doesn't matter"),
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
            ) %>
          </div>
        </div>

        <div>
          <label for="search_range" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("Search range") %>
          </label>
          <div class="mt-2">
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
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
            ) %>
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
    user.age - 5
  end

  def cal_maximum_partner_age(user) do
    user.age + 5
  end
end
