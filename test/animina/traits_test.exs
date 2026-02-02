defmodule Animina.TraitsTest do
  use Animina.DataCase, async: true

  alias Animina.Traits
  alias Animina.Traits.{Category, Flag, UserCategoryOptIn, UserFlag}

  import Animina.TraitsFixtures
  import Animina.AccountsFixtures

  describe "categories" do
    test "create_category/1 with valid data creates a category" do
      assert {:ok, %Category{} = category} =
               Traits.create_category(%{
                 name: "Test Sports #{System.unique_integer([:positive])}",
                 selection_mode: "multi",
                 sensitive: false,
                 position: 1
               })

      assert category.selection_mode == "multi"
      assert category.sensitive == false
      assert category.position == 1
    end

    test "create_category/1 with single selection mode" do
      assert {:ok, %Category{} = category} =
               Traits.create_category(%{
                 name: "Test Family #{System.unique_integer([:positive])}",
                 selection_mode: "single",
                 sensitive: false,
                 position: 1
               })

      assert category.selection_mode == "single"
    end

    test "create_category/1 with invalid selection_mode fails" do
      assert {:error, changeset} =
               Traits.create_category(%{
                 name: "Bad",
                 selection_mode: "invalid",
                 position: 1
               })

      assert %{selection_mode: _} = errors_on(changeset)
    end

    test "create_category/1 with duplicate name fails" do
      category_fixture(%{name: "Unique Name"})

      assert {:error, changeset} =
               Traits.create_category(%{
                 name: "Unique Name",
                 selection_mode: "multi",
                 position: 2
               })

      assert %{name: _} = errors_on(changeset)
    end

    test "list_categories/0 returns all categories ordered by position" do
      c1 = category_fixture(%{position: 2})
      c2 = category_fixture(%{position: 1})

      categories = Traits.list_categories()
      ids = Enum.map(categories, & &1.id)
      assert c2.id in ids
      assert c1.id in ids

      # c2 should come before c1 (position 1 before 2)
      assert Enum.find_index(ids, &(&1 == c2.id)) < Enum.find_index(ids, &(&1 == c1.id))
    end

    test "list_visible_categories/1 hides sensitive categories without opt-in" do
      user = user_fixture()
      normal = category_fixture(%{sensitive: false})
      sensitive = category_fixture(%{sensitive: true})

      visible = Traits.list_visible_categories(user)
      visible_ids = Enum.map(visible, & &1.id)
      assert normal.id in visible_ids
      refute sensitive.id in visible_ids
    end

    test "list_visible_categories/1 shows sensitive categories with opt-in" do
      user = user_fixture()
      sensitive = category_fixture(%{sensitive: true})
      Traits.opt_into_category(user, sensitive)

      visible = Traits.list_visible_categories(user)
      visible_ids = Enum.map(visible, & &1.id)
      assert sensitive.id in visible_ids
    end

    test "get_category!/1 returns the category" do
      category = category_fixture()
      assert Traits.get_category!(category.id).id == category.id
    end
  end

  describe "flags" do
    test "create_flag/1 with valid data creates a flag" do
      category = category_fixture()

      assert {:ok, %Flag{} = flag} =
               Traits.create_flag(%{
                 name: "Soccer",
                 emoji: "⚽",
                 category_id: category.id,
                 position: 1
               })

      assert flag.name == "Soccer"
      assert flag.emoji == "⚽"
      assert flag.category_id == category.id
    end

    test "create_flag/1 with parent creates a child flag" do
      category = category_fixture()

      {:ok, parent} =
        Traits.create_flag(%{
          name: "Parent Flag",
          emoji: "📁",
          category_id: category.id,
          position: 1
        })

      {:ok, child} =
        Traits.create_flag(%{
          name: "Child Flag",
          emoji: "📄",
          category_id: category.id,
          parent_id: parent.id,
          position: 1
        })

      assert child.parent_id == parent.id
    end

    test "create_flag/1 rejects nesting deeper than 2 levels" do
      category = category_fixture()

      {:ok, parent} =
        Traits.create_flag(%{
          name: "Level 1",
          emoji: "1️⃣",
          category_id: category.id,
          position: 1
        })

      {:ok, child} =
        Traits.create_flag(%{
          name: "Level 2",
          emoji: "2️⃣",
          category_id: category.id,
          parent_id: parent.id,
          position: 1
        })

      assert {:error, changeset} =
               Traits.create_flag(%{
                 name: "Level 3",
                 emoji: "3️⃣",
                 category_id: category.id,
                 parent_id: child.id,
                 position: 1
               })

      assert %{parent_id: ["maximum nesting depth of 2 levels exceeded"]} = errors_on(changeset)
    end

    test "create_flag/1 with duplicate name in same category fails" do
      category = category_fixture()
      flag_fixture(%{name: "Duplicate", category_id: category.id})

      assert {:error, changeset} =
               Traits.create_flag(%{
                 name: "Duplicate",
                 emoji: "🔁",
                 category_id: category.id,
                 position: 2
               })

      assert %{category_id: _} = errors_on(changeset)
    end

    test "list_top_level_flags_by_category/1 returns only parent flags" do
      category = category_fixture()

      {:ok, parent} =
        Traits.create_flag(%{
          name: "Parent",
          emoji: "📁",
          category_id: category.id,
          position: 1
        })

      {:ok, _child} =
        Traits.create_flag(%{
          name: "Child",
          emoji: "📄",
          category_id: category.id,
          parent_id: parent.id,
          position: 1
        })

      flags = Traits.list_top_level_flags_by_category(category)
      assert length(flags) == 1
      assert hd(flags).id == parent.id
    end

    test "get_flag_with_children!/1 preloads children" do
      {parent, children} = flag_with_children_fixture()
      loaded = Traits.get_flag_with_children!(parent.id)
      assert length(loaded.children) == length(children)
    end
  end

  describe "user flags" do
    test "add_user_flag/1 creates a user flag" do
      user = user_fixture()
      flag = flag_fixture()

      assert {:ok, %UserFlag{} = uf} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: flag.id,
                 color: "white",
                 intensity: "hard",
                 position: 1
               })

      assert uf.user_id == user.id
      assert uf.flag_id == flag.id
      assert uf.color == "white"
      assert uf.intensity == "hard"
      assert uf.inherited == false
    end

    test "add_user_flag/1 with soft intensity" do
      user = user_fixture()
      flag = flag_fixture()

      assert {:ok, %UserFlag{} = uf} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: flag.id,
                 color: "green",
                 intensity: "soft",
                 position: 1
               })

      assert uf.intensity == "soft"
    end

    test "add_user_flag/1 same flag and same color is rejected" do
      user = user_fixture()
      flag = flag_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: flag.id,
                 color: "white",
                 intensity: "hard",
                 position: 2
               })

      assert %{user_id: _} = errors_on(changeset)
    end

    test "add_user_flag/1 invalid color fails" do
      user = user_fixture()
      flag = flag_fixture()

      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: flag.id,
                 color: "blue",
                 intensity: "hard",
                 position: 1
               })

      assert %{color: _} = errors_on(changeset)
    end

    test "add_user_flag/1 invalid intensity fails" do
      user = user_fixture()
      flag = flag_fixture()

      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: flag.id,
                 color: "white",
                 intensity: "medium",
                 position: 1
               })

      assert %{intensity: _} = errors_on(changeset)
    end

    test "remove_user_flag/2 removes the flag" do
      user = user_fixture()
      flag = flag_fixture()

      {:ok, uf} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      assert {:ok, _} = Traits.remove_user_flag(user, uf.id)
      assert Traits.list_user_flags(user, "white") == []
    end

    test "list_user_flags/2 excludes inherited flags" do
      user = user_fixture()
      {parent, _children} = flag_with_children_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: parent.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      # list_user_flags should exclude inherited flags
      visible = Traits.list_user_flags(user, "white")
      assert length(visible) == 1
      assert hd(visible).flag_id == parent.id
      assert hd(visible).inherited == false
    end

    test "list_all_user_flags/1 includes inherited flags" do
      user = user_fixture()
      {parent, children} = flag_with_children_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: parent.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      # list_all_user_flags should include inherited flags
      all_flags = Traits.list_all_user_flags(user)
      # parent + 3 children
      assert length(all_flags) == 1 + length(children)
    end
  end

  describe "expand-on-write" do
    test "selecting a parent flag auto-creates inherited entries for children" do
      user = user_fixture()
      {parent, children} = flag_with_children_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: parent.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      all_flags = Traits.list_all_user_flags(user)
      child_ids = Enum.map(children, & &1.id)

      inherited_flags = Enum.filter(all_flags, & &1.inherited)
      inherited_flag_ids = Enum.map(inherited_flags, & &1.flag_id)

      # All children should have inherited entries
      for cid <- child_ids do
        assert cid in inherited_flag_ids
      end

      # Inherited flags should have same color and intensity as parent
      for inf <- inherited_flags do
        assert inf.color == "white"
        assert inf.intensity == "hard"
        assert inf.source_flag_id == parent.id
      end
    end

    test "removing a parent flag removes all inherited entries" do
      user = user_fixture()
      {parent, _children} = flag_with_children_fixture()

      {:ok, uf} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: parent.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      # Verify inherited flags exist
      assert length(Traits.list_all_user_flags(user)) > 1

      # Remove parent
      {:ok, _} = Traits.remove_user_flag(user, uf.id)

      # All flags (parent + inherited) should be gone
      assert Traits.list_all_user_flags(user) == []
    end
  end

  describe "no-mixing rule" do
    test "cannot select parent if child is already selected for same color" do
      user = user_fixture()
      {parent, [child | _]} = flag_with_children_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: child.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: parent.id,
                 color: "white",
                 intensity: "hard",
                 position: 2
               })

      assert %{flag_id: ["cannot select parent when children are already selected"]} =
               errors_on(changeset)
    end

    test "cannot select child if parent is already selected for same color" do
      user = user_fixture()
      {parent, [child | _]} = flag_with_children_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: parent.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      # Child should already exist as inherited, so adding explicit child fails
      assert {:error, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: child.id,
                 color: "white",
                 intensity: "hard",
                 position: 2
               })
    end

    test "can select parent and child for different colors" do
      user = user_fixture()
      category = category_fixture()

      {:ok, parent} =
        Traits.create_flag(%{
          name: "Parent X",
          emoji: "📁",
          category_id: category.id,
          position: 1
        })

      {:ok, child} =
        Traits.create_flag(%{
          name: "Child X",
          emoji: "📄",
          category_id: category.id,
          parent_id: parent.id,
          position: 1
        })

      # Select parent as white (creates inherited white entries for children)
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: parent.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      # Child has inherited white entry, but adding it as green (different color) should work
      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: child.id,
                 color: "green",
                 intensity: "hard",
                 position: 2
               })
    end
  end

  describe "single-select enforcement" do
    test "single-select category enforces one white flag" do
      category = single_select_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "Option A",
          emoji: "🅰️",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "Option B",
          emoji: "🅱️",
          category_id: category.id,
          position: 2
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: f1.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      # Second white flag in single-select category should fail
      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "white",
                 intensity: "hard",
                 position: 2
               })

      assert %{flag_id: ["single-select category allows only one flag per color"]} =
               errors_on(changeset)
    end

    test "single-select category enforces one green flag" do
      category = single_select_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "Green A",
          emoji: "🅰️",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "Green B",
          emoji: "🅱️",
          category_id: category.id,
          position: 2
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: f1.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "green",
                 intensity: "hard",
                 position: 2
               })

      assert %{flag_id: ["single-select category allows only one flag per color"]} =
               errors_on(changeset)
    end

    test "single-select category enforces one red flag" do
      category = single_select_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "Red A",
          emoji: "🅰️",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "Red B",
          emoji: "🅱️",
          category_id: category.id,
          position: 2
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: f1.id,
          color: "red",
          intensity: "hard",
          position: 1
        })

      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "red",
                 intensity: "soft",
                 position: 2
               })

      assert %{flag_id: ["single-select category allows only one flag per color"]} =
               errors_on(changeset)
    end

    test "single-select category allows different colors for the same category" do
      category = single_select_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "Option A",
          emoji: "🅰️",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "Option B",
          emoji: "🅱️",
          category_id: category.id,
          position: 2
        })

      # White flag for f1
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: f1.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      # Green flag for f2 in same category should work (different color)
      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "green",
                 intensity: "hard",
                 position: 1
               })
    end

    test "same flag can be used as white AND green by the same user" do
      category = category_fixture()
      user = user_fixture()

      {:ok, flag} =
        Traits.create_flag(%{
          name: "Same Flag",
          emoji: "🔄",
          category_id: category.id,
          position: 1
        })

      # Select as white (about me)
      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: flag.id,
                 color: "white",
                 intensity: "hard",
                 position: 1
               })

      # Same flag as green (what I like) should also work
      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: flag.id,
                 color: "green",
                 intensity: "hard",
                 position: 1
               })
    end

    test "same flag can be used as white AND red by the same user" do
      category = category_fixture()
      user = user_fixture()

      {:ok, flag} =
        Traits.create_flag(%{
          name: "Same Flag Red",
          emoji: "🔄",
          category_id: category.id,
          position: 1
        })

      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: flag.id,
                 color: "white",
                 intensity: "hard",
                 position: 1
               })

      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: flag.id,
                 color: "red",
                 intensity: "hard",
                 position: 1
               })
    end
  end

  describe "single_white selection mode" do
    test "single_white enforces one white flag per category" do
      category = single_white_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "SW Flag A",
          emoji: "🍷",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "SW Flag B",
          emoji: "🍺",
          category_id: category.id,
          position: 2
        })

      # First white flag succeeds
      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f1.id,
                 color: "white",
                 intensity: "hard",
                 position: 1
               })

      # Second white flag should fail
      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "white",
                 intensity: "hard",
                 position: 2
               })

      assert %{flag_id: ["single-select category allows only one flag per color"]} =
               errors_on(changeset)
    end

    test "single_white allows multiple green flags" do
      category = single_white_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "SW Green A",
          emoji: "🍷",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "SW Green B",
          emoji: "🍺",
          category_id: category.id,
          position: 2
        })

      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f1.id,
                 color: "green",
                 intensity: "hard",
                 position: 1
               })

      # Second green flag should succeed
      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "green",
                 intensity: "hard",
                 position: 2
               })
    end

    test "single_white allows multiple red flags" do
      category = single_white_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "SW Red A",
          emoji: "🍷",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "SW Red B",
          emoji: "🍺",
          category_id: category.id,
          position: 2
        })

      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f1.id,
                 color: "red",
                 intensity: "hard",
                 position: 1
               })

      # Second red flag should succeed
      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "red",
                 intensity: "hard",
                 position: 2
               })
    end
  end

  describe "count_user_flags/1" do
    test "returns 0 for user with no flags" do
      user = user_fixture()
      assert Traits.count_user_flags(user) == 0
    end

    test "counts only non-inherited flags" do
      user = user_fixture()
      {parent, _children} = flag_with_children_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: parent.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      # Parent creates inherited children, but count should only be 1
      assert Traits.count_user_flags(user) == 1
    end

    test "counts flags across all colors" do
      user = user_fixture()
      flag1 = flag_fixture()
      flag2 = flag_fixture()
      flag3 = flag_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag1.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag2.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag3.id,
          color: "red",
          intensity: "hard",
          position: 1
        })

      assert Traits.count_user_flags(user) == 3
    end
  end

  describe "count_user_flags_by_color/1" do
    test "returns empty map for user with no flags" do
      user = user_fixture()
      assert Traits.count_user_flags_by_color(user) == %{}
    end

    test "returns per-color counts excluding inherited flags" do
      user = user_fixture()
      flag1 = flag_fixture()
      flag2 = flag_fixture()
      flag3 = flag_fixture()
      flag4 = flag_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag1.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag2.id,
          color: "white",
          intensity: "hard",
          position: 2
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag3.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag4.id,
          color: "red",
          intensity: "hard",
          position: 1
        })

      counts = Traits.count_user_flags_by_color(user)
      assert counts == %{"white" => 2, "green" => 1, "red" => 1}
    end
  end

  describe "delete_all_user_flags/1" do
    test "deletes all flags including inherited" do
      user = user_fixture()
      {parent, _children} = flag_with_children_fixture()
      flag = flag_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: parent.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      # Verify flags exist (parent + inherited children + separate flag)
      assert Traits.list_all_user_flags(user) != []

      {:ok, _count} = Traits.delete_all_user_flags(user)

      assert Traits.list_all_user_flags(user) == []
      assert Traits.count_user_flags(user) == 0
    end

    test "returns ok with 0 when user has no flags" do
      user = user_fixture()
      assert {:ok, 0} = Traits.delete_all_user_flags(user)
    end
  end

  describe "opt-ins" do
    test "opt_into_category/2 creates an opt-in record" do
      user = user_fixture()
      category = sensitive_category_fixture()

      assert {:ok, %UserCategoryOptIn{}} = Traits.opt_into_category(user, category)
      assert Traits.user_opted_into_category?(user, category)
    end

    test "opt_into_category/2 is idempotent" do
      user = user_fixture()
      category = sensitive_category_fixture()

      assert {:ok, _} = Traits.opt_into_category(user, category)
      assert {:ok, _} = Traits.opt_into_category(user, category)
    end

    test "opt_out_of_category/2 removes opt-in and user flags" do
      user = user_fixture()
      category = sensitive_category_fixture()
      flag = flag_fixture(%{category_id: category.id})

      Traits.opt_into_category(user, category)

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      assert {:ok, _} = Traits.opt_out_of_category(user, category)
      refute Traits.user_opted_into_category?(user, category)
      assert Traits.list_user_flags(user, "white") == []
    end

    test "user_opted_into_category?/2 returns false when not opted in" do
      user = user_fixture()
      category = sensitive_category_fixture()

      refute Traits.user_opted_into_category?(user, category)
    end
  end

  describe "update_user_flag_intensity" do
    test "update_user_flag_intensity/2 changes intensity from hard to soft" do
      user = user_fixture()
      flag = flag_fixture()

      {:ok, uf} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      assert {:ok, updated} = Traits.update_user_flag_intensity(uf.id, "soft")
      assert updated.intensity == "soft"
    end

    test "update_user_flag_intensity/2 changes intensity from soft to hard" do
      user = user_fixture()
      flag = flag_fixture()

      {:ok, uf} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: "red",
          intensity: "soft",
          position: 1
        })

      assert {:ok, updated} = Traits.update_user_flag_intensity(uf.id, "hard")
      assert updated.intensity == "hard"
    end

    test "update_user_flag_intensity/2 updates inherited children's intensity" do
      user = user_fixture()
      {parent, _children} = flag_with_children_fixture()

      {:ok, uf} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: parent.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      {:ok, _updated} = Traits.update_user_flag_intensity(uf.id, "soft")

      # All inherited children should also be soft
      all_flags = Traits.list_all_user_flags(user)
      inherited = Enum.filter(all_flags, & &1.inherited)

      for inf <- inherited do
        assert inf.intensity == "soft"
      end
    end

    test "update_user_flag_intensity/2 rejects invalid intensity" do
      user = user_fixture()
      flag = flag_fixture()

      {:ok, uf} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      assert {:error, _changeset} = Traits.update_user_flag_intensity(uf.id, "medium")
    end
  end

  describe "matching" do
    test "compute_flag_overlap/2 finds matching white-white flags" do
      user_a = user_fixture()
      user_b = user_fixture()
      flag = flag_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      overlap = Traits.compute_flag_overlap(user_a, user_b)
      assert length(overlap.white_white) == 1
    end

    test "compute_flag_overlap/2 finds green-white matches" do
      user_a = user_fixture()
      user_b = user_fixture()
      flag = flag_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: flag.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      overlap = Traits.compute_flag_overlap(user_a, user_b)
      # B's green matches A's white
      assert overlap.green_white != []
    end

    test "compute_flag_overlap/2 finds red-white conflicts" do
      user_a = user_fixture()
      user_b = user_fixture()
      flag = flag_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: flag.id,
          color: "red",
          intensity: "hard",
          position: 1
        })

      overlap = Traits.compute_flag_overlap(user_a, user_b)
      assert overlap.red_white != []
    end

    test "compute_flag_overlap/2 is bidirectional" do
      user_a = user_fixture()
      user_b = user_fixture()
      flag = flag_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: flag.id,
          color: "green",
          intensity: "soft",
          position: 1
        })

      overlap = Traits.compute_flag_overlap(user_a, user_b)
      # B's green matches A's white
      assert overlap.green_white != []
    end

    test "compute_flag_overlap/2 respects sensitive opt-in" do
      user_a = user_fixture()
      user_b = user_fixture()
      category = sensitive_category_fixture()
      flag = flag_fixture(%{category_id: category.id})

      # Both opt in
      Traits.opt_into_category(user_a, category)
      Traits.opt_into_category(user_b, category)

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      overlap = Traits.compute_flag_overlap(user_a, user_b)
      assert length(overlap.white_white) == 1
    end

    test "compute_flag_overlap/2 excludes sensitive flags when one user not opted in" do
      user_a = user_fixture()
      user_b = user_fixture()
      category = sensitive_category_fixture()
      flag = flag_fixture(%{category_id: category.id})

      # Only user_a opts in
      Traits.opt_into_category(user_a, category)

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      overlap = Traits.compute_flag_overlap(user_a, user_b)
      assert overlap.white_white == []
    end

    test "expand-on-write enables matching on child flags" do
      user_a = user_fixture()
      user_b = user_fixture()
      {parent, [child | _]} = flag_with_children_fixture()

      # User A selects parent (expand-on-write creates child entries)
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: parent.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      # User B selects specific child
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: child.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      overlap = Traits.compute_flag_overlap(user_a, user_b)
      # B's green child matches A's inherited white child
      assert overlap.green_white != []
    end

    test "compute_flag_overlap/2 returns intensity-annotated green_white matches" do
      user_a = user_fixture()
      user_b = user_fixture()
      flag_hard = flag_fixture()
      flag_soft = flag_fixture()

      # User A has two white flags
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: flag_hard.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: flag_soft.id,
          color: "white",
          intensity: "hard",
          position: 2
        })

      # User B has green flags with different intensities
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: flag_hard.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: flag_soft.id,
          color: "green",
          intensity: "soft",
          position: 2
        })

      overlap = Traits.compute_flag_overlap(user_a, user_b)

      # Combined list preserved for backward compatibility
      assert length(overlap.green_white) == 2

      # Hard green match
      assert flag_hard.id in overlap.green_white_hard
      refute flag_soft.id in overlap.green_white_hard

      # Soft green match
      assert flag_soft.id in overlap.green_white_soft
      refute flag_hard.id in overlap.green_white_soft
    end

    test "compute_flag_overlap/2 returns intensity-annotated red_white matches" do
      user_a = user_fixture()
      user_b = user_fixture()
      flag_hard = flag_fixture()
      flag_soft = flag_fixture()

      # User A has two white flags
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: flag_hard.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: flag_soft.id,
          color: "white",
          intensity: "hard",
          position: 2
        })

      # User B has red flags with different intensities
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: flag_hard.id,
          color: "red",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: flag_soft.id,
          color: "red",
          intensity: "soft",
          position: 2
        })

      overlap = Traits.compute_flag_overlap(user_a, user_b)

      # Combined list preserved for backward compatibility
      assert length(overlap.red_white) == 2

      # Hard red match (deal breaker)
      assert flag_hard.id in overlap.red_white_hard
      refute flag_soft.id in overlap.red_white_hard

      # Soft red match (prefer not)
      assert flag_soft.id in overlap.red_white_soft
      refute flag_hard.id in overlap.red_white_soft
    end
  end

  describe "alcohol frequency (single-select sensitive)" do
    setup do
      {:ok, category} =
        Traits.create_category(%{
          name: "Alcohol #{System.unique_integer([:positive])}",
          selection_mode: "single",
          sensitive: true,
          position: System.unique_integer([:positive])
        })

      flags =
        for {name, emoji, pos} <- [
              {"None at All", "🚫", 1},
              {"Rarely", "🥂", 2},
              {"Sometimes", "🍷", 3},
              {"Often", "🍻", 4}
            ] do
          {:ok, flag} =
            Traits.create_flag(%{
              name: name,
              emoji: emoji,
              category_id: category.id,
              position: pos
            })

          flag
        end

      %{category: category, flags: flags}
    end

    test "user can select one alcohol frequency as white flag", %{
      category: _category,
      flags: [_none, rarely, _sometimes, _often]
    } do
      user = user_fixture()

      assert {:ok, uf} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: rarely.id,
                 color: "white",
                 intensity: "hard",
                 position: 1
               })

      assert uf.flag_id == rarely.id
      assert uf.color == "white"
    end

    test "single-select prevents two white flags in alcohol category", %{
      category: _category,
      flags: [_none, rarely, sometimes, _often]
    } do
      user = user_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: rarely.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: sometimes.id,
                 color: "white",
                 intensity: "hard",
                 position: 2
               })

      assert %{flag_id: ["single-select category allows only one flag per color"]} =
               errors_on(changeset)
    end

    test "alcohol flags visible only after opt-in", %{category: category} do
      user = user_fixture()

      visible = Traits.list_visible_categories(user)
      visible_ids = Enum.map(visible, & &1.id)
      refute category.id in visible_ids

      Traits.opt_into_category(user, category)

      visible = Traits.list_visible_categories(user)
      visible_ids = Enum.map(visible, & &1.id)
      assert category.id in visible_ids
    end

    test "alcohol overlap requires mutual opt-in", %{
      category: category,
      flags: [_none, rarely, _sometimes, _often]
    } do
      user_a = user_fixture()
      user_b = user_fixture()

      Traits.opt_into_category(user_a, category)

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: rarely.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: rarely.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      # Without mutual opt-in, no overlap
      overlap = Traits.compute_flag_overlap(user_a, user_b)
      assert overlap.white_white == []

      # With mutual opt-in, overlap found
      Traits.opt_into_category(user_b, category)
      overlap = Traits.compute_flag_overlap(user_a, user_b)
      assert length(overlap.white_white) == 1
    end
  end

  describe "smoking frequency (single-select sensitive)" do
    setup do
      {:ok, category} =
        Traits.create_category(%{
          name: "Smoking #{System.unique_integer([:positive])}",
          selection_mode: "single",
          sensitive: true,
          position: System.unique_integer([:positive])
        })

      flags =
        for {name, emoji, pos} <- [
              {"None at All", "🚫", 1},
              {"Rarely", "🚬", 2},
              {"Sometimes", "🚬", 3},
              {"Often", "🚬", 4}
            ] do
          {:ok, flag} =
            Traits.create_flag(%{
              name: name,
              emoji: emoji,
              category_id: category.id,
              position: pos
            })

          flag
        end

      %{category: category, flags: flags}
    end

    test "user can select one smoking frequency as white flag", %{
      flags: [_none, rarely, _sometimes, _often]
    } do
      user = user_fixture()

      assert {:ok, uf} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: rarely.id,
                 color: "white",
                 intensity: "hard",
                 position: 1
               })

      assert uf.flag_id == rarely.id
    end

    test "single-select prevents two white flags in smoking category", %{
      flags: [_none, rarely, sometimes, _often]
    } do
      user = user_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: rarely.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: sometimes.id,
                 color: "white",
                 intensity: "hard",
                 position: 2
               })

      assert %{flag_id: ["single-select category allows only one flag per color"]} =
               errors_on(changeset)
    end

    test "smoking flags visible only after opt-in", %{category: category} do
      user = user_fixture()

      visible = Traits.list_visible_categories(user)
      refute category.id in Enum.map(visible, & &1.id)

      Traits.opt_into_category(user, category)

      visible = Traits.list_visible_categories(user)
      assert category.id in Enum.map(visible, & &1.id)
    end
  end

  describe "seeded category: Relationship Status" do
    test "category uses single_white selection mode" do
      categories = Traits.list_categories()

      category =
        Enum.find(categories, fn c -> c.name == "Relationship Status" end)

      assert category != nil
      assert category.selection_mode == "single_white"
    end
  end

  describe "seeded category: What I'm Looking For" do
    test "category exists with correct attributes" do
      categories = Traits.list_categories()

      category =
        Enum.find(categories, fn c -> c.name == "What I'm Looking For" end)

      assert category != nil
      assert category.selection_mode == "multi"
      assert category.sensitive == false
      assert category.position == 2
    end

    test "category has all 8 flags" do
      categories = Traits.list_categories()
      category = Enum.find(categories, fn c -> c.name == "What I'm Looking For" end)
      assert category != nil

      flags = Traits.list_top_level_flags_by_category(category)
      assert length(flags) == 8

      flag_names = Enum.map(flags, & &1.name)
      assert "Long-term Relationship" in flag_names
      assert "Marriage" in flag_names
      assert "Something Casual" in flag_names
      assert "Friendship" in flag_names
      assert "Don't Know Yet" in flag_names
      assert "Dates" in flag_names
      assert "Shared Activities" in flag_names
      assert "Open Relationship" in flag_names
    end
  end

  describe "seeded category: Political Parties" do
    test "category exists with correct name" do
      categories = Traits.list_categories()

      category =
        Enum.find(categories, fn c -> c.name == "Political Parties" end)

      assert category != nil
      assert category.selection_mode == "multi"
      assert category.sensitive == true
    end

    test "category has all 7 flags" do
      categories = Traits.list_categories()
      category = Enum.find(categories, fn c -> c.name == "Political Parties" end)
      assert category != nil

      flags = Traits.list_top_level_flags_by_category(category)
      assert length(flags) == 7

      flag_names = Enum.map(flags, & &1.name)
      assert "CDU" in flag_names
      assert "SPD" in flag_names
      assert "Die Grünen" in flag_names
      assert "FDP" in flag_names
      assert "AfD" in flag_names
      assert "The Left" in flag_names
      assert "CSU" in flag_names
    end
  end

  describe "seeded category: Sexual Preferences" do
    test "category exists with correct attributes" do
      categories = Traits.list_categories()

      category =
        Enum.find(categories, fn c -> c.name == "Sexual Preferences" end)

      assert category != nil
      assert category.selection_mode == "multi"
      assert category.sensitive == true
    end

    test "category has all 14 flags" do
      categories = Traits.list_categories()
      category = Enum.find(categories, fn c -> c.name == "Sexual Preferences" end)
      assert category != nil

      flags = Traits.list_top_level_flags_by_category(category)
      assert length(flags) == 14

      flag_names = Enum.map(flags, & &1.name)
      assert "Vanilla" in flag_names
      assert "Dominant" in flag_names
      assert "Submissive" in flag_names
      assert "Switch" in flag_names
      assert "Bondage" in flag_names
      assert "S&M" in flag_names
      assert "Role Play" in flag_names
      assert "Tantra" in flag_names
      assert "Fetish" in flag_names
      assert "Exhibitionism" in flag_names
      assert "Voyeurism" in flag_names
      assert "Group Play" in flag_names
      assert "Toys" in flag_names
      assert "Swinging" in flag_names
    end

    test "category requires opt-in for visibility" do
      user = user_fixture()

      categories = Traits.list_categories()
      category = Enum.find(categories, fn c -> c.name == "Sexual Preferences" end)

      visible = Traits.list_visible_categories(user)
      visible_ids = Enum.map(visible, & &1.id)
      refute category.id in visible_ids

      Traits.opt_into_category(user, category)

      visible = Traits.list_visible_categories(user)
      visible_ids = Enum.map(visible, & &1.id)
      assert category.id in visible_ids
    end

    test "sensitive flags excluded from matching without mutual opt-in" do
      user_a = user_fixture()
      user_b = user_fixture()

      categories = Traits.list_categories()
      category = Enum.find(categories, fn c -> c.name == "Sexual Preferences" end)
      flags = Traits.list_top_level_flags_by_category(category)
      flag = hd(flags)

      # Only user_a opts in
      Traits.opt_into_category(user_a, category)

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      overlap = Traits.compute_flag_overlap(user_a, user_b)
      assert overlap.white_white == []

      # With mutual opt-in, overlap found
      Traits.opt_into_category(user_b, category)
      overlap = Traits.compute_flag_overlap(user_a, user_b)
      assert length(overlap.white_white) == 1
    end
  end

  describe "seeded category: Sexual Practices" do
    test "category exists with correct attributes" do
      categories = Traits.list_categories()

      category =
        Enum.find(categories, fn c -> c.name == "Sexual Practices" end)

      assert category != nil
      assert category.selection_mode == "multi"
      assert category.sensitive == true
    end

    test "category has all 22 flags" do
      categories = Traits.list_categories()
      category = Enum.find(categories, fn c -> c.name == "Sexual Practices" end)
      assert category != nil

      flags = Traits.list_top_level_flags_by_category(category)
      assert length(flags) == 22

      flag_names = Enum.map(flags, & &1.name)

      # Giving/Receiving practices (flat)
      assert "Oral Sex: Giving" in flag_names
      assert "Oral Sex: Receiving" in flag_names
      assert "Anal Sex: Giving" in flag_names
      assert "Anal Sex: Receiving" in flag_names
      assert "Fingering: Giving" in flag_names
      assert "Fingering: Receiving" in flag_names
      assert "Rimming: Giving" in flag_names
      assert "Rimming: Receiving" in flag_names
      assert "Massage: Giving" in flag_names
      assert "Massage: Receiving" in flag_names

      # Other practices (flat)
      assert "Vaginal Sex" in flag_names
      assert "Kissing" in flag_names
      assert "Dirty Talk" in flag_names
      assert "Sexting" in flag_names
      assert "Phone Sex" in flag_names

      # Positions (flat)
      assert "Missionary" in flag_names
      assert "Doggy Style" in flag_names
      assert "Cowgirl" in flag_names
      assert "Spooning" in flag_names
      assert "69" in flag_names
      assert "Standing" in flag_names
      assert "Against the Wall" in flag_names
    end

    test "category requires opt-in for visibility" do
      user = user_fixture()

      categories = Traits.list_categories()
      category = Enum.find(categories, fn c -> c.name == "Sexual Practices" end)

      visible = Traits.list_visible_categories(user)
      visible_ids = Enum.map(visible, & &1.id)
      refute category.id in visible_ids

      Traits.opt_into_category(user, category)

      visible = Traits.list_visible_categories(user)
      visible_ids = Enum.map(visible, & &1.id)
      assert category.id in visible_ids
    end

    test "sensitive flags excluded from matching without mutual opt-in" do
      user_a = user_fixture()
      user_b = user_fixture()

      categories = Traits.list_categories()
      category = Enum.find(categories, fn c -> c.name == "Sexual Practices" end)
      flags = Traits.list_top_level_flags_by_category(category)

      # Use a flat flag (no children) to get a clean single-flag overlap
      flag = Enum.find(flags, fn f -> f.name == "Kissing" end)

      # Only user_a opts in
      Traits.opt_into_category(user_a, category)

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_a.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user_b.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      overlap = Traits.compute_flag_overlap(user_a, user_b)
      assert overlap.white_white == []

      # With mutual opt-in, overlap found
      Traits.opt_into_category(user_b, category)
      overlap = Traits.compute_flag_overlap(user_a, user_b)
      assert length(overlap.white_white) == 1
    end
  end

  describe "exclusive_hard enforcement" do
    test "can add one green hard flag in exclusive_hard category" do
      category = exclusive_hard_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "EH Flag A",
          emoji: "💚",
          category_id: category.id,
          position: 1
        })

      assert {:ok, uf} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f1.id,
                 color: "green",
                 intensity: "hard",
                 position: 1
               })

      assert uf.intensity == "hard"
    end

    test "cannot add a second green hard flag in exclusive_hard category" do
      category = exclusive_hard_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "EH Flag A",
          emoji: "💚",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "EH Flag B",
          emoji: "💚",
          category_id: category.id,
          position: 2
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: f1.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "green",
                 intensity: "hard",
                 position: 2
               })

      assert %{flag_id: _} = errors_on(changeset)
    end

    test "can add multiple green soft flags in exclusive_hard category" do
      category = exclusive_hard_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "EH Soft A",
          emoji: "💚",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "EH Soft B",
          emoji: "💚",
          category_id: category.id,
          position: 2
        })

      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f1.id,
                 color: "green",
                 intensity: "soft",
                 position: 1
               })

      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "green",
                 intensity: "soft",
                 position: 2
               })
    end

    test "cannot add green soft when green hard exists in exclusive_hard category" do
      category = exclusive_hard_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "EH Hard",
          emoji: "💚",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "EH Soft",
          emoji: "💚",
          category_id: category.id,
          position: 2
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: f1.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "green",
                 intensity: "soft",
                 position: 2
               })

      assert %{flag_id: _} = errors_on(changeset)
    end

    test "cannot add green hard when green soft exists in exclusive_hard category" do
      category = exclusive_hard_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "EH Soft First",
          emoji: "💚",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "EH Hard Second",
          emoji: "💚",
          category_id: category.id,
          position: 2
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: f1.id,
          color: "green",
          intensity: "soft",
          position: 1
        })

      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "green",
                 intensity: "hard",
                 position: 2
               })

      assert %{flag_id: _} = errors_on(changeset)
    end

    test "red flags are exempt from exclusive_hard constraint" do
      category = exclusive_hard_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "EH Red A",
          emoji: "🔴",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "EH Red B",
          emoji: "🔴",
          category_id: category.id,
          position: 2
        })

      {:ok, f3} =
        Traits.create_flag(%{
          name: "EH Red C",
          emoji: "🔴",
          category_id: category.id,
          position: 3
        })

      # Multiple red hard flags allowed
      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f1.id,
                 color: "red",
                 intensity: "hard",
                 position: 1
               })

      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "red",
                 intensity: "hard",
                 position: 2
               })

      # Red soft also allowed alongside red hard
      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f3.id,
                 color: "red",
                 intensity: "soft",
                 position: 3
               })
    end

    test "promoting red soft to hard succeeds even with other red flags" do
      category = exclusive_hard_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "EH Red Promote A",
          emoji: "🔴",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "EH Red Promote B",
          emoji: "🔴",
          category_id: category.id,
          position: 2
        })

      {:ok, uf1} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: f1.id,
          color: "red",
          intensity: "soft",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: f2.id,
          color: "red",
          intensity: "soft",
          position: 2
        })

      # Promoting red soft to hard succeeds despite other red flags
      assert {:ok, updated} = Traits.update_user_flag_intensity(uf1.id, "hard")
      assert updated.intensity == "hard"
    end

    test "exclusive_hard_has_others? returns false for red flags" do
      category = exclusive_hard_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "EH Red Others A",
          emoji: "🔴",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "EH Red Others B",
          emoji: "🔴",
          category_id: category.id,
          position: 2
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: f1.id,
          color: "red",
          intensity: "soft",
          position: 1
        })

      # Should return false for red even though other red flags exist
      refute Traits.exclusive_hard_has_others?(user.id, f2.id, "red")
    end

    test "white flags unaffected by exclusive_hard constraint" do
      category = exclusive_hard_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "EH White A",
          emoji: "⬜",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "EH White B",
          emoji: "⬜",
          category_id: category.id,
          position: 2
        })

      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f1.id,
                 color: "white",
                 intensity: "hard",
                 position: 1
               })

      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "white",
                 intensity: "hard",
                 position: 2
               })
    end

    test "updating intensity soft->hard rejected when other flags of same color exist" do
      category = exclusive_hard_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "EH Update A",
          emoji: "💚",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "EH Update B",
          emoji: "💚",
          category_id: category.id,
          position: 2
        })

      {:ok, uf1} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: f1.id,
          color: "green",
          intensity: "soft",
          position: 1
        })

      {:ok, _uf2} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: f2.id,
          color: "green",
          intensity: "soft",
          position: 2
        })

      # Promoting to hard should fail because other soft flags exist
      assert {:error, changeset} = Traits.update_user_flag_intensity(uf1.id, "hard")
      assert %{flag_id: _} = errors_on(changeset)
    end

    test "updating intensity hard->soft always succeeds in exclusive_hard category" do
      category = exclusive_hard_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "EH Downgrade",
          emoji: "💚",
          category_id: category.id,
          position: 1
        })

      {:ok, uf} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: f1.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      assert {:ok, updated} = Traits.update_user_flag_intensity(uf.id, "soft")
      assert updated.intensity == "soft"
    end

    test "green and red constraints are independent" do
      category = exclusive_hard_category_fixture()
      user = user_fixture()

      {:ok, f1} =
        Traits.create_flag(%{
          name: "EH Cross A",
          emoji: "💚",
          category_id: category.id,
          position: 1
        })

      {:ok, f2} =
        Traits.create_flag(%{
          name: "EH Cross B",
          emoji: "🔴",
          category_id: category.id,
          position: 2
        })

      {:ok, f3} =
        Traits.create_flag(%{
          name: "EH Cross C",
          emoji: "🔴",
          category_id: category.id,
          position: 3
        })

      # One green hard — still constrained by exclusive_hard
      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f1.id,
                 color: "green",
                 intensity: "hard",
                 position: 1
               })

      # Multiple red hard — red is exempt from exclusive_hard
      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f2.id,
                 color: "red",
                 intensity: "hard",
                 position: 1
               })

      assert {:ok, _} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: f3.id,
                 color: "red",
                 intensity: "hard",
                 position: 2
               })
    end
  end

  describe "core/optin categories" do
    test "list_core_categories/0 returns only core=true categories ordered by position" do
      core = core_category_fixture(%{position: 2})
      _optin = optin_category_fixture(%{position: 1})

      cores = Traits.list_core_categories()
      core_ids = Enum.map(cores, & &1.id)
      assert core.id in core_ids
      refute Enum.any?(cores, fn c -> c.core == false end)

      # Verify ordering by position
      positions = Enum.map(cores, & &1.position)
      assert positions == Enum.sort(positions)
    end

    test "list_optin_categories/0 returns only core=false categories ordered by position" do
      _core = core_category_fixture(%{position: 1})
      optin = optin_category_fixture(%{position: 2})

      optins = Traits.list_optin_categories()
      optin_ids = Enum.map(optins, & &1.id)
      assert optin.id in optin_ids
      refute Enum.any?(optins, fn c -> c.core == true end)

      # Verify ordering by position
      positions = Enum.map(optins, & &1.position)
      assert positions == Enum.sort(positions)
    end

    test "list_wizard_categories/1 returns core + user opted-in categories" do
      user = user_fixture()
      core = core_category_fixture(%{position: 1})
      optin = optin_category_fixture(%{position: 2})
      _other_optin = optin_category_fixture(%{position: 3})

      # Before opting in, only core categories visible
      cats = Traits.list_wizard_categories(user)
      cat_ids = Enum.map(cats, & &1.id)
      assert core.id in cat_ids
      refute optin.id in cat_ids

      # After opting in, both core and opted-in visible
      Traits.toggle_category_optin(user, optin)
      cats = Traits.list_wizard_categories(user)
      cat_ids = Enum.map(cats, & &1.id)
      assert core.id in cat_ids
      assert optin.id in cat_ids
    end

    test "toggle_category_optin/2 creates opt-in record when not opted in" do
      user = user_fixture()
      optin = optin_category_fixture()

      assert {:ok, _} = Traits.toggle_category_optin(user, optin)
      assert optin.id in Traits.list_user_optin_category_ids(user)
    end

    test "toggle_category_optin/2 removes opt-in record when already opted in" do
      user = user_fixture()
      optin = optin_category_fixture()

      {:ok, _} = Traits.toggle_category_optin(user, optin)
      assert optin.id in Traits.list_user_optin_category_ids(user)

      {:ok, _} = Traits.toggle_category_optin(user, optin)
      refute optin.id in Traits.list_user_optin_category_ids(user)
    end

    test "toggle_category_optin/2 does NOT delete user_flags when opting out" do
      user = user_fixture()
      optin = optin_category_fixture()
      flag = flag_fixture(%{category_id: optin.id})

      # Opt in and add a flag
      {:ok, _} = Traits.toggle_category_optin(user, optin)

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      # Toggle off (opt out via picker)
      {:ok, _} = Traits.toggle_category_optin(user, optin)

      # Flag should still exist in DB
      assert Traits.list_user_flags(user, "white") != []
    end

    test "list_user_optin_category_ids/1 returns category IDs from opt-ins" do
      user = user_fixture()
      optin1 = optin_category_fixture()
      optin2 = optin_category_fixture()

      Traits.toggle_category_optin(user, optin1)
      Traits.toggle_category_optin(user, optin2)

      ids = Traits.list_user_optin_category_ids(user)
      assert optin1.id in ids
      assert optin2.id in ids
    end
  end

  describe "marijuana frequency (single-select sensitive)" do
    setup do
      {:ok, category} =
        Traits.create_category(%{
          name: "Marijuana #{System.unique_integer([:positive])}",
          selection_mode: "single",
          sensitive: true,
          position: System.unique_integer([:positive])
        })

      flags =
        for {name, emoji, pos} <- [
              {"None at All", "🚫", 1},
              {"Rarely", "🌿", 2},
              {"Sometimes", "🌿", 3},
              {"Often", "🌿", 4}
            ] do
          {:ok, flag} =
            Traits.create_flag(%{
              name: name,
              emoji: emoji,
              category_id: category.id,
              position: pos
            })

          flag
        end

      %{category: category, flags: flags}
    end

    test "user can select one marijuana frequency as white flag", %{
      flags: [_none, _rarely, sometimes, _often]
    } do
      user = user_fixture()

      assert {:ok, uf} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: sometimes.id,
                 color: "white",
                 intensity: "hard",
                 position: 1
               })

      assert uf.flag_id == sometimes.id
    end

    test "single-select prevents two white flags in marijuana category", %{
      flags: [none, _rarely, sometimes, _often]
    } do
      user = user_fixture()

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: none.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      assert {:error, changeset} =
               Traits.add_user_flag(%{
                 user_id: user.id,
                 flag_id: sometimes.id,
                 color: "white",
                 intensity: "hard",
                 position: 2
               })

      assert %{flag_id: ["single-select category allows only one flag per color"]} =
               errors_on(changeset)
    end

    test "marijuana flags visible only after opt-in", %{category: category} do
      user = user_fixture()

      visible = Traits.list_visible_categories(user)
      refute category.id in Enum.map(visible, & &1.id)

      Traits.opt_into_category(user, category)

      visible = Traits.list_visible_categories(user)
      assert category.id in Enum.map(visible, & &1.id)
    end
  end
end
