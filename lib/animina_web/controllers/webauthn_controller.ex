defmodule AniminaWeb.WebAuthnController do
  @moduledoc """
  Handles WebAuthn/passkey registration and authentication ceremonies.

  All endpoints exchange JSON and use the browser session for challenge storage.
  """

  use AniminaWeb, :controller

  @compile {:no_warn_undefined, Wax}

  alias Animina.Accounts
  alias Animina.ActivityLog
  alias AniminaWeb.UserAuth

  # --- Registration (authenticated user adding a passkey) ---

  @doc """
  Begins passkey registration: generates a challenge and returns options for
  navigator.credentials.create().
  """
  def register_begin(conn, _params) do
    user = conn.assigns.current_scope.user

    challenge = Wax.new_registration_challenge()

    # Existing credential IDs to exclude (prevent re-registration)
    existing = Accounts.list_user_passkeys(user)

    exclude_credentials =
      Enum.map(existing, fn pk ->
        %{type: "public-key", id: Base.url_encode64(pk.credential_id, padding: false)}
      end)

    conn
    |> put_session(:webauthn_challenge, challenge)
    |> json(%{
      challenge: Base.url_encode64(challenge.bytes, padding: false),
      rp: %{id: challenge.rp_id, name: "ANIMINA"},
      user: %{
        id: Base.url_encode64(user.id, padding: false),
        name: user.email,
        displayName: user.display_name
      },
      pubKeyCredParams: [
        %{type: "public-key", alg: -7},
        %{type: "public-key", alg: -257}
      ],
      authenticatorSelection: %{
        residentKey: "preferred",
        userVerification: "preferred"
      },
      attestation: "none",
      excludeCredentials: exclude_credentials,
      timeout: 120_000
    })
  end

  @doc """
  Completes passkey registration: verifies the attestation and stores the credential.
  """
  def register_complete(conn, params) do
    user = conn.assigns.current_scope.user
    challenge = get_session(conn, :webauthn_challenge)

    if is_nil(challenge) do
      conn |> put_status(400) |> json(%{error: "No registration challenge in session"})
    else
      attestation_object = Base.url_decode64!(params["attestation_object"], padding: false)
      client_data_json = Base.url_decode64!(params["client_data_json"], padding: false)

      case Wax.register(attestation_object, client_data_json, challenge) do
        {:ok, {auth_data, _attestation_result}} ->
          credential_id = auth_data.attested_credential_data.credential_id
          cose_key = auth_data.attested_credential_data.credential_public_key

          attrs = %{
            credential_id: credential_id,
            public_key: cose_key,
            sign_count: auth_data.sign_count,
            label: params["label"]
          }

          save_passkey(conn, user, attrs)

        {:error, error} ->
          conn
          |> delete_session(:webauthn_challenge)
          |> put_status(400)
          |> json(%{error: Exception.message(error)})
      end
    end
  end

  # --- Authentication (logging in with a passkey) ---

  @doc """
  Begins passkey authentication: generates a challenge for discoverable credentials.
  No email required — the authenticator provides the credential.
  """
  def auth_begin(conn, _params) do
    challenge = Wax.new_authentication_challenge()

    conn
    |> put_session(:webauthn_challenge, challenge)
    |> json(%{
      challenge: Base.url_encode64(challenge.bytes, padding: false),
      rpId: challenge.rp_id,
      userVerification: "preferred",
      timeout: 120_000
    })
  end

  @doc """
  Completes passkey authentication: verifies the assertion and creates a session.
  """
  def auth_complete(conn, params) do
    challenge = get_session(conn, :webauthn_challenge)

    if is_nil(challenge) do
      conn |> put_status(400) |> json(%{error: "No authentication challenge in session"})
    else
      with {:ok, credential_id} <-
             decode_b64(params["credential_id"]),
           {:ok, authenticator_data} <-
             decode_b64(params["authenticator_data"]),
           {:ok, signature} <-
             decode_b64(params["signature"]),
           {:ok, client_data_json} <-
             decode_b64(params["client_data_json"]),
           {user, passkey} <-
             lookup_credential(credential_id),
           :ok <-
             verify_sudo_user(conn, user) do
        conn
        |> maybe_set_sudo_return_to(params)
        |> verify_and_login(
          credential_id,
          authenticator_data,
          signature,
          client_data_json,
          challenge,
          user,
          passkey
        )
      else
        nil ->
          conn
          |> delete_session(:webauthn_challenge)
          |> put_status(401)
          |> json(%{error: gettext("Passkey not recognized. Please try again or use password.")})

        :sudo_mismatch ->
          conn
          |> delete_session(:webauthn_challenge)
          |> put_status(403)
          |> json(%{
            error: gettext("This passkey does not belong to your account.")
          })

        {:error, reason} ->
          conn
          |> delete_session(:webauthn_challenge)
          |> put_status(400)
          |> json(%{error: "Invalid request: #{reason}"})
      end
    end
  end

  # --- Helpers ---

  defp save_passkey(conn, user, attrs) do
    case Accounts.create_user_passkey(user, attrs) do
      {:ok, passkey} ->
        conn
        |> delete_session(:webauthn_challenge)
        |> json(%{ok: true, id: passkey.id, label: passkey.label})

      {:error, changeset} ->
        conn
        |> delete_session(:webauthn_challenge)
        |> put_status(422)
        |> json(%{error: format_changeset_errors(changeset)})
    end
  end

  defp verify_and_login(
         conn,
         credential_id,
         authenticator_data,
         signature,
         client_data_json,
         challenge,
         user,
         passkey
       ) do
    credentials = [{passkey.credential_id, passkey.public_key}]

    case Wax.authenticate(
           credential_id,
           authenticator_data,
           signature,
           client_data_json,
           challenge,
           credentials
         ) do
      {:ok, auth_data} ->
        Accounts.update_passkey_after_auth(passkey, auth_data.sign_count)

        ActivityLog.log("auth", "login_passkey", "#{user.display_name} logged in via passkey",
          actor_id: user.id,
          metadata: conn_metadata(conn)
        )

        conn
        |> delete_session(:webauthn_challenge)
        |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

      {:error, error} ->
        ActivityLog.log("auth", "login_failed", "Failed passkey authentication",
          metadata: Map.put(conn_metadata(conn), "error", Exception.message(error))
        )

        conn
        |> delete_session(:webauthn_challenge)
        |> put_status(401)
        |> json(%{error: Exception.message(error)})
    end
  end

  # During sudo mode, verify the passkey belongs to the currently logged-in user
  defp verify_sudo_user(%{assigns: %{current_scope: %{user: %{id: session_user_id}}}}, user) do
    if user.id == session_user_id, do: :ok, else: :sudo_mismatch
  end

  defp verify_sudo_user(_conn, _user), do: :ok

  # Set user_return_to from sudo_return_to param (validates path starts with "/")
  defp maybe_set_sudo_return_to(conn, %{"sudo_return_to" => "/" <> _ = return_to}) do
    put_session(conn, :user_return_to, return_to)
  end

  defp maybe_set_sudo_return_to(conn, _params), do: conn

  defp decode_b64(nil), do: {:error, "missing parameter"}

  defp decode_b64(value) do
    case Base.url_decode64(value, padding: false) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, "invalid base64url encoding"}
    end
  end

  defp lookup_credential(credential_id) do
    Accounts.get_user_by_passkey_credential_id(credential_id)
  end

  defp conn_metadata(conn) do
    ua =
      case Plug.Conn.get_req_header(conn, "user-agent") do
        [ua | _] -> ua
        _ -> nil
      end

    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    %{"user_agent" => ua, "ip_address" => ip}
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join(", ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
  end
end
