defmodule Animina.Accounts.RegistrationSpikeAlertTest do
  use Animina.DataCase, async: false

  import Animina.AccountsFixtures

  alias Animina.Accounts
  alias Animina.Accounts.RegistrationSpikeAlert

  setup do
    try do
      :persistent_term.erase(:registration_spike_last_alert)
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  describe "count_confirmed_users_today_berlin/0" do
    test "returns 0 when no users exist" do
      assert Accounts.count_confirmed_users_today_berlin() == 0
    end

    test "counts confirmed users created today (Berlin time)" do
      user_fixture()
      user_fixture()

      assert Accounts.count_confirmed_users_today_berlin() == 2
    end

    test "does not count unconfirmed users" do
      unconfirmed_user_fixture()

      assert Accounts.count_confirmed_users_today_berlin() == 0
    end

    test "does not count users created before today" do
      user = user_fixture()
      backdate_user(user, days_ago: 2)

      assert Accounts.count_confirmed_users_today_berlin() == 0
    end
  end

  describe "average_daily_confirmed_users_last_30_days/0" do
    test "returns 0.0 when no historical users exist" do
      assert Accounts.average_daily_confirmed_users_last_30_days() == 0.0
    end

    test "excludes today's users from the average" do
      user_fixture()

      assert Accounts.average_daily_confirmed_users_last_30_days() == 0.0
    end

    test "calculates average over 30 days" do
      # Create 30 users backdated to yesterday
      for _ <- 1..30 do
        user = user_fixture()
        backdate_user(user, days_ago: 1)
      end

      avg = Accounts.average_daily_confirmed_users_last_30_days()
      assert avg == 1.0
    end
  end

  describe "confirmed_users_today_by_hour_berlin/0" do
    test "returns empty list when no users exist" do
      assert Accounts.confirmed_users_today_by_hour_berlin() == []
    end

    test "returns hourly breakdown" do
      user_fixture()
      user_fixture()

      result = Accounts.confirmed_users_today_by_hour_berlin()

      # Each entry is {hour, count}
      [{hour, count} | _] = result
      assert is_integer(hour)
      assert hour >= 0 and hour <= 23
      assert count == 2
    end
  end

  describe "count_confirmed_users_yesterday_berlin/0" do
    test "returns 0 when no users exist" do
      assert Accounts.count_confirmed_users_yesterday_berlin() == 0
    end

    test "counts users from yesterday" do
      user = user_fixture()
      backdate_user(user, days_ago: 1)

      assert Accounts.count_confirmed_users_yesterday_berlin() == 1
    end

    test "does not count today's users" do
      user_fixture()

      assert Accounts.count_confirmed_users_yesterday_berlin() == 0
    end
  end

  describe "run/0" do
    test "returns :ok and logs when no spike detected" do
      assert RegistrationSpikeAlert.run() == :ok
    end

    test "returns :ok when today count is 0" do
      assert RegistrationSpikeAlert.run() == :ok
    end

    test "sends alert when spike detected (no history, any registration triggers)" do
      # With no history, avg is 0.0, so any registration >= 0 * 1.5 triggers
      user_fixture()

      assert {:ok, _email} = RegistrationSpikeAlert.run()
    end

    test "sends alert when today exceeds 1.5x average" do
      # Create 30 users across 30 days (1/day avg)
      for day <- 1..30 do
        user = user_fixture()
        backdate_user(user, days_ago: day)
      end

      # Average is 1.0, threshold is 1.5, so 2 users today should trigger
      user_fixture()
      user_fixture()

      assert {:ok, _email} = RegistrationSpikeAlert.run()
    end

    test "does not send alert when today is below threshold" do
      # Create 30 users per day for 30 days (30/day avg)
      for day <- 1..30 do
        for _ <- 1..30 do
          user = user_fixture()
          backdate_user(user, days_ago: day)
        end
      end

      # Average is 30.0, threshold is 45.0
      # 1 user today is well below threshold
      user_fixture()

      assert RegistrationSpikeAlert.run() == :ok
    end

    test "suppresses repeat alert at same spike level" do
      # With no history, avg is 0.0 — any registration triggers
      user_fixture()

      # First call should send
      assert {:ok, _email} = RegistrationSpikeAlert.run()

      # Second call at same level should be suppressed
      assert RegistrationSpikeAlert.run() == :ok
    end

    test "re-alerts when spike factor doubles" do
      # Create a baseline: 30 users across 30 days (1/day avg)
      for day <- 1..30 do
        user = user_fixture()
        backdate_user(user, days_ago: day)
      end

      # 2 users today → factor 2.0x (above 1.5x threshold)
      user_fixture()
      user_fixture()

      assert {:ok, _email} = RegistrationSpikeAlert.run()

      # Add more users to double the factor: need factor >= 4.0x → 4 users today
      user_fixture()
      user_fixture()

      assert {:ok, _email} = RegistrationSpikeAlert.run()
    end

    test "resets on new day" do
      # Manually set persistent_term with yesterday's date
      yesterday = Date.utc_today() |> Date.add(-1)
      :persistent_term.put(:registration_spike_last_alert, {yesterday, 5.0})

      # Any spike should send a fresh alert since it's a new day
      user_fixture()

      assert {:ok, _email} = RegistrationSpikeAlert.run()
    end

    test "suppresses just below escalation threshold" do
      # Create a baseline: 30 users across 30 days (1/day avg)
      for day <- 1..30 do
        user = user_fixture()
        backdate_user(user, days_ago: day)
      end

      # 2 users today → factor 2.0x
      user_fixture()
      user_fixture()

      assert {:ok, _email} = RegistrationSpikeAlert.run()

      # Add 1 more user → factor 3.0x, but need 4.0x to re-alert (2.0 * 2.0)
      user_fixture()

      assert RegistrationSpikeAlert.run() == :ok
    end
  end
end
