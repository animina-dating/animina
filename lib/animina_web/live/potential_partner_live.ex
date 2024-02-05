defmodule AniminaWeb.PotentialPartnerLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts.User
  alias AniminaWeb.Registration

  @impl true
  def mount(_params, session, socket) do
    current_user = Registration.get_current_user(session)

    # TODO: Let's not update these values in the database at this point
    # in time.
    current_user =
      current_user
      |> User.update!(%{
        maximum_partner_height: cal_maximum_partner_height(current_user),
        minimum_partner_height: cal_minimum_partner_height(current_user),
        maximum_partner_age: cal_maximum_partner_age(current_user),
        minimum_partner_age: cal_minimum_partner_age(current_user)
      })

    socket =
      socket
      |> assign(current_user: current_user)
      |> assign(active_tab: :home)
      |> assign(update_form: AshPhoenix.Form.for_update(current_user, :update) |> to_form())

    {:ok, socket}
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
        title={"Hallo #{@current_user.name}!"}
        message="Danke für Deine Registierung."
      />

      <h2>Kriterien für Deine Partnerwahl</h2>
      <.form :let={f} for={@update_form} phx-submit="update_user" class="space-y-6">
        <div>
          <label
            for="minimum_partner_height"
            class="block text-sm font-medium leading-6 text-gray-900"
          >
            Minimale Größe <span class="text-gray-400">(in cm)</span>
          </label>
          <div class="mt-2">
            <%= select(f, :minimum_partner_height, Enum.map(140..210, &{"#{&1} cm", &1}),
              prompt: "Egal",
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
            Maximale Größe <span class="text-gray-400">(in cm)</span>
          </label>
          <div class="mt-2">
            <%= select(f, :maximum_partner_height, Enum.map(140..210, &{"#{&1} cm", &1}),
              prompt: "Egal",
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
            ) %>
          </div>
        </div>

        <div>
          <label for="minimum_partner_age" class="block text-sm font-medium leading-6 text-gray-900">
            Mindestalter
          </label>
          <div class="mt-2">
            <%= select(f, :minimum_partner_age, Enum.map(18..110, &{&1, &1}),
              prompt: "Egal",
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
            ) %>
          </div>
        </div>

        <div>
          <label for="maximum_partner_age" class="block text-sm font-medium leading-6 text-gray-900">
            Höchstalter
          </label>
          <div class="mt-2">
            <%= select(f, :maximum_partner_age, Enum.map(18..110, &{&1, &1}),
              prompt: "Egal",
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
            ) %>
          </div>
        </div>

        <div>
          <%= submit("Update",
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
