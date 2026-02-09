defmodule Animina.Accounts.UserSessionTrackerTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.UserOnlineSession
  alias Animina.Accounts.UserSessionTracker
  alias Animina.Repo

  import Animina.AccountsFixtures
  import Ecto.Query

  describe "close_stale_sessions/0" do
    test "closes all open sessions" do
      user = user_fixture()

      # Create an open session
      started_at =
        DateTime.utc_now()
        |> DateTime.add(-2, :hour)
        |> DateTime.truncate(:second)

      %UserOnlineSession{}
      |> Ecto.Changeset.change(%{
        user_id: user.id,
        started_at: started_at,
        ended_at: nil,
        duration_minutes: nil
      })
      |> Repo.insert!()

      # Verify open session exists
      open_count =
        from(s in UserOnlineSession, where: is_nil(s.ended_at))
        |> Repo.aggregate(:count)

      assert open_count == 1

      # Close stale sessions
      UserSessionTracker.close_stale_sessions()

      # Verify all sessions are closed
      open_count =
        from(s in UserOnlineSession, where: is_nil(s.ended_at))
        |> Repo.aggregate(:count)

      assert open_count == 0

      # Verify duration was computed
      session =
        from(s in UserOnlineSession, where: s.user_id == ^user.id, limit: 1)
        |> Repo.one()

      assert session.ended_at != nil
      assert session.duration_minutes != nil
      assert session.duration_minutes >= 0
    end
  end
end
