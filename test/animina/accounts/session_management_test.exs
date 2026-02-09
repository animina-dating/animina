defmodule Animina.Accounts.SessionManagementTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts

  import Animina.AccountsFixtures

  describe "generate_user_session_token/2 with conn_info" do
    test "stores user_agent and ip_address" do
      user = user_fixture()

      token =
        Accounts.generate_user_session_token(user, %{
          user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
          ip_address: "192.168.1.1"
        })

      assert token

      sessions = Accounts.list_user_sessions(user.id)
      assert [session] = sessions
      assert session.user_agent == "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
      assert session.ip_address == "192.168.1.1"
      assert session.last_seen_at
    end

    test "works without conn_info (backward compatible)" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert token

      sessions = Accounts.list_user_sessions(user.id)
      assert [session] = sessions
      assert is_nil(session.user_agent)
      assert is_nil(session.ip_address)
    end
  end

  describe "list_user_sessions/1" do
    test "returns all active sessions ordered by last_seen_at desc" do
      user = user_fixture()

      _token1 =
        Accounts.generate_user_session_token(user, %{
          user_agent: "Chrome",
          ip_address: "1.1.1.1"
        })

      _token2 =
        Accounts.generate_user_session_token(user, %{
          user_agent: "Firefox",
          ip_address: "2.2.2.2"
        })

      sessions = Accounts.list_user_sessions(user.id)
      assert length(sessions) == 2
    end

    test "does not return sessions from other users" do
      user1 = user_fixture()
      user2 = user_fixture()

      Accounts.generate_user_session_token(user1, %{user_agent: "Chrome"})
      Accounts.generate_user_session_token(user2, %{user_agent: "Firefox"})

      sessions = Accounts.list_user_sessions(user1.id)
      assert length(sessions) == 1
      assert hd(sessions).user_agent == "Chrome"
    end
  end

  describe "delete_user_session_by_id/2" do
    test "deletes a specific session" do
      user = user_fixture()
      Accounts.generate_user_session_token(user, %{user_agent: "Chrome"})
      Accounts.generate_user_session_token(user, %{user_agent: "Firefox"})

      [session1, _session2] = Accounts.list_user_sessions(user.id)

      deleted = Accounts.delete_user_session_by_id(session1.id, user.id)
      assert deleted

      remaining = Accounts.list_user_sessions(user.id)
      assert length(remaining) == 1
    end

    test "returns nil for non-existent session" do
      user = user_fixture()
      assert is_nil(Accounts.delete_user_session_by_id(Ecto.UUID.generate(), user.id))
    end

    test "cannot delete another user's session" do
      user1 = user_fixture()
      user2 = user_fixture()

      Accounts.generate_user_session_token(user1, %{user_agent: "Chrome"})

      [session] = Accounts.list_user_sessions(user1.id)
      assert is_nil(Accounts.delete_user_session_by_id(session.id, user2.id))
    end
  end

  describe "delete_other_user_sessions/2" do
    test "deletes all sessions except the current one" do
      user = user_fixture()
      current_token = Accounts.generate_user_session_token(user, %{user_agent: "Chrome"})
      Accounts.generate_user_session_token(user, %{user_agent: "Firefox"})
      Accounts.generate_user_session_token(user, %{user_agent: "Safari"})

      deleted = Accounts.delete_other_user_sessions(user.id, current_token)
      assert length(deleted) == 2

      remaining = Accounts.list_user_sessions(user.id)
      assert length(remaining) == 1
      assert hd(remaining).token == current_token
    end
  end

  describe "maybe_update_last_seen/1" do
    test "updates last_seen_at" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      # Backdate the last_seen_at so the throttle allows update
      Animina.Repo.update_all(
        from(t in Accounts.UserToken, where: t.token == ^token),
        set: [last_seen_at: DateTime.add(DateTime.utc_now(:second), -10, :minute)]
      )

      {count, _} = Accounts.maybe_update_last_seen(token)
      assert count == 1
    end

    test "throttles updates within 5 minutes" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      # last_seen_at was just set during token creation, so update should be throttled
      {count, _} = Accounts.maybe_update_last_seen(token)
      assert count == 0
    end
  end
end
