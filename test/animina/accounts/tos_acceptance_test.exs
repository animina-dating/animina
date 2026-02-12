defmodule Animina.Accounts.TosAcceptanceTest do
  use AniminaWeb.ConnCase, async: true

  import Animina.AccountsFixtures
  import Ecto.Query, warn: false

  alias Animina.Accounts
  alias Animina.Accounts.TosAcceptance

  describe "record_tos_acceptance/2" do
    test "inserts a tos_acceptance record" do
      user = user_fixture()

      assert {:ok, %TosAcceptance{} = acceptance} =
               Accounts.record_tos_acceptance(user, "2026-02-13")

      assert acceptance.user_id == user.id
      assert acceptance.version == "2026-02-13"
      assert acceptance.accepted_at != nil
      assert acceptance.inserted_at != nil
    end
  end

  describe "accept_terms_of_service/1" do
    test "updates user tos_accepted_at, creates acceptance record, and logs activity" do
      user = user_fixture()

      # Clear tos_accepted_at to simulate re-consent
      Animina.Repo.update_all(
        from(u in Animina.Accounts.User, where: u.id == ^user.id),
        set: [tos_accepted_at: nil]
      )

      user = Animina.Repo.get!(Animina.Accounts.User, user.id)
      assert is_nil(user.tos_accepted_at)

      assert {:ok, updated_user} = Accounts.accept_terms_of_service(user)
      assert updated_user.tos_accepted_at != nil

      # Verify TosAcceptance record was created
      acceptances =
        from(a in TosAcceptance, where: a.user_id == ^user.id)
        |> Animina.Repo.all()

      assert length(acceptances) == 1
      assert hd(acceptances).version == Accounts.tos_version()

      # Verify activity log entry was created
      log =
        from(l in Animina.ActivityLog.ActivityLogEntry,
          where: l.actor_id == ^user.id and l.event == "tos_accepted"
        )
        |> Animina.Repo.one()

      assert log != nil
      assert log.category == "profile"
      assert log.metadata["version"] == Accounts.tos_version()
    end
  end

  describe "list_tos_acceptances/1" do
    test "returns paginated results" do
      user = user_fixture()
      {:ok, _} = Accounts.record_tos_acceptance(user, "2026-02-13")

      result = Accounts.list_tos_acceptances(page: 1, per_page: 50)

      assert result.total_count >= 1
      assert result.entries != []
      assert hd(result.entries).user != nil
    end

    test "filters by user_id" do
      user1 = user_fixture()
      user2 = user_fixture()
      {:ok, _} = Accounts.record_tos_acceptance(user1, "2026-02-13")
      {:ok, _} = Accounts.record_tos_acceptance(user2, "2026-02-13")

      result = Accounts.list_tos_acceptances(filter_user_id: user1.id)

      assert Enum.all?(result.entries, fn a -> a.user_id == user1.id end)
    end

    test "filters by version" do
      user = user_fixture()
      {:ok, _} = Accounts.record_tos_acceptance(user, "2026-01-01")
      {:ok, _} = Accounts.record_tos_acceptance(user, "2026-02-13")

      result = Accounts.list_tos_acceptances(filter_version: "2026-02-13")

      assert Enum.all?(result.entries, fn a -> a.version == "2026-02-13" end)
    end
  end

  describe "tos_version/0" do
    test "returns the current version string" do
      version = Accounts.tos_version()
      assert is_binary(version)
      assert String.match?(version, ~r/^\d{4}-\d{2}-\d{2}$/)
    end
  end

  describe "count_tos_acceptances/0" do
    test "returns the total count" do
      initial_count = Accounts.count_tos_acceptances()
      user = user_fixture()
      {:ok, _} = Accounts.record_tos_acceptance(user, "2026-02-13")

      assert Accounts.count_tos_acceptances() == initial_count + 1
    end
  end

  describe "list_tos_versions/0" do
    test "returns distinct versions" do
      user = user_fixture()
      {:ok, _} = Accounts.record_tos_acceptance(user, "2026-01-01")
      {:ok, _} = Accounts.record_tos_acceptance(user, "2026-02-13")

      versions = Accounts.list_tos_versions()
      assert "2026-01-01" in versions
      assert "2026-02-13" in versions
    end
  end
end
