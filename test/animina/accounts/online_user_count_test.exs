defmodule OnlineUserCountTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts
  alias Animina.Accounts.OnlineUserCount
  alias Animina.Repo

  describe "record_online_user_count/1" do
    test "inserts a count record" do
      assert {:ok, record} = Accounts.record_online_user_count(5)
      assert record.count == 5
      assert record.recorded_at
    end
  end

  describe "online_user_counts_since/2" do
    test "returns empty list when no data exists" do
      since = DateTime.utc_now() |> DateTime.add(-24, :hour)
      assert Accounts.online_user_counts_since(since, 10) == []
    end

    test "returns aggregated data bucketed by interval" do
      now = DateTime.utc_now(:second)

      # Insert several records spread across time
      for i <- 0..5 do
        recorded_at = DateTime.add(now, -i * 5, :minute)

        %OnlineUserCount{}
        |> OnlineUserCount.changeset(%{count: 10 + i, recorded_at: recorded_at})
        |> Repo.insert!()
      end

      since = DateTime.add(now, -1, :hour)
      results = Accounts.online_user_counts_since(since, 10)

      assert [_ | _] = results

      Enum.each(results, fn %{bucket: bucket, avg_count: avg_count} ->
        assert %DateTime{} = bucket
        assert is_integer(avg_count)
        assert avg_count > 0
      end)
    end
  end

  describe "purge_old_online_user_counts/1" do
    test "deletes records older than specified days" do
      now = DateTime.utc_now(:second)
      old = DateTime.add(now, -31, :day)
      recent = DateTime.add(now, -1, :day)

      %OnlineUserCount{}
      |> OnlineUserCount.changeset(%{count: 5, recorded_at: old})
      |> Repo.insert!()

      %OnlineUserCount{}
      |> OnlineUserCount.changeset(%{count: 10, recorded_at: recent})
      |> Repo.insert!()

      {deleted, _} = Accounts.purge_old_online_user_counts(30)
      assert deleted == 1

      # Recent record should still exist
      since = DateTime.add(now, -2, :day)
      assert [_] = Accounts.online_user_counts_since(since, 60)
    end
  end
end
