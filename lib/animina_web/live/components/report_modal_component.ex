defmodule AniminaWeb.ReportModalComponent do
  @moduledoc """
  Modal component for reporting a user.

  Props:
  - `show` - boolean, whether to show the modal
  - `reported_user` - the user being reported
  - `context_type` - "chat", "moodboard", or "profile"
  - `context_id` - conversation_id or moodboard_item_id (nil for profile)
  - `current_scope` - the current user's scope
  """

  use AniminaWeb, :live_component

  alias Animina.Reports
  alias Animina.Reports.Category

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:category, fn -> nil end)
     |> assign_new(:description, fn -> "" end)
     |> assign_new(:submitting, fn -> false end)
     |> assign(:categories, Category.user_options())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <dialog id={"report-modal-#{@id}"} class={["modal", if(@show, do: "modal-open")]}>
        <div class="modal-box">
          <h3 class="font-bold text-lg mb-4">
            {gettext("Report user")}
          </h3>

          <form phx-submit="submit_report" phx-target={@myself}>
            <div class="form-control mb-4">
              <label class="label">
                <span class="label-text font-medium">{gettext("Category")}</span>
              </label>
              <select
                name="category"
                class="select select-bordered w-full"
                required
                phx-change="select_category"
                phx-target={@myself}
              >
                <option value="" disabled selected={is_nil(@category)}>
                  {gettext("Select a reason...")}
                </option>
                <option
                  :for={{value, label} <- @categories}
                  value={value}
                  selected={@category == value}
                >
                  {label}
                </option>
              </select>
            </div>

            <div class="form-control mb-4">
              <label class="label">
                <span class="label-text font-medium">{gettext("Description (optional)")}</span>
              </label>
              <textarea
                name="description"
                class="textarea textarea-bordered w-full"
                rows="3"
                maxlength="500"
                placeholder={gettext("Provide additional details...")}
                phx-change="update_description"
                phx-target={@myself}
              >{@description}</textarea>
              <label class="label">
                <span class="label-text-alt">{String.length(@description)}/500</span>
              </label>
            </div>

            <div class="modal-action">
              <button
                type="button"
                class="btn"
                phx-click="close_report_modal"
              >
                {gettext("Cancel")}
              </button>
              <button
                type="submit"
                class="btn btn-error"
                disabled={is_nil(@category) || @submitting}
              >
                <span :if={@submitting} class="loading loading-spinner loading-sm"></span>
                {gettext("Submit report")}
              </button>
            </div>
          </form>
        </div>
        <form method="dialog" class="modal-backdrop">
          <button phx-click="close_report_modal">{gettext("close")}</button>
        </form>
      </dialog>
    </div>
    """
  end

  @impl true
  def handle_event("select_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :category, category)}
  end

  @impl true
  def handle_event("update_description", %{"description" => desc}, socket) do
    {:noreply, assign(socket, :description, String.slice(desc, 0, 500))}
  end

  @impl true
  def handle_event("submit_report", %{"category" => category} = params, socket) do
    reporter = socket.assigns.current_scope.user
    reported_user = socket.assigns.reported_user

    attrs = %{
      category: category,
      description: Map.get(params, "description", ""),
      context_type: socket.assigns.context_type,
      context_reference_id: socket.assigns[:context_id]
    }

    socket = assign(socket, :submitting, true)

    case Reports.file_report(reporter, reported_user, attrs) do
      {:ok, _report} ->
        send(self(), {:report_submitted, reported_user.id})
        {:noreply, assign(socket, submitting: false, category: nil, description: "")}

      {:error, _reason} ->
        send(self(), {:report_failed})
        {:noreply, assign(socket, :submitting, false)}
    end
  end
end
