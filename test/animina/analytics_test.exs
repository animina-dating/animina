defmodule Animina.AnalyticsTest do
  use Animina.DataCase, async: false

  alias Animina.Analytics
  alias Animina.Analytics.DailyFunnelStat
  alias Animina.Analytics.DailyPageStat
  alias Animina.Analytics.PageView

  import Animina.AccountsFixtures

  # Clean up any stale page views leaked by Task.start in AnalyticsHook
  setup do
    Repo.delete_all(PageView)
    Repo.delete_all(DailyPageStat)
    Repo.delete_all(DailyFunnelStat)
    :ok
  end

  describe "record_page_view/1" do
    test "inserts a page view" do
      session_id = Ecto.UUID.generate()

      assert {:ok, pv} =
               Analytics.record_page_view(%{
                 session_id: session_id,
                 path: "/discover"
               })

      assert pv.session_id == session_id
      assert pv.path == "/discover"
      assert pv.inserted_at != nil
    end

    test "inserts a page view with user_id and referrer" do
      user = user_fixture()
      session_id = Ecto.UUID.generate()

      assert {:ok, pv} =
               Analytics.record_page_view(%{
                 session_id: session_id,
                 path: "/my/messages",
                 referrer_path: "/my",
                 user_id: user.id
               })

      assert pv.user_id == user.id
      assert pv.referrer_path == "/my"
    end

    test "fails without required fields" do
      assert {:error, _changeset} = Analytics.record_page_view(%{})
    end
  end

  describe "real-time queries" do
    setup do
      session_id = Ecto.UUID.generate()
      user = user_fixture()

      # Insert some page views for today
      for path <- ["/discover", "/discover", "/my/messages"] do
        Analytics.record_page_view(%{
          session_id: session_id,
          path: path,
          user_id: user.id
        })
      end

      # Another session
      session_id2 = Ecto.UUID.generate()

      Analytics.record_page_view(%{
        session_id: session_id2,
        path: "/discover"
      })

      %{session_id: session_id, user: user}
    end

    test "today_stats/0 returns page views, sessions, and users" do
      stats = Analytics.today_stats()
      assert stats.page_views == 4
      assert stats.unique_sessions == 2
      assert stats.unique_users == 1
    end

    test "page_view_count_today/0 counts all views" do
      assert Analytics.page_view_count_today() == 4
    end

    test "top_pages_today/1 ranks pages by views" do
      top = Analytics.top_pages_today(10)
      assert hd(top).path == "/discover"
      assert hd(top).views == 3
    end
  end

  # rollup functions interpret dates as Berlin timezone, so we must
  # use the current Berlin date (not UTC) to match recorded page views
  defp berlin_today do
    DateTime.utc_now()
    |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)
    |> DateTime.to_date()
  end

  describe "rollup_page_stats/1" do
    test "aggregates page views into daily stats" do
      session_id = Ecto.UUID.generate()
      today = berlin_today()

      for path <- ["/discover", "/discover", "/my"] do
        Analytics.record_page_view(%{session_id: session_id, path: path})
      end

      assert {:ok, 2} = Analytics.rollup_page_stats(today)

      stats = Repo.all(DailyPageStat)
      assert length(stats) == 2

      discover_stat = Enum.find(stats, &(&1.path == "/discover"))
      assert discover_stat.view_count == 2
      assert discover_stat.unique_sessions == 1
    end

    test "is idempotent — re-running replaces existing data" do
      session_id = Ecto.UUID.generate()
      today = berlin_today()

      Analytics.record_page_view(%{session_id: session_id, path: "/test"})

      assert {:ok, 1} = Analytics.rollup_page_stats(today)
      assert {:ok, 1} = Analytics.rollup_page_stats(today)

      assert Repo.aggregate(DailyPageStat, :count) == 1
    end
  end

  describe "rollup_funnel_stats/1" do
    test "creates a funnel stat row" do
      session_id = Ecto.UUID.generate()
      today = berlin_today()

      Analytics.record_page_view(%{session_id: session_id, path: "/"})

      assert :ok = Analytics.rollup_funnel_stats(today)

      [stat] = Repo.all(DailyFunnelStat)
      assert stat.date == today
      assert stat.visitors == 1
    end
  end

  describe "purge_old_page_views/1" do
    test "deletes page views older than specified days" do
      session_id = Ecto.UUID.generate()

      # Insert a page view with a very old timestamp
      old_time = DateTime.add(DateTime.utc_now(), -100, :day)

      %PageView{}
      |> Ecto.Changeset.change(%{
        session_id: session_id,
        path: "/old",
        inserted_at: DateTime.truncate(old_time, :second)
      })
      |> Repo.insert!()

      # Insert a recent one
      Analytics.record_page_view(%{session_id: session_id, path: "/new"})

      assert {:ok, 1} = Analytics.purge_old_page_views(90)
      assert Repo.aggregate(PageView, :count) == 1
    end
  end

  describe "daily_totals/1" do
    test "returns empty list when no data" do
      assert Analytics.daily_totals(30) == []
    end

    test "returns aggregated data from rollup tables" do
      today = Date.utc_today()

      %DailyPageStat{}
      |> DailyPageStat.changeset(%{
        date: today,
        path: "/a",
        view_count: 10,
        unique_sessions: 5,
        unique_users: 3
      })
      |> Repo.insert!()

      %DailyPageStat{}
      |> DailyPageStat.changeset(%{
        date: today,
        path: "/b",
        view_count: 5,
        unique_sessions: 3,
        unique_users: 2
      })
      |> Repo.insert!()

      [row] = Analytics.daily_totals(30)
      assert row.date == today
      assert row.view_count == 15
    end
  end

  describe "funnel_totals/1" do
    test "returns zeros when no data" do
      totals = Analytics.funnel_totals(30)
      assert totals.visitors == 0
      assert totals.registered == 0
    end
  end

  describe "feature_engagement/1" do
    test "returns empty list when no activity" do
      assert Analytics.feature_engagement(30) == []
    end
  end
end
