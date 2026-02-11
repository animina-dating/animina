defmodule Animina.Reports.AppealsTest do
  use Animina.DataCase, async: true

  alias Animina.AccountsFixtures
  alias Animina.Reports

  describe "create_appeal/3" do
    setup do
      reporter = AccountsFixtures.user_fixture(%{display_name: "Alice"})
      reported_user = AccountsFixtures.user_fixture(%{display_name: "Bob"})
      moderator = AccountsFixtures.moderator_fixture(%{display_name: "Mod1"})

      {:ok, report} =
        Reports.file_report(reporter, reported_user, %{
          category: "harassment",
          context_type: "profile"
        })

      {:ok, resolved_report} = Reports.resolve_report(report, moderator, "warning", "Warned")

      %{
        report: resolved_report,
        reported_user: reported_user,
        moderator: moderator,
        reporter: reporter
      }
    end

    test "creates an appeal", %{report: report, reported_user: reported_user} do
      assert {:ok, appeal} =
               Reports.create_appeal(report, reported_user, "I believe this was a mistake.")

      assert appeal.status == "pending"
      assert appeal.appellant_id == reported_user.id
    end

    test "rejects duplicate appeal", %{report: report, reported_user: reported_user} do
      {:ok, _appeal} = Reports.create_appeal(report, reported_user, "First appeal")

      assert {:error, :appeal_already_exists} =
               Reports.create_appeal(report, reported_user, "Second attempt")
    end

    test "rejects appeal from non-reported user", %{report: report} do
      other_user = AccountsFixtures.user_fixture()

      assert {:error, :not_reported_user} =
               Reports.create_appeal(report, other_user, "Not my report")
    end
  end

  describe "resolve_appeal/4" do
    setup do
      reporter = AccountsFixtures.user_fixture(%{display_name: "Alice"})
      reported_user = AccountsFixtures.user_fixture(%{display_name: "Bob"})
      moderator1 = AccountsFixtures.moderator_fixture(%{display_name: "Mod1"})
      moderator2 = AccountsFixtures.moderator_fixture(%{display_name: "Mod2"})

      {:ok, report} =
        Reports.file_report(reporter, reported_user, %{
          category: "harassment",
          context_type: "profile"
        })

      {:ok, resolved_report} =
        Reports.resolve_report(report, moderator1, "temp_ban_7", "Suspended")

      {:ok, appeal} =
        Reports.create_appeal(resolved_report, reported_user, "I was wrongly suspended")

      %{
        appeal: appeal,
        reported_user: reported_user,
        moderator1: moderator1,
        moderator2: moderator2
      }
    end

    test "approves appeal and restores user", %{
      appeal: appeal,
      reported_user: reported_user,
      moderator2: moderator2
    } do
      assert {:ok, resolved_appeal} =
               Reports.resolve_appeal(appeal, moderator2, "approved", "Valid appeal")

      assert resolved_appeal.status == "approved"

      user = Animina.Accounts.get_user!(reported_user.id)
      assert user.state == "normal"
    end

    test "rejects appeal", %{appeal: appeal, moderator2: moderator2} do
      assert {:ok, resolved_appeal} =
               Reports.resolve_appeal(appeal, moderator2, "rejected", "Decision upheld")

      assert resolved_appeal.status == "rejected"
    end

    test "enforces different moderator", %{appeal: appeal, moderator1: moderator1} do
      assert {:error, :same_moderator} =
               Reports.resolve_appeal(appeal, moderator1, "approved", "Self-review")
    end
  end
end
