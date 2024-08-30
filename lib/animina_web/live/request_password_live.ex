defmodule AniminaWeb.RequestPasswordLive do
  use AniminaWeb, :live_view
  alias Animina.Accounts
  alias Animina.Accounts.User
  alias AshPhoenix.Form

  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(current_user: nil)
      |> assign(trigger_action: false)
      |> assign(current_user_credit_points: 0)
      |> assign(:errors, [])
      |> assign(page_title: gettext("Request Password Reset"))
      |> assign(:cta, gettext("Send Reset Password Link"))
      |> assign(active_tab: :register)
      |> assign(page_title: "Animina #{gettext("Request Password Reset")}")
      |> assign(:action, "/auth/user/password/reset_request")
      |> assign(
        :form,
        Form.for_create(User, :register_with_password, domain: Accounts, as: "user")
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => user}, socket) do
    form = Form.validate(socket.assigns.form, user, errors: true)

    {:noreply, socket |> assign(form: form)}
  end

  @impl true
  def handle_event("submit", %{"user" => user}, socket) do
    form = Form.validate(socket.assigns.form, user)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:errors, Form.errors(form))
     |> assign(:trigger_action, true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-5 space-y-10">
      <.form
        :let={f}
        id="basic_user_form"
        for={@form}
        action={@action}
        phx-trigger-action={@trigger_action}
        method="POST"
        class="space-y-6 group "
        phx-change="validate"
        phx-submit="submit"
      >
        <p class="text-xl dark:text-white text-black font-medium">
          <%= gettext("Enter your email address to receive a password reset link") %>
        </p>

        <div class="w-[100%] md:grid grid-cols-1 gap-1">
          <label
            for="user_email"
            class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
          >
            <%= gettext("E-mail address") %>
          </label>
          <div phx-feedback-for={f[:email].name} class="mt-2">
            <%= text_input(f, :email,
              class:
                "block w-full rounded-md border-0 py-1.5 dark:bg-gray-700  dark:text-white text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 ",
              placeholder: gettext("alice@example.net"),
              value: f[:email].value,
              required: true,
              autocomplete: :email,
              "phx-debounce": "200"
            ) %>
          </div>
          <div class="mt-3">
            <.link navigate="/sign-in">
              <p class="block text-sm leading-6 text-blue-600 transition-all duration-500 ease-in-out hover:text-blue-500 dark:hover:text-blue-500 hover:cursor-pointer hover:underline">
                <%= gettext("Back to Sign In") %>
              </p>
            </.link>
          </div>

          <div class="mt-4">
            <%= submit(@cta,
              class:
                "flex w-full justify-center rounded-md bg-indigo-600 dark:bg-indigo-500 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 "
            ) %>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
