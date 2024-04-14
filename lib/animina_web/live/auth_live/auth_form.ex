defmodule AniminaWeb.AuthLive.AuthForm do
  use AniminaWeb, :live_component
  use Phoenix.HTML
  alias Animina.GenServers.ProfileViewCredits
  alias AshPhoenix.Form
  alias Phoenix.PubSub

  @impl true
  def update(assigns, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
    end

    socket =
      socket
      |> assign(assigns)
      |> assign(trigger_action: false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    form = socket.assigns.form |> Form.validate(params, errors: false)

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    form = socket.assigns.form |> Form.validate(params)

    socket =
      socket
      |> assign(:form, form)
      |> assign(:errors, Form.errors(form))
      |> assign(:trigger_action, form.valid?)

    {:noreply, socket}
  end

  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      if socket.assigns.current_user do
        ProfileViewCredits.get_updated_credit_for_user(socket, credits)
      else
        0
      end

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <ul class="error-messages">
        <%= if @form.errors do %>
          <%= for {k, v} <- @errors do %>
            <li>
              <%= humanize("#{k} #{v}") %>
            </li>
          <% end %>
        <% end %>
      </ul>
      <.form
        :let={f}
        for={@form}
        phx-change="validate"
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        phx-target={@myself}
        action={@action}
        method="POST"
      >
        <%= if @is_register? do %>
          <fieldset class="form-group">
            <%= text_input(f, :username,
              class: "form-control form-control-lg",
              placeholder: "Username"
            ) %>
          </fieldset>
        <% end %>
        <fieldset class="form-group">
          <%= text_input(f, :email,
            class: "form-control form-control-lg",
            placeholder: "Email"
          ) %>
        </fieldset>
        <fieldset class="form-group">
          <%= password_input(f, :password,
            class: "form-control form-control-lg",
            placeholder: "Password"
          ) %>
        </fieldset>
        <%= submit(@cta, class: "btn btn-lg btn-primary pull-xs-right") %>
      </.form>
    </div>
    """
  end
end
