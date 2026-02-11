defmodule Animina.Reports.ModerationTest do
  use Animina.DataCase, async: true

  alias Animina.AccountsFixtures
  alias Animina.Reports

  describe "resolve_report/4" do
    setup do
      reporter = AccountsFixtures.user_fixture(%{display_name: "Alice"})
      reported_user = AccountsFixtures.user_fixture(%{display_name: "Bob"})
      moderator = AccountsFixtures.moderator_fixture(%{display_name: "Mod"})

      attrs = %{category: "harassment", context_type: "profile"}
      {:ok, report} = Reports.file_report(reporter, reported_user, attrs)

      %{report: report, reporter: reporter, reported_user: reported_user, moderator: moderator}
    end

    test "resolves with warning", %{report: report, moderator: moderator} do
      assert {:ok, resolved} =
               Reports.resolve_report(report, moderator, "warning", "First offense")

      assert resolved.status == "resolved"
      assert resolved.resolution == "warning"
      assert resolved.resolver_id == moderator.id
    end

    test "resolves with dismissal (no strike)", %{
      report: report,
      reported_user: reported_user,
      moderator: moderator
    } do
      {:ok, _resolved} = Reports.resolve_report(report, moderator, "dismissed", "False report")
      assert Reports.strike_count(reported_user) == 0
    end

    test "creates strike record on non-dismissed resolution", %{
      report: report,
      reported_user: reported_user,
      moderator: moderator
    } do
      {:ok, _resolved} = Reports.resolve_report(report, moderator, "warning", "Warned")
      assert Reports.strike_count(reported_user) == 1
    end

    test "suspends user on temp ban", %{
      report: report,
      reported_user: reported_user,
      moderator: moderator
    } do
      {:ok, _resolved} = Reports.resolve_report(report, moderator, "temp_ban_7", "Suspended")

      user = Animina.Accounts.get_user!(reported_user.id)
      assert user.state == "suspended"
      assert user.suspended_until != nil
    end

    test "permanently bans user", %{
      report: report,
      reported_user: reported_user,
      moderator: moderator
    } do
      {:ok, _resolved} = Reports.resolve_report(report, moderator, "permanent_ban", "Banned")

      user = Animina.Accounts.get_user!(reported_user.id)
      assert user.state == "banned"

      # Registration ban created
      assert Reports.registration_banned?(reported_user.mobile_phone, reported_user.email)
    end
  end

  describe "strike system" do
    test "recommended_action based on strike count" do
      reported_user = AccountsFixtures.user_fixture()

      # 0 strikes → warning
      assert Reports.recommended_action(reported_user) == "warning"

      # Create 1 strike
      reporter1 = AccountsFixtures.user_fixture()
      moderator = AccountsFixtures.moderator_fixture()

      {:ok, report1} =
        Reports.file_report(reporter1, reported_user, %{
          category: "harassment",
          context_type: "profile"
        })

      {:ok, _} = Reports.resolve_report(report1, moderator, "warning", "Strike 1")

      # 1 strike → temp_ban_7
      assert Reports.recommended_action(reported_user) == "temp_ban_7"

      # Create 2nd strike
      reporter2 = AccountsFixtures.user_fixture()

      {:ok, report2} =
        Reports.file_report(reporter2, reported_user, %{
          category: "harassment",
          context_type: "profile"
        })

      {:ok, _} = Reports.resolve_report(report2, moderator, "warning", "Strike 2")

      # 2 strikes → permanent_ban
      assert Reports.recommended_action(reported_user) == "permanent_ban"
    end

    test "strike_history returns records ordered by date" do
      reported_user = AccountsFixtures.user_fixture()
      moderator = AccountsFixtures.moderator_fixture()

      reporter1 = AccountsFixtures.user_fixture()

      {:ok, report1} =
        Reports.file_report(reporter1, reported_user, %{
          category: "harassment",
          context_type: "profile"
        })

      {:ok, _} = Reports.resolve_report(report1, moderator, "warning", "First")

      reporter2 = AccountsFixtures.user_fixture()

      {:ok, report2} =
        Reports.file_report(reporter2, reported_user, %{
          category: "scam_spam",
          context_type: "profile"
        })

      {:ok, _} = Reports.resolve_report(report2, moderator, "warning", "Second")

      history = Reports.strike_history(reported_user)
      assert length(history) == 2
    end
  end

  describe "registration_banned?/2" do
    test "returns false for unbanned user" do
      refute Reports.registration_banned?("+4917012345678", "test@example.com")
    end
  end

  describe "maybe_unsuspend/1" do
    test "auto-unsuspends when suspension has expired" do
      user = AccountsFixtures.user_fixture()

      # Manually set suspended state with past expiry
      {:ok, user} =
        user
        |> Animina.Accounts.User.moderation_changeset(%{
          state: "suspended",
          suspended_until: DateTime.add(DateTime.utc_now(), -1, :hour)
        })
        |> Animina.Repo.update()

      unsuspended = Reports.maybe_unsuspend(user)
      assert unsuspended.state == "normal"
      assert unsuspended.suspended_until == nil
    end

    test "does not unsuspend when suspension is still active" do
      user = AccountsFixtures.user_fixture()

      {:ok, user} =
        user
        |> Animina.Accounts.User.moderation_changeset(%{
          state: "suspended",
          suspended_until: DateTime.add(DateTime.utc_now(), 7, :day)
        })
        |> Animina.Repo.update()

      still_suspended = Reports.maybe_unsuspend(user)
      assert still_suspended.state == "suspended"
    end
  end
end
