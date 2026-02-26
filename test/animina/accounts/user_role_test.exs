defmodule Animina.Accounts.UserRoleTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.UserRole

  import Animina.AccountsFixtures

  describe "changeset/2" do
    test "valid with moderator role" do
      user = user_fixture()
      changeset = UserRole.changeset(%UserRole{}, %{user_id: user.id, role: "moderator"})
      assert changeset.valid?
    end

    test "valid with admin role" do
      user = user_fixture()
      changeset = UserRole.changeset(%UserRole{}, %{user_id: user.id, role: "admin"})
      assert changeset.valid?
    end

    test "invalid with user role" do
      user = user_fixture()
      changeset = UserRole.changeset(%UserRole{}, %{user_id: user.id, role: "user"})
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role
    end

    test "invalid with unknown role" do
      user = user_fixture()
      changeset = UserRole.changeset(%UserRole{}, %{user_id: user.id, role: "superadmin"})
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role
    end

    test "requires user_id" do
      changeset = UserRole.changeset(%UserRole{}, %{role: "admin"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "requires role" do
      user = user_fixture()
      changeset = UserRole.changeset(%UserRole{}, %{user_id: user.id})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).role
    end

    test "enforces unique constraint on user_id + role" do
      user = user_fixture()
      {:ok, _} = Repo.insert(UserRole.changeset(%UserRole{}, %{user_id: user.id, role: "admin"}))

      assert {:error, changeset} =
               Repo.insert(UserRole.changeset(%UserRole{}, %{user_id: user.id, role: "admin"}))

      assert "has already been taken" in errors_on(changeset).user_id
    end
  end

  describe "valid_roles/0" do
    test "returns moderator and admin" do
      assert UserRole.valid_roles() == ["moderator", "admin"]
    end
  end
end
