defmodule Animina.Discovery.PopularityTest do
  use Animina.DataCase

  alias Animina.Discovery.Popularity
  alias Animina.Discovery.Schemas.{Inquiry, PopularityStat}
  alias Animina.Repo

  import Animina.AccountsFixtures

  describe "record_inquiry/2" do
    test "creates an inquiry record" do
      sender = user_fixture()
      receiver = user_fixture()

      assert {:ok, %Inquiry{}} = Popularity.record_inquiry(sender.id, receiver.id)
    end

    test "sets inquiry_date to today" do
      sender = user_fixture()
      receiver = user_fixture()

      {:ok, inquiry} = Popularity.record_inquiry(sender.id, receiver.id)

      assert inquiry.inquiry_date == Date.utc_today()
    end

    test "is idempotent - same pair only creates one record" do
      sender = user_fixture()
      receiver = user_fixture()

      assert {:ok, _} = Popularity.record_inquiry(sender.id, receiver.id)
      assert {:ok, _} = Popularity.record_inquiry(sender.id, receiver.id)

      # Should only have one inquiry for this pair
      count =
        Repo.aggregate(
          from(i in Inquiry, where: i.sender_id == ^sender.id and i.receiver_id == ^receiver.id),
          :count
        )

      assert count == 1
    end

    test "allows reverse direction (A->B and B->A are separate)" do
      user_a = user_fixture()
      user_b = user_fixture()

      assert {:ok, _} = Popularity.record_inquiry(user_a.id, user_b.id)
      assert {:ok, _} = Popularity.record_inquiry(user_b.id, user_a.id)

      # Should have two separate inquiry records
      count = Repo.aggregate(Inquiry, :count)
      assert count == 2
    end
  end

  describe "inquiry_exists?/2" do
    test "returns false when no inquiry exists" do
      sender = user_fixture()
      receiver = user_fixture()

      refute Popularity.inquiry_exists?(sender.id, receiver.id)
    end

    test "returns true after recording an inquiry" do
      sender = user_fixture()
      receiver = user_fixture()

      Popularity.record_inquiry(sender.id, receiver.id)

      assert Popularity.inquiry_exists?(sender.id, receiver.id)
    end

    test "is directional - A->B does not imply B->A" do
      sender = user_fixture()
      receiver = user_fixture()

      Popularity.record_inquiry(sender.id, receiver.id)

      assert Popularity.inquiry_exists?(sender.id, receiver.id)
      refute Popularity.inquiry_exists?(receiver.id, sender.id)
    end
  end

  describe "get_daily_count/2" do
    test "returns 0 when no inquiries received today" do
      user = user_fixture()

      assert Popularity.get_daily_count(user.id, Date.utc_today()) == 0
    end

    test "counts inquiries received today" do
      receiver = user_fixture()
      sender1 = user_fixture()
      sender2 = user_fixture()
      sender3 = user_fixture()

      Popularity.record_inquiry(sender1.id, receiver.id)
      Popularity.record_inquiry(sender2.id, receiver.id)
      Popularity.record_inquiry(sender3.id, receiver.id)

      assert Popularity.get_daily_count(receiver.id, Date.utc_today()) == 3
    end

    test "only counts for the specified date" do
      receiver = user_fixture()
      sender = user_fixture()

      Popularity.record_inquiry(sender.id, receiver.id)

      # Today should have 1
      assert Popularity.get_daily_count(receiver.id, Date.utc_today()) == 1
      # Yesterday should have 0
      assert Popularity.get_daily_count(receiver.id, Date.add(Date.utc_today(), -1)) == 0
    end
  end

  describe "exceeded_daily_limit?/1" do
    test "returns false when under the limit" do
      receiver = user_fixture()
      sender1 = user_fixture()
      sender2 = user_fixture()

      Popularity.record_inquiry(sender1.id, receiver.id)
      Popularity.record_inquiry(sender2.id, receiver.id)

      refute Popularity.exceeded_daily_limit?(receiver.id)
    end

    test "returns true when at the limit" do
      receiver = user_fixture()

      # Create 6 inquiries (the default limit)
      for _ <- 1..6 do
        sender = user_fixture()
        Popularity.record_inquiry(sender.id, receiver.id)
      end

      assert Popularity.exceeded_daily_limit?(receiver.id)
    end

    test "returns true when over the limit" do
      receiver = user_fixture()

      # Create 8 inquiries (over the default limit of 6)
      for _ <- 1..8 do
        sender = user_fixture()
        Popularity.record_inquiry(sender.id, receiver.id)
      end

      assert Popularity.exceeded_daily_limit?(receiver.id)
    end
  end

  describe "users_exceeding_daily_limit/0" do
    test "returns empty list when no users at limit" do
      _user1 = user_fixture()
      _user2 = user_fixture()

      assert Popularity.users_exceeding_daily_limit() == []
    end

    test "returns user IDs of those at or over the limit" do
      receiver1 = user_fixture()
      receiver2 = user_fixture()
      receiver3 = user_fixture()

      # Give receiver1 6 inquiries (at limit)
      for _ <- 1..6 do
        sender = user_fixture()
        Popularity.record_inquiry(sender.id, receiver1.id)
      end

      # Give receiver2 only 2 inquiries (under limit)
      sender_a = user_fixture()
      sender_b = user_fixture()
      Popularity.record_inquiry(sender_a.id, receiver2.id)
      Popularity.record_inquiry(sender_b.id, receiver2.id)

      # Give receiver3 8 inquiries (over limit)
      for _ <- 1..8 do
        sender = user_fixture()
        Popularity.record_inquiry(sender.id, receiver3.id)
      end

      result = Popularity.users_exceeding_daily_limit()

      assert receiver1.id in result
      assert receiver3.id in result
      refute receiver2.id in result
      assert length(result) == 2
    end
  end

  describe "get_rolling_averages/1" do
    test "returns {0.0, 0.0} when no stats exist" do
      user = user_fixture()

      assert Popularity.get_rolling_averages(user.id) == {0.0, 0.0}
    end

    test "returns the latest averages" do
      user = user_fixture()
      today = Date.utc_today()

      # Insert a popularity stat
      %PopularityStat{}
      |> PopularityStat.changeset(%{
        user_id: user.id,
        stat_date: today,
        daily_inquiry_count: 5,
        avg_7_day: 3.5,
        avg_30_day: 2.1
      })
      |> Repo.insert!()

      assert Popularity.get_rolling_averages(user.id) == {3.5, 2.1}
    end

    test "returns most recent stats when multiple exist" do
      user = user_fixture()
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      # Insert old stat
      %PopularityStat{}
      |> PopularityStat.changeset(%{
        user_id: user.id,
        stat_date: yesterday,
        daily_inquiry_count: 3,
        avg_7_day: 2.0,
        avg_30_day: 1.5
      })
      |> Repo.insert!()

      # Insert newer stat
      %PopularityStat{}
      |> PopularityStat.changeset(%{
        user_id: user.id,
        stat_date: today,
        daily_inquiry_count: 6,
        avg_7_day: 4.5,
        avg_30_day: 3.2
      })
      |> Repo.insert!()

      # Should return the most recent
      assert Popularity.get_rolling_averages(user.id) == {4.5, 3.2}
    end
  end

  describe "compute_rolling_averages/2" do
    test "creates a stat record with computed averages" do
      user = user_fixture()
      today = Date.utc_today()

      # Create some inquiries over the past few days
      for days_ago <- 0..6 do
        date = Date.add(today, -days_ago)

        # Create 2 inquiries per day for the past week
        for _ <- 1..2 do
          sender = user_fixture()

          # Manually insert with specific date
          %Inquiry{}
          |> Inquiry.changeset(%{
            sender_id: sender.id,
            receiver_id: user.id,
            inquiry_date: date
          })
          |> Repo.insert!()
        end
      end

      {:ok, stat} = Popularity.compute_rolling_averages(user.id, today)

      # 7 days * 2 inquiries = 14 total, avg = 2.0
      assert stat.avg_7_day == 2.0
      # Only 7 days of data, so 30-day avg is lower
      assert stat.avg_30_day == 14 / 30
    end
  end

  describe "aggregate_daily_counts/1" do
    test "aggregates inquiry counts for the given date" do
      user1 = user_fixture()
      user2 = user_fixture()
      today = Date.utc_today()

      # Give user1 3 inquiries
      for _ <- 1..3 do
        sender = user_fixture()
        Popularity.record_inquiry(sender.id, user1.id)
      end

      # Give user2 5 inquiries
      for _ <- 1..5 do
        sender = user_fixture()
        Popularity.record_inquiry(sender.id, user2.id)
      end

      {:ok, count} = Popularity.aggregate_daily_counts(today)

      # Should have processed 2 users
      assert count == 2

      # Verify the stats were created
      stat1 = Repo.get_by(PopularityStat, user_id: user1.id, stat_date: today)
      stat2 = Repo.get_by(PopularityStat, user_id: user2.id, stat_date: today)

      assert stat1.daily_inquiry_count == 3
      assert stat2.daily_inquiry_count == 5
    end
  end
end
