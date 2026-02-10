defmodule Animina.Accounts.ProcessReferralTest do
  use Animina.DataCase, async: true

  import Animina.AccountsFixtures

  alias Animina.Accounts
  alias Animina.Accounts.User
  alias Animina.Repo

  import Ecto.Query

  describe "process_referral/1" do
    test "reduces end_waitlist_at for both referrer and referred user" do
      referrer = user_fixture(language: "en", display_name: "Referrer")
      # Set referrer to waitlisted state with end_waitlist_at in the future
      end_at = DateTime.add(DateTime.utc_now(), 14, :day) |> DateTime.truncate(:second)

      from(u in User, where: u.id == ^referrer.id)
      |> Repo.update_all(set: [state: "waitlisted", end_waitlist_at: end_at])

      # Create referred user with referred_by_id
      referred = user_fixture(language: "en", display_name: "Referred")

      from(u in User, where: u.id == ^referred.id)
      |> Repo.update_all(
        set: [state: "waitlisted", end_waitlist_at: end_at, referred_by_id: referrer.id]
      )

      referred = Repo.get!(User, referred.id)
      Accounts.process_referral(referred)

      updated_referrer = Repo.get!(User, referrer.id)
      updated_referred = Repo.get!(User, referred.id)

      # With defaults (14 days, threshold 3): each referral reduces by ~4.67 days
      # Both should have end_waitlist_at earlier than the original
      assert DateTime.compare(updated_referrer.end_waitlist_at, end_at) == :lt
      assert DateTime.compare(updated_referred.end_waitlist_at, end_at) == :lt
    end

    test "clamps end_waitlist_at to now when reduction exceeds remaining time" do
      referrer = user_fixture(language: "en", display_name: "Referrer")
      # Set end_waitlist_at to only 1 day from now (less than the ~4.67 day reduction)
      end_at = DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.truncate(:second)

      from(u in User, where: u.id == ^referrer.id)
      |> Repo.update_all(set: [state: "waitlisted", end_waitlist_at: end_at])

      referred = user_fixture(language: "en", display_name: "Referred")

      from(u in User, where: u.id == ^referred.id)
      |> Repo.update_all(
        set: [state: "waitlisted", end_waitlist_at: end_at, referred_by_id: referrer.id]
      )

      referred = Repo.get!(User, referred.id)
      now_before = DateTime.utc_now(:second)
      Accounts.process_referral(referred)
      now_after = DateTime.utc_now(:second)

      updated_referrer = Repo.get!(User, referrer.id)

      # end_waitlist_at should be clamped to approximately now, not go into the past
      assert DateTime.compare(updated_referrer.end_waitlist_at, now_before) != :lt
      assert DateTime.compare(updated_referrer.end_waitlist_at, now_after) != :gt
    end

    test "skips reduction for already-activated users" do
      referrer = user_fixture(language: "en", display_name: "Referrer")
      end_at = DateTime.add(DateTime.utc_now(), 14, :day) |> DateTime.truncate(:second)

      # Referrer is already activated (state = "normal"), not waitlisted
      from(u in User, where: u.id == ^referrer.id)
      |> Repo.update_all(set: [state: "normal", end_waitlist_at: end_at])

      referred = user_fixture(language: "en", display_name: "Referred")

      from(u in User, where: u.id == ^referred.id)
      |> Repo.update_all(
        set: [state: "waitlisted", end_waitlist_at: end_at, referred_by_id: referrer.id]
      )

      referred = Repo.get!(User, referred.id)
      Accounts.process_referral(referred)

      # Referrer's end_waitlist_at should be unchanged (reduction skipped)
      updated_referrer = Repo.get!(User, referrer.id)
      assert DateTime.compare(updated_referrer.end_waitlist_at, end_at) == :eq

      # Referred user's end_waitlist_at should still be reduced (they are waitlisted)
      updated_referred = Repo.get!(User, referred.id)
      assert DateTime.compare(updated_referred.end_waitlist_at, end_at) == :lt
    end

    test "creates activity log entries for waitlist reduction" do
      referrer = user_fixture(language: "en", display_name: "Referrer")
      end_at = DateTime.add(DateTime.utc_now(), 14, :day) |> DateTime.truncate(:second)

      from(u in User, where: u.id == ^referrer.id)
      |> Repo.update_all(set: [state: "waitlisted", end_waitlist_at: end_at])

      referred = user_fixture(language: "en", display_name: "Referred")

      from(u in User, where: u.id == ^referred.id)
      |> Repo.update_all(
        set: [state: "waitlisted", end_waitlist_at: end_at, referred_by_id: referrer.id]
      )

      referred = Repo.get!(User, referred.id)
      Accounts.process_referral(referred)

      # Check activity logs were created
      alias Animina.ActivityLog.ActivityLogEntry

      logs =
        from(l in ActivityLogEntry,
          where: l.event == "referral_waitlist_reduced",
          where: l.actor_id in [^referrer.id, ^referred.id]
        )
        |> Repo.all()

      assert length(logs) == 2
      assert Enum.all?(logs, &(&1.category == "profile"))
    end

    test "does nothing for user without referrer" do
      user = user_fixture(language: "en", display_name: "Solo")
      assert :ok = Accounts.process_referral(user)
    end

    test "increments waitlist_priority for both users" do
      referrer = user_fixture(language: "en", display_name: "Referrer")
      end_at = DateTime.add(DateTime.utc_now(), 14, :day) |> DateTime.truncate(:second)

      from(u in User, where: u.id == ^referrer.id)
      |> Repo.update_all(set: [state: "waitlisted", end_waitlist_at: end_at])

      referred = user_fixture(language: "en", display_name: "Referred")

      from(u in User, where: u.id == ^referred.id)
      |> Repo.update_all(
        set: [state: "waitlisted", end_waitlist_at: end_at, referred_by_id: referrer.id]
      )

      referred = Repo.get!(User, referred.id)
      Accounts.process_referral(referred)

      assert Repo.get!(User, referrer.id).waitlist_priority == 1
      assert Repo.get!(User, referred.id).waitlist_priority == 1
    end
  end
end
