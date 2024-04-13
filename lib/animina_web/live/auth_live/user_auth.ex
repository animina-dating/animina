defmodule AniminaWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in liveviews
  """

  alias AniminaWeb.Registration
  import Phoenix.Component

  use AniminaWeb, :verified_routes

  def on_mount(:live_user_optional, _params, session, socket) do
    if socket.assigns[:current_user] do
      current_user = Registration.get_current_user(session)

      {:cont,
       socket
       |> assign(:current_user, current_user)
       |> assign(:current_user_credit_points, current_user.credit_points)}
    else
      {:cont,
       socket
       |> assign(:current_user_credit_points, 0)
       |> assign(:current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, session, socket) do
    path =
      case Map.get(socket.private.connect_info, :request_path, nil) do
        nil ->
          "sign-in"

        path ->
          case Map.get(socket.private.connect_info, :query_string, nil) do
            nil ->
              "sign-in?redirect_to=" <> path

            "" ->
              "sign-in?redirect_to=" <> path

            query_string ->
              "sign-in?redirect_to=" <> path <> "?" <> query_string
          end
      end

    if socket.assigns[:current_user] do
      current_user = Registration.get_current_user(session)

      {:cont,
       socket
       |> assign(:current_user, current_user)
       |> assign(:current_user_credit_points, current_user.credit_points)}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/#{path}")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    else
      {:cont,
       socket
       |> assign(:current_user_credit_points, 0)
       |> assign(:current_user, nil)}
    end
  end
end
