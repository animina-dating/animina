defmodule Animina.Accounts.ScopeTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.Scope

  import Animina.AccountsFixtures

  describe "for_user/1" do
    test "returns scope for user with default role" do
      user = user_fixture()
      scope = Scope.for_user(user)
      assert scope.user.id == user.id
      assert scope.current_role == "user"
      assert scope.roles == ["user"]
    end

    test "returns nil for nil user" do
      assert Scope.for_user(nil) == nil
    end
  end

  describe "for_user/3" do
    test "sets current_role when role is valid" do
      user = user_fixture()
      scope = Scope.for_user(user, ["user", "admin"], "admin")
      assert scope.current_role == "admin"
      assert scope.roles == ["user", "admin"]
    end

    test "falls back to user when current_role is not in roles" do
      user = user_fixture()
      scope = Scope.for_user(user, ["user"], "admin")
      assert scope.current_role == "user"
    end

    test "falls back to user when current_role is nil" do
      user = user_fixture()
      scope = Scope.for_user(user, ["user", "admin"], nil)
      assert scope.current_role == "user"
    end
  end

  describe "admin?/1" do
    test "returns true for admin role" do
      user = user_fixture()
      scope = Scope.for_user(user, ["user", "admin"], "admin")
      assert Scope.admin?(scope)
    end

    test "returns false for moderator role" do
      user = user_fixture()
      scope = Scope.for_user(user, ["user", "moderator"], "moderator")
      refute Scope.admin?(scope)
    end

    test "returns false for user role" do
      user = user_fixture()
      scope = Scope.for_user(user)
      refute Scope.admin?(scope)
    end

    test "returns false for nil" do
      refute Scope.admin?(nil)
    end
  end

  describe "moderator?/1" do
    test "returns true for moderator role" do
      user = user_fixture()
      scope = Scope.for_user(user, ["user", "moderator"], "moderator")
      assert Scope.moderator?(scope)
    end

    test "returns true for admin role (admins have moderator powers)" do
      user = user_fixture()
      scope = Scope.for_user(user, ["user", "admin"], "admin")
      assert Scope.moderator?(scope)
    end

    test "returns false for user role" do
      user = user_fixture()
      scope = Scope.for_user(user)
      refute Scope.moderator?(scope)
    end

    test "returns false for nil" do
      refute Scope.moderator?(nil)
    end
  end

  describe "has_role?/2" do
    test "returns true when role is in the roles list" do
      user = user_fixture()
      scope = Scope.for_user(user, ["user", "admin"], "admin")
      assert Scope.has_role?(scope, "admin")
      assert Scope.has_role?(scope, "user")
    end

    test "returns false when role is not in the roles list" do
      user = user_fixture()
      scope = Scope.for_user(user, ["user"], "user")
      refute Scope.has_role?(scope, "admin")
    end

    test "returns false for nil scope" do
      refute Scope.has_role?(nil, "admin")
    end
  end

  describe "has_multiple_roles?/1" do
    test "returns true when user has more than one role" do
      user = user_fixture()
      scope = Scope.for_user(user, ["user", "admin"], "admin")
      assert Scope.has_multiple_roles?(scope)
    end

    test "returns false when user has only the user role" do
      user = user_fixture()
      scope = Scope.for_user(user, ["user"], "user")
      refute Scope.has_multiple_roles?(scope)
    end

    test "returns false for nil scope" do
      refute Scope.has_multiple_roles?(nil)
    end
  end
end
