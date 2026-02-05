defmodule Animina.Accounts.SoftDeleteTest do
  use Animina.DataCase

  alias Animina.Accounts.SoftDelete
  alias Animina.Accounts.User

  import Animina.AccountsFixtures

  describe "soft_delete_user/2" do
    test "sets deleted_at to a future date (grace period end)" do
      user = user_fixture()

      {:ok, deleted_user} = SoftDelete.soft_delete_user(user)

      assert deleted_user.deleted_at != nil
      # deleted_at should be in the future (28 days from now by default)
      assert DateTime.after?(deleted_user.deleted_at, DateTime.utc_now())
    end
  end

  describe "within_grace_period?/1" do
    test "returns true when deleted_at is in the future" do
      user = user_fixture()

      # Set deleted_at to 10 days in the future
      future_date = DateTime.utc_now() |> DateTime.add(10, :day) |> DateTime.truncate(:second)

      {:ok, user} =
        user
        |> Ecto.Changeset.change(deleted_at: future_date)
        |> Repo.update()

      assert SoftDelete.within_grace_period?(user) == true
    end

    test "returns false when deleted_at is in the past" do
      user = user_fixture()

      # Set deleted_at to 1 day in the past (grace period expired)
      past_date = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)

      {:ok, user} =
        user
        |> Ecto.Changeset.change(deleted_at: past_date)
        |> Repo.update()

      assert SoftDelete.within_grace_period?(user) == false
    end

    test "returns false when deleted_at is nil" do
      user = user_fixture()
      assert SoftDelete.within_grace_period?(user) == false
    end
  end

  describe "get_deleted_user_by_email_and_password/2" do
    test "returns user when deleted_at is in the future (within grace period)" do
      user = user_fixture()
      password = valid_user_password()

      # Soft delete the user (sets future deleted_at)
      {:ok, _deleted_user} = SoftDelete.soft_delete_user(user)

      found = SoftDelete.get_deleted_user_by_email_and_password(user.email, password)

      assert found != nil
      assert found.id == user.id
    end

    test "returns nil when deleted_at is in the past (grace period expired)" do
      user = user_fixture()
      password = valid_user_password()

      # Set deleted_at to 1 day in the past
      past_date = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)

      {:ok, _user} =
        user
        |> Ecto.Changeset.change(deleted_at: past_date)
        |> Repo.update()

      found = SoftDelete.get_deleted_user_by_email_and_password(user.email, password)

      assert found == nil
    end

    test "returns nil with wrong password" do
      user = user_fixture()

      {:ok, _deleted_user} = SoftDelete.soft_delete_user(user)

      found = SoftDelete.get_deleted_user_by_email_and_password(user.email, "wrong_password!")

      assert found == nil
    end
  end

  describe "purge_deleted_users/0" do
    test "deletes users whose deleted_at is in the past" do
      user = user_fixture()

      # Set deleted_at to 1 day in the past (expired)
      past_date = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)

      Repo.update_all(
        from(u in User, where: u.id == ^user.id),
        set: [deleted_at: past_date]
      )

      {count, _} = SoftDelete.purge_deleted_users()

      assert count >= 1
      assert Repo.get(User, user.id) == nil
    end

    test "does not delete users whose deleted_at is in the future" do
      user = user_fixture()

      # Soft delete normally (future deleted_at)
      {:ok, _deleted_user} = SoftDelete.soft_delete_user(user)

      {_count, _} = SoftDelete.purge_deleted_users()

      # User should still exist
      assert Repo.get(User, user.id) != nil
    end

    test "does not delete active users (no deleted_at)" do
      user = user_fixture()

      {_count, _} = SoftDelete.purge_deleted_users()

      assert Repo.get(User, user.id) != nil
    end
  end

  describe "reactivate_user/2" do
    test "clears deleted_at to reactivate user" do
      user = user_fixture()

      {:ok, deleted_user} = SoftDelete.soft_delete_user(user)
      assert deleted_user.deleted_at != nil

      {:ok, reactivated_user} = SoftDelete.reactivate_user(deleted_user)
      assert reactivated_user.deleted_at == nil
    end
  end
end
