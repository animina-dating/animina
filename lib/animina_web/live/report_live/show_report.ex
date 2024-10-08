defmodule AniminaWeb.ShowReportLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts.Points

  alias Animina.Accounts.Report

  alias Phoenix.PubSub

  alias Animina.GenServers.ProfileViewCredits
  @impl true
  def mount(%{"id" => id}, %{"language" => language} = _session, socket) do
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

    report =
      case Report.by_id(id, actor: socket.assigns.current_user) do
        {:ok, report} ->
          report

        _ ->
          nil
      end

    socket =
      socket
      |> assign(active_tab: :reports)
      |> assign(:language, language)
      |> assign(:page_title, with_locale(language, fn -> gettext("Report") end))
      |> assign(:report, report)

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
       |> push_navigate(to: "/auth/user/sign-out?auto_log_out=#{current_user.state}")}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @report do %>
        <.report_show_card language={@language} report={@report} current_user={@current_user} />
      <% else %>
        <.no_report language={@language} />
      <% end %>
    </div>
    """
  end
end
