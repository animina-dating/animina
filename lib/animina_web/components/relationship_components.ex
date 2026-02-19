defmodule AniminaWeb.RelationshipComponents do
  @moduledoc """
  Shared function components for the relationship system.

  Provides:
  - `relationship_timeline/1` — vertical timeline of milestones
  - `relationship_badge_class/1` — status → DaisyUI badge class
  - `relationship_status_label/1` — status → gettext translated label
  """

  use Phoenix.Component
  use Gettext, backend: AniminaWeb.Gettext

  import AniminaWeb.CoreComponents, only: [icon: 1]

  # --- Badge & Label Helpers (shared by MessagesLive + RelationshipsLive) ---

  @doc """
  Returns the DaisyUI badge class for a relationship status.
  """
  def relationship_badge_class("chatting"), do: "badge-info"
  def relationship_badge_class("dating"), do: "badge-primary"
  def relationship_badge_class("couple"), do: "badge-secondary"
  def relationship_badge_class("married"), do: "badge-accent"
  def relationship_badge_class("separated"), do: "badge-warning"
  def relationship_badge_class("divorced"), do: "badge-warning"
  def relationship_badge_class("ex"), do: "badge-ghost"
  def relationship_badge_class("friend"), do: "badge-ghost"
  def relationship_badge_class("blocked"), do: "badge-error"
  def relationship_badge_class("ended"), do: "badge-ghost"
  def relationship_badge_class(_), do: "badge-ghost"

  @doc """
  Returns the translated label for a relationship status.
  """
  def relationship_status_label("chatting"), do: gettext("Chatting")
  def relationship_status_label("dating"), do: gettext("Dating")
  def relationship_status_label("couple"), do: gettext("Couple")
  def relationship_status_label("married"), do: gettext("Married")
  def relationship_status_label("separated"), do: gettext("Separated")
  def relationship_status_label("divorced"), do: gettext("Divorced")
  def relationship_status_label("ex"), do: gettext("Ex")
  def relationship_status_label("friend"), do: gettext("Friend")
  def relationship_status_label("blocked"), do: gettext("Blocked")
  def relationship_status_label("ended"), do: gettext("Ended")
  def relationship_status_label(_), do: ""

  # --- Timeline Component ---

  @doc """
  Renders a vertical timeline of relationship milestones.

  ## Attributes

    * `milestones` — list of `%RelationshipEvent{}` structs (required)
    * `users` — map of user_id → user struct (required)
    * `current_user_id` — the current user's ID (required)
  """
  attr :milestones, :list, required: true
  attr :users, :map, required: true
  attr :current_user_id, :string, required: true

  def relationship_timeline(assigns) do
    ~H"""
    <div :if={@milestones == []} class="text-sm text-base-content/50 italic">
      {gettext("No milestones yet")}
    </div>
    <div :if={@milestones != []} class="relative pl-6">
      <%!-- Vertical line --%>
      <div class="absolute left-[9px] top-2 bottom-2 w-0.5 bg-base-300" />

      <div :for={milestone <- @milestones} class="relative pb-4 last:pb-0">
        <%!-- Dot --%>
        <div class={[
          "absolute -left-6 top-0.5 w-[18px] h-[18px] rounded-full border-2 border-base-100 flex items-center justify-center",
          milestone_dot_class(milestone.to_status)
        ]}>
          <.icon name={milestone_icon(milestone.to_status)} class="h-2.5 w-2.5 text-white" />
        </div>

        <%!-- Content --%>
        <div class="ml-2">
          <span class={["badge badge-sm", relationship_badge_class(milestone.to_status)]}>
            {relationship_status_label(milestone.to_status)}
          </span>
          <div class="text-xs text-base-content/50 mt-0.5">
            {format_milestone_time(milestone.inserted_at)}
            <span :if={milestone.actor_id} class="ml-1">
              &mdash; {actor_name(milestone.actor_id, @current_user_id, @users)}
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- Private Helpers ---

  defp milestone_dot_class("chatting"), do: "bg-info"
  defp milestone_dot_class("dating"), do: "bg-primary"
  defp milestone_dot_class("couple"), do: "bg-secondary"
  defp milestone_dot_class("married"), do: "bg-accent"
  defp milestone_dot_class("separated"), do: "bg-warning"
  defp milestone_dot_class("divorced"), do: "bg-warning"
  defp milestone_dot_class("ex"), do: "bg-base-300"
  defp milestone_dot_class("friend"), do: "bg-base-300"
  defp milestone_dot_class("blocked"), do: "bg-error"
  defp milestone_dot_class("ended"), do: "bg-base-300"
  defp milestone_dot_class(_), do: "bg-base-300"

  defp milestone_icon("chatting"), do: "hero-chat-bubble-left-right-mini"
  defp milestone_icon("dating"), do: "hero-heart-mini"
  defp milestone_icon("couple"), do: "hero-users-mini"
  defp milestone_icon("married"), do: "hero-sparkles-mini"
  defp milestone_icon("separated"), do: "hero-arrows-pointing-out-mini"
  defp milestone_icon("divorced"), do: "hero-document-text-mini"
  defp milestone_icon("ex"), do: "hero-x-mark-mini"
  defp milestone_icon("friend"), do: "hero-hand-raised-mini"
  defp milestone_icon("blocked"), do: "hero-no-symbol-mini"
  defp milestone_icon("ended"), do: "hero-x-circle-mini"
  defp milestone_icon(_), do: "hero-minus-mini"

  defp actor_name(actor_id, current_user_id, _users) when actor_id == current_user_id do
    gettext("You")
  end

  defp actor_name(actor_id, _current_user_id, users) do
    case Map.get(users, actor_id) do
      nil -> ""
      user -> user.display_name
    end
  end

  defp format_milestone_time(datetime) do
    now = DateTime.utc_now()
    diff_days = Date.diff(DateTime.to_date(now), DateTime.to_date(datetime))

    cond do
      diff_days == 0 -> gettext("Today")
      diff_days == 1 -> gettext("Yesterday")
      diff_days < 7 -> Calendar.strftime(datetime, "%A")
      diff_days < 30 -> gettext("%{count} days ago", count: diff_days)
      true -> Calendar.strftime(datetime, "%d.%m.%Y")
    end
  end
end
