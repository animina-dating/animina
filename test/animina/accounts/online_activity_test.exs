defmodule Animina.Accounts.OnlineActivityTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.OnlineActivity
  alias Animina.Accounts.UserOnlineSession
  alias Animina.Repo

  import Animina.AccountsFixtures

  describe "last_seen/1" do
    test "returns :online when user has an open session" do
      user = user_fixture()
      insert_session(user.id, hours_ago: 1, open: true)

      assert OnlineActivity.last_seen(user.id) == :online
    end

    test "returns the latest ended_at when all sessions are closed" do
      user = user_fixture()
      insert_session(user.id, hours_ago: 5, duration_minutes: 30)
      recent = insert_session(user.id, hours_ago: 1, duration_minutes: 15)

      result = OnlineActivity.last_seen(user.id)
      assert result == recent.ended_at
    end

    test "returns nil when user has no sessions" do
      user = user_fixture()
      assert OnlineActivity.last_seen(user.id) == nil
    end
  end

  describe "activity_level/1" do
    test "returns :inactive when user has no sessions" do
      user = user_fixture()
      assert OnlineActivity.activity_level(user.id) == :inactive
    end

    test "returns :daily when user is online most days" do
      user = user_fixture()

      # Insert sessions for 28 of the last 30 days
      for day <- 0..27 do
        insert_session(user.id, days_ago: day, duration_minutes: 10)
      end

      assert OnlineActivity.activity_level(user.id) == :daily
    end

    test "returns :rarely when user has few sessions" do
      user = user_fixture()

      # Only 2 sessions in 30 days
      insert_session(user.id, days_ago: 5, duration_minutes: 10)
      insert_session(user.id, days_ago: 20, duration_minutes: 10)

      assert OnlineActivity.activity_level(user.id) == :rarely
    end

    test "returns :weekly when user has moderate sessions" do
      user = user_fixture()

      # 5 sessions in 30 days = ~17%
      for day <- [3, 8, 13, 18, 23] do
        insert_session(user.id, days_ago: day, duration_minutes: 10)
      end

      assert OnlineActivity.activity_level(user.id) == :weekly
    end
  end

  describe "typical_online_times/1" do
    test "returns empty list when insufficient data" do
      user = user_fixture()
      assert OnlineActivity.typical_online_times(user.id) == []
    end

    test "returns empty list when less than 30 minutes of data" do
      user = user_fixture()
      insert_session(user.id, hours_ago: 2, duration_minutes: 10)
      assert OnlineActivity.typical_online_times(user.id) == []
    end

    test "identifies dominant time block" do
      user = user_fixture()

      # Insert sessions concentrated in the evening (18-24 Berlin time)
      # We need UTC times that map to Berlin evening hours
      # Berlin is UTC+1 (winter) or UTC+2 (summer)
      # For evening 19:00 Berlin = 18:00 UTC (winter) or 17:00 UTC (summer)
      # Create enough data (>30 min) in evening hours
      for day <- 0..5 do
        insert_session_at_utc_hour(user.id, day, 17, duration_minutes: 60)
      end

      result = OnlineActivity.typical_online_times(user.id)
      assert is_list(result)
      assert result != []
    end
  end

  describe "purge_old_sessions/1" do
    test "deletes old closed sessions" do
      user = user_fixture()

      # Old closed session (100 days ago)
      old = insert_session(user.id, days_ago: 100, duration_minutes: 30)

      # Recent closed session
      recent = insert_session(user.id, days_ago: 5, duration_minutes: 30)

      # Open session (should never be purged)
      open = insert_session(user.id, hours_ago: 1, open: true)

      {count, _} = OnlineActivity.purge_old_sessions(90)
      assert count == 1

      assert Repo.get(UserOnlineSession, old.id) == nil
      assert Repo.get(UserOnlineSession, recent.id) != nil
      assert Repo.get(UserOnlineSession, open.id) != nil
    end

    test "keeps recent closed sessions" do
      user = user_fixture()
      recent = insert_session(user.id, days_ago: 10, duration_minutes: 30)

      {count, _} = OnlineActivity.purge_old_sessions(90)
      assert count == 0
      assert Repo.get(UserOnlineSession, recent.id) != nil
    end
  end

  describe "label helpers" do
    test "activity_level_label returns translated strings" do
      assert OnlineActivity.activity_level_label(:daily) == "Online daily"
      assert OnlineActivity.activity_level_label(:most_days) == "Online most days"
      assert OnlineActivity.activity_level_label(:inactive) == nil
    end

    test "typical_times_label returns nil for empty list" do
      assert OnlineActivity.typical_times_label([]) == nil
    end

    test "typical_times_label returns formatted string" do
      result = OnlineActivity.typical_times_label([:evening])
      assert result =~ "evening"
    end
  end

  # Test helpers

  defp insert_session(user_id, opts) do
    open = Keyword.get(opts, :open, false)
    duration = Keyword.get(opts, :duration_minutes, 30)

    started_at =
      cond do
        Keyword.has_key?(opts, :hours_ago) ->
          DateTime.utc_now()
          |> DateTime.add(-Keyword.fetch!(opts, :hours_ago), :hour)
          |> DateTime.truncate(:second)

        Keyword.has_key?(opts, :days_ago) ->
          DateTime.utc_now()
          |> DateTime.add(-Keyword.fetch!(opts, :days_ago), :day)
          |> DateTime.truncate(:second)
      end

    ended_at =
      if open do
        nil
      else
        DateTime.add(started_at, duration, :minute)
      end

    duration_val = if open, do: nil, else: duration

    %UserOnlineSession{}
    |> Ecto.Changeset.change(%{
      user_id: user_id,
      started_at: started_at,
      ended_at: ended_at,
      duration_minutes: duration_val
    })
    |> Repo.insert!()
  end

  defp insert_session_at_utc_hour(user_id, days_ago, utc_hour, opts) do
    duration = Keyword.get(opts, :duration_minutes, 30)

    date = Date.add(Date.utc_today(), -days_ago)
    {:ok, started_at} = DateTime.new(date, Time.new!(utc_hour, 0, 0), "Etc/UTC")
    started_at = DateTime.truncate(started_at, :second)
    ended_at = DateTime.add(started_at, duration, :minute)

    %UserOnlineSession{}
    |> Ecto.Changeset.change(%{
      user_id: user_id,
      started_at: started_at,
      ended_at: ended_at,
      duration_minutes: duration
    })
    |> Repo.insert!()
  end
end
