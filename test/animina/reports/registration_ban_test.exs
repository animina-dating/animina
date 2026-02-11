defmodule Animina.Reports.RegistrationBanTest do
  use Animina.DataCase, async: true

  alias Animina.AccountsFixtures
  alias Animina.Reports

  describe "registration ban check" do
    test "permanently banned user's phone and email are banned" do
      reporter = AccountsFixtures.user_fixture()
      reported_user = AccountsFixtures.user_fixture()
      moderator = AccountsFixtures.moderator_fixture()

      {:ok, report} =
        Reports.file_report(reporter, reported_user, %{
          category: "threatening_behavior",
          context_type: "profile"
        })

      {:ok, _} = Reports.resolve_report(report, moderator, "permanent_ban", "Banned")

      assert Reports.registration_banned?(reported_user.mobile_phone, reported_user.email)
    end

    test "warned user's phone and email are not banned" do
      reporter = AccountsFixtures.user_fixture()
      reported_user = AccountsFixtures.user_fixture()
      moderator = AccountsFixtures.moderator_fixture()

      {:ok, report} =
        Reports.file_report(reporter, reported_user, %{category: "other", context_type: "profile"})

      {:ok, _} = Reports.resolve_report(report, moderator, "warning", "Warned")

      refute Reports.registration_banned?(reported_user.mobile_phone, reported_user.email)
    end

    test "unrelated phone/email are not banned" do
      refute Reports.registration_banned?("+4917099999999", "nobody@example.com")
    end
  end
end
