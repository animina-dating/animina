defmodule AniminaWeb.UserLive.Waitlist do
  @moduledoc """
  Legacy route — redirects to MyHub which now handles waitlist content inline.
  """

  use AniminaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: ~p"/my")}
  end
end
