defmodule AniminaWeb.PendingReportsLive do
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
      case Report.pending_reports(actor: socket.assigns.current_user) do
        {:ok, reports} ->
          reports

        _ ->
          []
      end

    socket =
      socket
      |> assign(active_tab: :reports)
      |> assign(:language, language)
      |> assign(:page_title, gettext("Pending Reports"))
      |> assign(:reports, reports)

    {:ok, socket}
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)
      |> Points.humanized_points()

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
  end

  def handle_info({:user, current_user}, socket) do
    if current_user.state in user_states_to_be_auto_logged_out() do
      {:noreply,
       socket
       |> push_redirect(to: "/auth/user/sign-out?auto_log_out=#{current_user.state}")}
    else
      {:noreply,
       socket
       |> assign(:current_user, current_user)}
    end
  end

  defp user_states_to_be_auto_logged_out do
    [
      :under_investigation,
      :banned,
      :archived
    ]
  end

  def render(assigns) do
    ~H"""
    <div>
      <.report_tabs current_report_tab="pending" />

      <.reports_card reports={@reports} current_user={@current_user} />
    </div>
    """
  end
end
