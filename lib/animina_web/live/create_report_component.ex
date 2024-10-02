defmodule AniminaWeb.Live.CreateReportComponent do
  @moduledoc """
  This is the LiveView component for creating a report.
  """
  use AniminaWeb, :live_component
  alias Animina.Accounts
  alias Animina.Accounts.Report
  alias AshPhoenix.Form

  @impl true
  def update(%{current_user: current_user, user: user, language: language} = assigns, socket) do
    form =
      Form.for_create(Report, :create,
        domain: Accounts,
        as: "report",
        forms: [],
        actor: current_user
      )
      |> to_form()

    socket =
      socket
      |> assign(language: language)
      |> assign(active_tab: :home)
      |> assign(form: form)
      |> assign(errors: [])
      |> assign(current_user: current_user)
      |> assign(user: user)
      |> assign(assigns)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"report" => report}, socket) do
    form = Form.validate(socket.assigns.form, report, errors: true)

    {:noreply,
     socket
     |> assign(:form, form)}
  end

  def handle_event("submit", %{"report" => report}, socket) do
    form = Form.validate(socket.assigns.form, report)

    with [] <- Form.errors(form),
         {:ok, _report} <-
           Report.create(report) do
      {:noreply,
       socket
       |> assign(:errors, [])
       |> put_flash(:info, "Report submitted successfully.")
       |> push_navigate(to: ~p"/my/dashboard")}
    else
      {:error, form} ->
        {:noreply, socket |> assign(:form, form)}

      errors ->
        {:noreply, socket |> assign(:errors, errors)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <p class="dark:text-white text-sm">
        <%= with_locale(@language, fn -> %>
          <%= gettext(
            "To report an account is a serious act. The account will be deactivated right away and will be investigated by our team. Please tell us why you report the account."
          ) %>
        <% end) %>

        <.form
          :let={f}
          id="report-form"
          for={@form}
          phx-target={@myself}
          class="space-y-6 group"
          phx-change="validate"
          phx-submit="submit"
        >
          <%= hidden_input(f, :accuser_id, value: @current_user.id) %>
          <%= hidden_input(f, :accused_id, value: @user.id) %>
          <%= hidden_input(f, :accused_user_state, value: @user.state) %>
          <%= hidden_input(f, :state, value: :pending) %>
          <div>
            <label
              for="report_description"
              class="block  font-medium leading-6 text-gray-900 dark:text-white"
            >
              <%= with_locale(@language, fn -> %>
                <%= gettext("Description") %>
              <% end) %>
            </label>

            <div phx-feedback-for={f[:description].name} class="mt-2">
              <%= textarea(
                f,
                :description,
                class:
                  "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                    unless(get_field_errors(f[:description], :description) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    ),
                placeholder:
                  with_locale(@language, fn ->
                    gettext(
                      "Use normal text or the Markdown format to write your description. You can use **bold**, *italic*, ~line-through~, [links](https://example.com) and more. Each post can be up to 8,192 characters long. Please do write multiple posts to share your thoughts."
                    )
                  end),
                value: f[:description].value,
                rows: 12,
                type: :text,
                "phx-debounce": "200",
                maxlength: "8192"
              ) %>

              <.error :for={msg <- get_field_errors(f[:description], :description)}>
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Description") <> " " <> msg %>
                <% end) %>
              </.error>
            </div>
          </div>

          <div>
            <%= submit(with_locale(@language, fn -> gettext("Report User") end),
              class:
                "flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                  unless(@form.source.source.valid? == false,
                    do: "",
                    else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                  ),
              disabled: @form.source.source.valid? == false
            ) %>
          </div>
        </.form>
      </p>
    </div>
    """
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
  end
end
