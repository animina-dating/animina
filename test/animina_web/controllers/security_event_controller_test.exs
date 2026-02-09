defmodule AniminaWeb.SecurityEventControllerTest do
  use AniminaWeb.ConnCase, async: true

  alias Animina.Accounts

  import Animina.AccountsFixtures

  describe "undo" do
    test "undoes an email change and redirects to login", %{conn: conn} do
      user = user_fixture(language: "en")
      old_email = user.email
      new_email = unique_user_email()

      # Simulate email change
      user
      |> Ecto.Changeset.change(email: new_email)
      |> Animina.Repo.update!()

      {:ok, security_info} =
        Accounts.create_security_event_for_email_change(user, old_email, new_email)

      conn = get(conn, ~p"/users/security/undo/#{security_info.undo_token}")
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "undone"

      # Email should be reverted
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.email == old_email
    end

    test "undoes a password change", %{conn: conn} do
      user = user_fixture(language: "en")
      old_hash = user.hashed_password

      user
      |> Ecto.Changeset.change(hashed_password: "changed_hash")
      |> Animina.Repo.update!()

      {:ok, security_info} =
        Accounts.create_security_event_for_password_change(user, old_hash)

      conn = get(conn, ~p"/users/security/undo/#{security_info.undo_token}")
      assert redirected_to(conn) == ~p"/users/log-in"

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.hashed_password == old_hash
    end

    test "shows error for invalid token", %{conn: conn} do
      conn = get(conn, ~p"/users/security/undo/invalid_token_here")
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid"
    end
  end

  describe "confirm" do
    test "confirms a security event and clears cooldown", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, security_info} =
        Accounts.create_security_event_for_email_change(user, user.email, "new@test.com")

      assert Accounts.has_active_security_cooldown?(user.id)

      conn = get(conn, ~p"/users/security/confirm/#{security_info.confirm_token}")
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "confirmed"

      refute Accounts.has_active_security_cooldown?(user.id)
    end

    test "shows error for invalid token", %{conn: conn} do
      conn = get(conn, ~p"/users/security/confirm/invalid_token_here")
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid"
    end
  end
end
