defmodule AniminaWeb.UserAuth do
  @moduledoc """
  Handles user authentication, session management, and scope-based access control.
  """

  use AniminaWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller
  use Gettext, backend: AniminaWeb.Gettext

  alias Animina.Accounts
  alias Animina.Accounts.Scope
  alias AniminaWeb.Plugs.SetLocale

  # Date after which users must re-accept the ToS (AI features update).
  @tos_updated_at ~U[2026-02-13 00:00:00Z]

  # Make the remember me cookie valid for 14 days. This should match
  # the session validity setting in UserToken.
  @max_cookie_age_in_days 14
  @remember_me_cookie "_animina_web_user_remember_me"
  @remember_me_options [
    sign: true,
    max_age: @max_cookie_age_in_days * 24 * 60 * 60,
    same_site: "Lax"
  ]

  # How old the session token should be before a new one is issued. When a request is made
  # with a session token older than this value, then a new session token will be created
  # and the session and remember-me cookies (if set) will be updated with the new token.
  # Lowering this value will result in more tokens being created by active users. Increasing
  # it will result in less time before a session token expires for a user to get issued a new
  # token. This can be set to a value greater than `@max_cookie_age_in_days` to disable
  # the reissuing of tokens completely.
  @session_reissue_age_in_days 7

  @doc """
  Logs the user in.

  Redirects to the session's `:user_return_to` path
  or falls back to the `signed_in_path/1`.
  """
  def log_in_user(conn, user, params \\ %{}) do
    user_return_to = get_session(conn, :user_return_to)

    redirect_to =
      cond do
        needs_tos_acceptance?(user) -> ~p"/users/accept-terms"
        user_return_to -> user_return_to
        user.state == "waitlisted" -> ~p"/my/waitlist"
        true -> signed_in_path(conn)
      end

    conn
    |> create_or_extend_session(user, params)
    |> redirect(to: redirect_to)
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      AniminaWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session(nil)
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session and remember me token.

  Will reissue the session token if it is older than the configured age.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    with {token, conn} <- ensure_user_token(conn),
         {user, token_inserted_at} <- Accounts.get_user_by_session_token(token),
         false <- Accounts.user_deleted?(user) do
      # Auto-unsuspend if suspension has expired
      user = Animina.Reports.maybe_unsuspend(user)
      authenticate_active_user(conn, user, token, token_inserted_at)
    else
      true ->
        # User is soft-deleted, clear session
        conn
        |> delete_session(:user_token)
        |> assign(:current_scope, Scope.for_user(nil))

      nil ->
        assign(conn, :current_scope, Scope.for_user(nil))
    end
  end

  defp authenticate_active_user(conn, %{state: "banned"} = _user, _token, _token_inserted_at) do
    user_token = get_session(conn, :user_token)
    if user_token, do: Accounts.delete_user_session_token(user_token)

    conn
    |> delete_session(:user_token)
    |> assign(:current_scope, Scope.for_user(nil))
  end

  defp authenticate_active_user(conn, user, token, token_inserted_at) do
    roles = Accounts.get_user_roles(user)
    session_role = get_session(conn, :current_role)
    effective_role = auto_role_for_path(conn.request_path, roles, session_role)
    scope = Scope.for_user(user, roles, effective_role)

    # Update last_seen_at (throttled to every 5 min, very fast update_all)
    Accounts.maybe_update_last_seen(token)

    conn =
      if effective_role != session_role do
        put_session(conn, :current_role, effective_role)
      else
        conn
      end

    conn
    |> assign(:current_scope, scope)
    |> maybe_reissue_user_session_token(user, token_inserted_at)
  end

  # Determines the effective role based on the URL path.
  # Auto-switches to "admin" for /admin/* paths if the user has the admin role,
  # and to "user" for /my/* paths if the user has multiple roles.
  defp auto_role_for_path("/admin" <> _, roles, _session_role) do
    if "admin" in roles, do: "admin", else: "user"
  end

  defp auto_role_for_path("/my" <> _, _roles, _session_role), do: "user"

  defp auto_role_for_path(_path, _roles, session_role), do: session_role

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, conn |> put_token_in_session(token) |> put_session(:user_remember_me, true)}
      else
        nil
      end
    end
  end

  # Reissue the session token if it is older than the configured reissue age.
  defp maybe_reissue_user_session_token(conn, user, token_inserted_at) do
    token_age = DateTime.diff(DateTime.utc_now(:second), token_inserted_at, :day)

    if token_age >= @session_reissue_age_in_days do
      create_or_extend_session(conn, user, %{})
    else
      conn
    end
  end

  # This function is the one responsible for creating session tokens
  # and storing them safely in the session and cookies. It may be called
  # either when logging in, during sudo mode, or to renew a session which
  # will soon expire.
  #
  # When the session is created, rather than extended, the renew_session
  # function will clear the session to avoid fixation attacks. See the
  # renew_session function to customize this behaviour.
  defp create_or_extend_session(conn, user, params) do
    # Delete the old session token to prevent stale sessions from accumulating
    # (e.g. from sudo re-auth or token reissue on the same browser)
    old_token = get_session(conn, :user_token)
    if old_token, do: Accounts.delete_user_session_token(old_token)

    conn_info = extract_conn_info(conn)
    token = Accounts.generate_user_session_token(user, conn_info)
    remember_me = get_session(conn, :user_remember_me)

    conn
    |> renew_session(user)
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params, remember_me)
  end

  defp extract_conn_info(conn) do
    user_agent =
      case get_req_header(conn, "user-agent") do
        [ua | _] -> ua
        _ -> nil
      end

    ip_address =
      conn.remote_ip
      |> :inet.ntoa()
      |> to_string()

    %{user_agent: user_agent, ip_address: ip_address}
  end

  # Do not renew session if the user is already logged in
  # to prevent CSRF errors or data being lost in tabs that are still open
  defp renew_session(conn, user) when conn.assigns.current_scope.user.id == user.id do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  defp renew_session(conn, _user) do
    delete_csrf_token()
    locale = get_session(conn, :locale)
    current_role = get_session(conn, :current_role)

    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> put_session(:locale, locale)
    |> put_session(:current_role, current_role)
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}, _),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, token, _params, true),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, _token, _params, _), do: conn

  defp write_remember_me_cookie(conn, token) do
    conn
    |> put_session(:user_remember_me, true)
    |> put_resp_cookie(@remember_me_cookie, token, @remember_me_options)
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, user_session_topic(token))
  end

  @doc """
  Disconnects existing sockets for the given tokens.
  """
  def disconnect_sessions(tokens) do
    Enum.each(tokens, fn %{token: token} ->
      AniminaWeb.Endpoint.broadcast(user_session_topic(token), "disconnect", %{})
    end)
  end

  defp user_session_topic(token), do: "users_sessions:#{Base.url_encode64(token)}"

  @doc """
  Handles mounting and authenticating the current_scope in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_scope` - Assigns current_scope
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:require_authenticated` - Authenticates the user from the session,
      and assigns the current_scope to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the `current_scope`:

      defmodule AniminaWeb.PageLive do
        use AniminaWeb, :live_view

        on_mount {AniminaWeb.UserAuth, :mount_current_scope}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{AniminaWeb.UserAuth, :require_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if match?(%{current_scope: %{user: %_{}}}, socket.assigns) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, gettext("You must log in to access this page."))
        |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")

      {:halt, socket}
    end
  end

  def on_mount(:require_authenticated_with_tos, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    cond do
      not match?(%{current_scope: %{user: %_{}}}, socket.assigns) ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, gettext("You must log in to access this page."))
          |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")

        {:halt, socket}

      needs_tos_acceptance?(socket.assigns.current_scope.user) ->
        socket = Phoenix.LiveView.redirect(socket, to: ~p"/users/accept-terms")
        {:halt, socket}

      true ->
        {:cont, socket}
    end
  end

  def on_mount(:require_admin, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    scope = socket.assigns.current_scope

    cond do
      Scope.admin?(scope) ->
        {:cont, socket}

      Scope.has_role?(scope, "admin") ->
        updated_scope = %{scope | current_role: "admin"}
        {:cont, Phoenix.Component.assign(socket, :current_scope, updated_scope)}

      true ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            gettext("You are not authorized to access this page.")
          )
          |> Phoenix.LiveView.redirect(to: ~p"/")

        {:halt, socket}
    end
  end

  def on_mount(:require_moderator, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    scope = socket.assigns.current_scope

    cond do
      Scope.moderator?(scope) ->
        {:cont, socket}

      Scope.has_role?(scope, "admin") ->
        updated_scope = %{scope | current_role: "admin"}
        {:cont, Phoenix.Component.assign(socket, :current_scope, updated_scope)}

      Scope.has_role?(scope, "moderator") ->
        updated_scope = %{scope | current_role: "moderator"}
        {:cont, Phoenix.Component.assign(socket, :current_scope, updated_scope)}

      true ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            gettext("You are not authorized to access this page.")
          )
          |> Phoenix.LiveView.redirect(to: ~p"/")

        {:halt, socket}
    end
  end

  def on_mount(:require_sudo_mode, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if Accounts.sudo_mode?(socket.assigns.current_scope.user, -10) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :error,
          gettext("You must re-authenticate to access this page.")
        )
        |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")

      {:halt, socket}
    end
  end

  def on_mount({:require_sudo_mode, return_to}, _params, session, socket)
      when is_binary(return_to) do
    socket = mount_current_scope(socket, session)

    if Accounts.sudo_mode?(socket.assigns.current_scope.user, -10) do
      {:cont, socket}
    else
      redirect_url = ~p"/users/log-in" <> "?sudo_return_to=#{URI.encode_www_form(return_to)}"

      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :error,
          gettext("You must re-authenticate to access this page.")
        )
        |> Phoenix.LiveView.redirect(to: redirect_url)

      {:halt, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    user_token = session["user_token"]

    socket =
      Phoenix.Component.assign_new(socket, :current_scope, fn ->
        {user, _} =
          if user_token do
            Accounts.get_user_by_session_token(user_token)
          end || {nil, nil}

        if user do
          roles = Accounts.get_user_roles(user)
          session_role = session["current_role"]
          Scope.for_user(user, roles, session_role)
        else
          Scope.for_user(nil)
        end
      end)

    # Redirect suspended/banned users to the suspended page (unless already there)
    socket = maybe_redirect_suspended(socket)

    socket = Phoenix.Component.assign(socket, :current_session_token, user_token)

    default_locale =
      Application.get_env(:animina, AniminaWeb.Gettext, [])
      |> Keyword.get(:default_locale, "de")

    user_language =
      case socket.assigns.current_scope do
        %{user: %{language: lang}} when is_binary(lang) -> lang
        _ -> nil
      end

    candidate = user_language || session["locale"] || default_locale

    locale =
      if candidate in SetLocale.supported_locales(),
        do: candidate,
        else: default_locale

    Gettext.put_locale(AniminaWeb.Gettext, locale)

    socket
    |> Phoenix.Component.assign(:locale, locale)
    |> subscribe_to_deployment_notifications()
    |> maybe_track_presence()
    |> maybe_subscribe_messages()
  end

  defp maybe_redirect_suspended(socket) do
    case socket.assigns do
      %{current_scope: %{user: %{state: state}}}
      when state in ["suspended", "banned"] ->
        view = socket.private[:live_view_module]

        if view != AniminaWeb.UserLive.AccountSuspended do
          Phoenix.LiveView.redirect(socket, to: ~p"/my/suspended")
        else
          socket
        end

      _ ->
        socket
    end
  end

  defp subscribe_to_deployment_notifications(socket) do
    if Phoenix.LiveView.connected?(socket) && !socket.assigns[:deployment_subscribed] do
      Phoenix.PubSub.subscribe(Animina.PubSub, Animina.Deployment.topic())

      socket
      |> Phoenix.Component.assign(:deployment_subscribed, true)
      |> Phoenix.LiveView.attach_hook(:deployment_notice, :handle_info, fn
        {:deploying, version}, sock ->
          {:halt, Phoenix.LiveView.push_event(sock, "deployment-starting", %{version: version})}

        _other, sock ->
          {:cont, sock}
      end)
    else
      socket
    end
  end

  defp maybe_track_presence(socket) do
    with true <- Phoenix.LiveView.connected?(socket),
         false <- !!socket.assigns[:presence_tracked],
         %{user: %_{id: user_id}} <- socket.assigns[:current_scope] do
      AniminaWeb.Presence.track_user(self(), user_id)
      Phoenix.PubSub.subscribe(Animina.PubSub, AniminaWeb.Presence.topic())

      socket
      |> Phoenix.Component.assign(:presence_tracked, true)
      |> Phoenix.LiveView.attach_hook(:presence_diff, :handle_info, fn
        %Phoenix.Socket.Broadcast{event: "presence_diff"}, sock ->
          maybe_refresh_online_count(sock)
          {:halt, sock}

        _other, sock ->
          {:cont, sock}
      end)
    else
      _ -> socket
    end
  end

  defp maybe_refresh_online_count(sock) do
    if sock.assigns[:current_scope] && Scope.admin?(sock.assigns[:current_scope]) do
      Phoenix.LiveView.send_update(AniminaWeb.LiveOnlineCountComponent, id: "online-count")
    end
  end

  defp maybe_subscribe_messages(socket) do
    with true <- Phoenix.LiveView.connected?(socket),
         false <- !!socket.assigns[:messages_subscribed],
         %{user: %_{id: user_id}} <- socket.assigns[:current_scope] do
      Phoenix.PubSub.subscribe(Animina.PubSub, Animina.Messaging.user_topic(user_id))

      socket
      |> Phoenix.Component.assign(:messages_subscribed, true)
      |> Phoenix.LiveView.attach_hook(:unread_badge, :handle_info, fn
        {:unread_count_changed, _count}, sock ->
          Phoenix.LiveView.send_update(AniminaWeb.LiveUnreadBadgeComponent,
            id: "unread-badge",
            user_id: user_id
          )

          {:cont, sock}

        {:new_message, _conv_id, _msg}, sock ->
          Phoenix.LiveView.send_update(AniminaWeb.LiveUnreadBadgeComponent,
            id: "unread-badge",
            user_id: user_id
          )

          {:cont, sock}

        _other, sock ->
          {:cont, sock}
      end)
    else
      _ -> socket
    end
  end

  defp needs_tos_acceptance?(user) do
    is_nil(user.tos_accepted_at) or
      DateTime.compare(user.tos_accepted_at, @tos_updated_at) == :lt
  end

  @doc "Returns the path to redirect to after log in."
  # the user was already logged in, redirect to settings
  def signed_in_path(%Plug.Conn{assigns: %{current_scope: %Scope{user: %Accounts.User{}}}}) do
    ~p"/my/settings"
  end

  def signed_in_path(_), do: ~p"/"

  @doc """
  Plug for routes that require the user to be authenticated.
  """
  def require_authenticated_user(conn, _opts) do
    if match?(%{current_scope: %{user: %_{}}}, conn.assigns) do
      conn
    else
      conn
      |> put_flash(:error, gettext("You must log in to access this page."))
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn
end
