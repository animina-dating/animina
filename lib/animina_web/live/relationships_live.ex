defmodule AniminaWeb.RelationshipsLive do
  @moduledoc """
  LiveView for listing all relationships.
  """

  use AniminaWeb, :live_view

  import AniminaWeb.RelationshipComponents

  alias Animina.Accounts
  alias Animina.Relationships
  alias AniminaWeb.Helpers.AvatarHelpers

  @active_statuses ~w(couple married dating chatting friend)
  @past_statuses ~w(separated divorced ex ended blocked)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.breadcrumb_nav>
          <:crumb navigate={~p"/my"}>{gettext("My Hub")}</:crumb>
          <:crumb>{gettext("Relationships")}</:crumb>
        </.breadcrumb_nav>
        <.header>
          {gettext("Relationships")}
        </.header>

        <%= if @active_relationships == [] && @past_relationships == [] do %>
          <div class="text-center py-12 text-base-content/50">
            <.icon name="hero-heart" class="h-12 w-12 mx-auto mb-4 opacity-50" />
            <p class="text-lg">{gettext("No relationships yet")}</p>
            <p class="text-sm mt-2">
              {gettext("Start a conversation from a user's profile")}
            </p>
          </div>
        <% else %>
          <%!-- Active Relationships --%>
          <div :if={@active_relationships != []} class="mt-6">
            <h2 class="text-sm font-semibold text-base-content/50 uppercase tracking-wider mb-3">
              {gettext("Active")}
            </h2>
            <div class="divide-y divide-base-300">
              <.relationship_row
                :for={rel <- @active_relationships}
                relationship={rel}
                current_user_id={@current_scope.user.id}
                users={@users}
                avatar_photos={@avatar_photos}
                expanded_timeline={@expanded_timeline}
                milestones={@milestones}
                online_user_ids={@online_user_ids}
                current_scope={@current_scope}
              />
            </div>
          </div>

          <%!-- Past Relationships --%>
          <div :if={@past_relationships != []} class="mt-10">
            <div class="divider"></div>
            <h2 class="text-sm font-semibold text-base-content/50 uppercase tracking-wider mb-3">
              {gettext("Past")}
            </h2>
            <div class="divide-y divide-base-300">
              <.relationship_row
                :for={rel <- @past_relationships}
                relationship={rel}
                current_user_id={@current_scope.user.id}
                users={@users}
                avatar_photos={@avatar_photos}
                expanded_timeline={@expanded_timeline}
                milestones={@milestones}
                online_user_ids={@online_user_ids}
                current_scope={@current_scope}
              />
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :relationship, :map, required: true
  attr :current_user_id, :string, required: true
  attr :users, :map, required: true
  attr :avatar_photos, :map, required: true
  attr :expanded_timeline, :string, default: nil
  attr :milestones, :list, default: []
  attr :online_user_ids, :any, default: MapSet.new()
  attr :current_scope, :any, default: nil

  defp relationship_row(assigns) do
    other_id = Relationships.other_user_id(assigns.relationship, assigns.current_user_id)
    other_user = Map.get(assigns.users, other_id)
    expanded = assigns.expanded_timeline == assigns.relationship.id

    assigns =
      assigns
      |> assign(:other_user, other_user)
      |> assign(:expanded, expanded)

    ~H"""
    <div :if={@other_user}>
      <div class="flex items-center gap-3 py-3">
        <.user_avatar
          user={@other_user}
          photos={@avatar_photos}
          online={MapSet.member?(@online_user_ids, @other_user.id)}
          current_scope={@current_scope}
        />

        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <span class="font-medium truncate">{@other_user.display_name}</span>
            <span class={["badge badge-sm", relationship_badge_class(@relationship.status)]}>
              {relationship_status_label(@relationship.status)}
            </span>
          </div>
          <div class="text-xs text-base-content/50 mt-0.5">
            {format_relative(@relationship.status_changed_at)}
          </div>
        </div>

        <button
          phx-click="toggle_timeline"
          phx-value-relationship-id={@relationship.id}
          class={[
            "btn btn-ghost btn-sm btn-circle",
            @expanded && "text-primary"
          ]}
          title={gettext("Timeline")}
        >
          <.icon name="hero-clock" class="h-4 w-4" />
        </button>

        <.link
          navigate={
            ~p"/my/messages?start_with=#{Relationships.other_user_id(@relationship, @current_user_id)}"
          }
          class="btn btn-ghost btn-sm btn-circle"
          title={gettext("Message")}
        >
          <.icon name="hero-chat-bubble-left" class="h-4 w-4" />
        </.link>
      </div>

      <div :if={@expanded} class="px-12 pb-3">
        <.relationship_timeline
          milestones={@milestones}
          users={@users}
          current_user_id={@current_user_id}
        />
      </div>
    </div>
    """
  end

  defp format_relative(nil), do: ""

  defp format_relative(datetime) do
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

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    all_relationships = Relationships.list_relationships(user.id)

    active_relationships =
      Enum.filter(all_relationships, &(&1.status in @active_statuses))

    past_relationships =
      Enum.filter(all_relationships, &(&1.status in @past_statuses))

    # Collect all other user IDs
    other_user_ids =
      all_relationships
      |> Enum.map(&Relationships.other_user_id(&1, user.id))
      |> Enum.uniq()

    # Load users
    users =
      other_user_ids
      |> Enum.map(&Accounts.get_user/1)
      |> Enum.reject(&is_nil/1)
      |> Map.new(&{&1.id, &1})

    # Load avatars
    avatar_photos = AvatarHelpers.load_avatars(other_user_ids)

    {:ok,
     assign(socket,
       page_title: gettext("Relationships"),
       active_relationships: active_relationships,
       past_relationships: past_relationships,
       users: users,
       avatar_photos: avatar_photos,
       expanded_timeline: nil,
       milestones: []
     )}
  end

  @impl true
  def handle_event("toggle_timeline", %{"relationship-id" => rel_id}, socket) do
    if socket.assigns.expanded_timeline == rel_id do
      {:noreply, assign(socket, expanded_timeline: nil, milestones: [])}
    else
      milestones = Relationships.list_milestones(rel_id)
      {:noreply, assign(socket, expanded_timeline: rel_id, milestones: milestones)}
    end
  end
end
