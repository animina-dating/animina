defmodule Animina.Accounts.GridColumnsTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts

  import Animina.AccountsFixtures

  describe "update_grid_columns/2" do
    test "saves and retrieves column preference" do
      user = user_fixture()
      assert {:ok, updated} = Accounts.update_grid_columns(user, 1)
      assert updated.grid_columns == 1
    end

    test "default is 2 for new users" do
      user = user_fixture()
      assert user.grid_columns == 2
    end

    test "rejects invalid column count via changeset" do
      user = user_fixture()

      changeset =
        Accounts.User.grid_columns_changeset(user, %{grid_columns: 4})

      refute changeset.valid?
      assert {"is invalid", _} = changeset.errors[:grid_columns]
    end

    test "rejects zero column count via changeset" do
      user = user_fixture()

      changeset =
        Accounts.User.grid_columns_changeset(user, %{grid_columns: 0})

      refute changeset.valid?
      assert {"is invalid", _} = changeset.errors[:grid_columns]
    end
  end

  describe "ColumnPreferences helper" do
    alias AniminaWeb.Helpers.ColumnPreferences

    test "get_columns_for_user returns saved preference" do
      user = user_fixture()
      {:ok, user} = Accounts.update_grid_columns(user, 1)
      assert ColumnPreferences.get_columns_for_user(user) == 1
    end

    test "default_columns returns 3" do
      assert ColumnPreferences.default_columns() == 3
    end

    test "grid_class returns correct CSS classes" do
      assert ColumnPreferences.grid_class(1) == "grid-cols-1"
      assert ColumnPreferences.grid_class(2) == "grid-cols-2"
      assert ColumnPreferences.grid_class(3) == "grid-cols-3"
    end

    test "sm_grid_class caps at 2 columns" do
      assert ColumnPreferences.sm_grid_class(1) == "sm:grid-cols-1"
      assert ColumnPreferences.sm_grid_class(2) == "sm:grid-cols-2"
      assert ColumnPreferences.sm_grid_class(3) == "sm:grid-cols-2"
    end

    test "md_grid_class allows 3 columns for tablets" do
      assert ColumnPreferences.md_grid_class(1) == "md:grid-cols-1"
      assert ColumnPreferences.md_grid_class(2) == "md:grid-cols-2"
      assert ColumnPreferences.md_grid_class(3) == "md:grid-cols-3"
    end

    test "persist_columns saves and returns {columns, updated_user}" do
      user = user_fixture()
      assert {1, updated_user} = ColumnPreferences.persist_columns(user, "1")
      assert updated_user.grid_columns == 1

      reloaded = Accounts.get_user!(user.id)
      assert reloaded.grid_columns == 1
    end

    test "validate_columns returns valid values unchanged" do
      assert ColumnPreferences.validate_columns(1) == 1
      assert ColumnPreferences.validate_columns(2) == 2
      assert ColumnPreferences.validate_columns(3) == 3
    end

    test "validate_columns defaults invalid values to 3" do
      assert ColumnPreferences.validate_columns(0) == 3
      assert ColumnPreferences.validate_columns(4) == 3
      assert ColumnPreferences.validate_columns(nil) == 3
    end
  end

  describe "distribute_to_columns/2" do
    import AniminaWeb.MoodboardComponents, only: [distribute_to_columns: 2]

    test "returns all columns even when some are empty" do
      items = [%{id: 1}]
      result = distribute_to_columns(items, 3)

      assert length(result) == 3
      assert {[%{id: 1}], 0} = Enum.at(result, 0)
      assert {[], 1} = Enum.at(result, 1)
      assert {[], 2} = Enum.at(result, 2)
    end

    test "distributes items round-robin across columns" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}, %{id: 5}]
      result = distribute_to_columns(items, 3)

      assert {[%{id: 1}, %{id: 4}], 0} = Enum.at(result, 0)
      assert {[%{id: 2}, %{id: 5}], 1} = Enum.at(result, 1)
      assert {[%{id: 3}], 2} = Enum.at(result, 2)
    end

    test "single column returns all items in one column" do
      items = [%{id: 1}, %{id: 2}]
      result = distribute_to_columns(items, 1)

      assert length(result) == 1
      assert {[%{id: 1}, %{id: 2}], 0} = Enum.at(result, 0)
    end
  end
end
