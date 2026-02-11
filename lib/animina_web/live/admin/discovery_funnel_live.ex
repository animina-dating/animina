defmodule AniminaWeb.Admin.DiscoveryFunnelLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Discovery.CandidatePool
  alias AniminaWeb.Layouts

  @impl true
  def mount(%{"user_id" => user_id}, _session, socket) do
    user = Accounts.get_user!(user_id)
    send(self(), {:load_funnel, user})

    {:ok,
     assign(socket,
       page_title: gettext("Discovery Funnel"),
       search_query: "",
       search_results: [],
       selected_user: user,
       funnel_steps: nil,
       candidate_count: nil,
       loading: true
     )}
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Discovery Funnel"),
       search_query: "",
       search_results: [],
       selected_user: nil,
       funnel_steps: nil,
       candidate_count: nil,
       loading: false
     )}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    results = Accounts.search_users(query)
    {:noreply, assign(socket, search_query: query, search_results: results)}
  end

  def handle_event("select_user", %{"id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    send(self(), {:load_funnel, user})

    {:noreply,
     assign(socket,
       selected_user: user,
       funnel_steps: nil,
       candidate_count: nil,
       loading: true
     )}
  end

  @impl true
  def handle_info({:load_funnel, user}, socket) do
    {steps, candidates} = CandidatePool.build_with_funnel(user)

    {:noreply,
     assign(socket,
       funnel_steps: steps,
       candidate_count: length(candidates),
       loading: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.page_header
          title={gettext("Discovery Funnel")}
          subtitle={gettext("Analyze filter pipeline for any user")}
        >
          <:crumb navigate={~p"/admin"}>{gettext("Admin")}</:crumb>
        </.page_header>

        <div class="mb-6">
          <form phx-change="search">
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder={gettext("Search users by email or name...")}
              class="input input-bordered w-full"
              autocomplete="off"
              phx-debounce="300"
            />
          </form>
        </div>

        <div
          :if={@search_results != []}
          class="bg-base-200 rounded-lg divide-y divide-base-300 mb-6"
        >
          <button
            :for={user <- @search_results}
            phx-click="select_user"
            phx-value-id={user.id}
            class={[
              "block w-full text-start px-4 py-3 hover:bg-base-300 transition-colors",
              @selected_user && @selected_user.id == user.id && "bg-primary/10"
            ]}
          >
            <p class="text-sm font-medium text-base-content">{user.display_name}</p>
            <p class="text-xs text-base-content/50">{user.email}</p>
          </button>
        </div>

        <div :if={@selected_user} class="bg-base-200 rounded-lg p-6 mb-6">
          <h2 class="text-lg font-semibold text-base-content mb-1">
            {@selected_user.display_name}
          </h2>
          <p class="text-sm text-base-content/50">{@selected_user.email}</p>
        </div>

        <div :if={@loading} class="flex justify-center py-8">
          <span class="loading loading-spinner loading-lg"></span>
        </div>

        <div :if={@funnel_steps && !@loading}>
          <div class="overflow-x-auto">
            <table class="table table-zebra w-full">
              <thead>
                <tr>
                  <th>{gettext("Step")}</th>
                  <th class="text-right">{gettext("Count")}</th>
                  <th class="text-right">{gettext("Drop")}</th>
                  <th class="text-right">{gettext("Drop %")}</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={step <- @funnel_steps}>
                  <td class="font-medium">{step.name}</td>
                  <td class="text-right font-mono">{step.count}</td>
                  <td class="text-right font-mono">
                    <span :if={step.drop > 0}>−{step.drop}</span>
                    <span :if={step.drop == 0} class="text-base-content/30">—</span>
                  </td>
                  <td class="text-right">
                    <span class={drop_color(step.drop_pct)}>
                      {format_pct(step.drop_pct)}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <p
          :if={!@selected_user && !@loading}
          class="text-center text-base-content/50 py-8"
        >
          {gettext("Select a user to analyze their discovery funnel.")}
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp drop_color(pct) when pct < 10.0, do: "text-success font-mono"
  defp drop_color(pct) when pct < 30.0, do: "text-warning font-mono"
  defp drop_color(_pct), do: "text-error font-mono"

  defp format_pct(pct) when pct == 0.0, do: "—"
  defp format_pct(pct), do: "#{Float.round(pct, 1)}%"
end
