defmodule AniminaWeb.UserLive.Login do
  use AniminaWeb, :live_view

  @dev_routes Application.compile_env(:animina, :dev_routes)
  @dev_password "password12345"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md px-4 py-8">
        <div class="bg-surface rounded-xl shadow-md p-6 sm:p-8">
          <div class="text-center mb-8">
            <h1 class="text-2xl sm:text-3xl font-light text-base-content">
              {gettext("Log in")}
            </h1>
            <p :if={!@current_scope} class="mt-2 text-base text-base-content/70">
              {gettext("Don't have an account?")}
              <.link
                navigate={~p"/users/register"}
                class="font-semibold text-primary hover:underline"
              >
                {gettext("Register now")}
              </.link>
            </p>
            <p :if={@current_scope} class="mt-2 text-base text-base-content/70">
              {gettext("Please re-authenticate to perform sensitive actions.")}
            </p>
          </div>

          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
            class="space-y-4"
          >
            <.input
              readonly={!!@current_scope}
              field={f[:email]}
              type="email"
              label={gettext("Email address")}
              autocomplete="email"
              required
              phx-mounted={JS.focus()}
            />
            <.input
              field={@form[:password]}
              type="password"
              label={gettext("Password")}
              autocomplete="current-password"
              required
            />
            <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
              {gettext("Log in")}
            </.button>
          </.form>

          <div :if={!@current_scope} class="mt-4 text-center">
            <.link
              navigate={~p"/users/forgot-password"}
              class="text-sm text-base-content/70 hover:text-primary hover:underline"
            >
              {gettext("Forgot your password?")}
            </.link>
          </div>
        </div>

        <.dev_users_panel :if={@dev_routes && !@current_scope} dev_users={@dev_users} />
      </div>
    </Layouts.app>
    """
  end

  attr :dev_users, :list, required: true

  defp dev_users_panel(assigns) do
    ~H"""
    <div :if={length(@dev_users) > 0} class="mt-6 bg-surface rounded-xl shadow-md p-4">
      <div class="text-center mb-3">
        <h2 class="text-lg font-semibold text-base-content">Dev Test Accounts</h2>
        <p class="text-xs text-base-content/60">Click to log in instantly</p>
      </div>

      <div class="max-h-80 overflow-y-auto">
        <div class="grid grid-cols-2 gap-1">
          <.dev_user_button :for={user <- @dev_users} user={user} />
        </div>
      </div>
    </div>
    """
  end

  attr :user, :map, required: true

  defp dev_user_button(assigns) do
    ~H"""
    <form action={~p"/users/log-in"} method="post" class="contents">
      <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
      <input type="hidden" name="user[email]" value={@user.email} />
      <input type="hidden" name="user[password]" value={dev_password()} />
      <input type="hidden" name="user[remember_me]" value="true" />
      <button
        type="submit"
        class="flex items-center gap-1.5 px-2 py-1.5 text-xs rounded hover:bg-base-200 transition-colors text-left w-full"
      >
        <span class="flex-shrink-0">{gender_icon(@user.gender)}</span>
        <span class="truncate flex-1 font-medium">{@user.display_name}</span>
        <span class="text-base-content/60">{@user.age}</span>
        <.role_badges roles={@user.roles} />
      </button>
    </form>
    """
  end

  attr :roles, :list, required: true

  defp role_badges(assigns) do
    ~H"""
    <span :if={:admin in @roles} class="px-1 py-0.5 text-[10px] bg-error/20 text-error rounded">
      A
    </span>
    <span
      :if={:moderator in @roles}
      class="px-1 py-0.5 text-[10px] bg-warning/20 text-warning rounded"
    >
      M
    </span>
    """
  end

  defp gender_icon("male"), do: raw("&#9794;")
  defp gender_icon("female"), do: raw("&#9792;")
  defp gender_icon(_), do: raw("&#9898;")

  defp dev_password, do: @dev_password

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    dev_users =
      if @dev_routes do
        load_dev_users()
      else
        []
      end

    {:ok,
     assign(socket,
       form: form,
       trigger_submit: false,
       dev_routes: @dev_routes,
       dev_users: dev_users
     )}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  defp load_dev_users do
    import Ecto.Query

    query =
      from(u in Animina.Accounts.User,
        where: like(u.email, "dev-%@animina.test"),
        where: is_nil(u.deleted_at),
        left_join: r in assoc(u, :user_roles),
        preload: [user_roles: r],
        order_by: [asc: u.gender, asc: u.display_name]
      )

    Animina.Repo.all(query)
    |> Enum.map(fn user ->
      age = calculate_age(user.birthday)

      roles =
        user.user_roles
        |> Enum.map(fn ur -> String.to_atom(ur.role) end)

      %{
        email: user.email,
        display_name: user.display_name,
        gender: user.gender,
        age: age,
        roles: roles
      }
    end)
  end

  defp calculate_age(birthday) do
    today = Date.utc_today()
    age = today.year - birthday.year

    if {today.month, today.day} < {birthday.month, birthday.day} do
      age - 1
    else
      age
    end
  end
end
