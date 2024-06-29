defmodule AniminaWeb.AllReportsLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Points
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.Report
  alias Animina.Accounts.User
  alias AshPhoenix.Form
  alias Phoenix.PubSub

  def mount(_params, %{"language" => language} = _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )

      Phoenix.PubSub.subscribe(
        Animina.PubSub,
        "user_flag:created:#{socket.assigns.current_user.id}"
      )
    end

    reports =
      case Report.all_reports(actor: socket.assigns.current_user) do
        {:ok, reports} ->
          reports

        _ ->
          []
      end

    socket =
      socket
      |> assign(active_tab: :reports)
      |> assign(:language, language)
      |> assign(:page_title, gettext("All Reports"))
      |> assign(:reports, reports)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <p class="dark:text-white text-black  text-xl">
        All Reports
      </p>

      <.reports_card reports={@reports} current_user={@current_user} />
    </div>
    """
  end
end
