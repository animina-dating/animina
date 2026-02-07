defmodule AniminaWeb.WebAuthnControllerTest do
  use AniminaWeb.ConnCase, async: true

  setup :register_and_log_in_user

  describe "POST /webauthn/register/begin" do
    test "returns challenge and options for authenticated user", %{conn: conn} do
      conn = post(conn, ~p"/webauthn/register/begin")
      body = json_response(conn, 200)

      assert is_binary(body["challenge"])
      assert body["rp"]["name"] == "ANIMINA"
      assert body["rp"]["id"] == "localhost"
      assert is_binary(body["user"]["id"])
      assert is_binary(body["user"]["name"])
      assert is_binary(body["user"]["displayName"])
      assert is_list(body["pubKeyCredParams"])
      assert body["attestation"] == "none"
      assert is_list(body["excludeCredentials"])
    end

    test "excludes existing passkeys", %{conn: conn, user: user} do
      # Register a passkey directly
      {:ok, _} =
        Animina.Accounts.create_user_passkey(user, %{
          credential_id: :crypto.strong_rand_bytes(32),
          public_key: %{1 => 2, 3 => -7}
        })

      conn = post(conn, ~p"/webauthn/register/begin")
      body = json_response(conn, 200)

      assert length(body["excludeCredentials"]) == 1
    end
  end

  describe "POST /webauthn/register/complete" do
    test "returns error when no challenge in session", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webauthn/register/complete", %{
          attestation_object: "dGVzdA",
          client_data_json: "dGVzdA"
        })

      body = json_response(conn, 400)
      assert body["error"] =~ "No registration challenge"
    end
  end

  describe "POST /webauthn/auth/begin (public)" do
    test "returns challenge for unauthenticated user" do
      conn = build_conn()
      conn = post(conn, ~p"/webauthn/auth/begin")
      body = json_response(conn, 200)

      assert is_binary(body["challenge"])
      assert body["rpId"] == "localhost"
      assert body["userVerification"] == "preferred"
    end
  end

  describe "POST /webauthn/auth/complete (public)" do
    test "returns error when no challenge in session" do
      conn = build_conn()

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webauthn/auth/complete", %{
          credential_id: "dGVzdA",
          authenticator_data: "dGVzdA",
          signature: "dGVzdA",
          client_data_json: "dGVzdA"
        })

      body = json_response(conn, 400)
      assert body["error"] =~ "No authentication challenge"
    end
  end

  describe "POST /webauthn/register/begin (unauthenticated)" do
    test "redirects to login page" do
      conn = build_conn()
      conn = post(conn, ~p"/webauthn/register/begin")

      assert redirected_to(conn) =~ ~p"/users/log-in"
    end
  end
end
