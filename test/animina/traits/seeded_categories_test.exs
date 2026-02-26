defmodule Animina.Traits.SeededCategoriesTest do
  @moduledoc """
  Tests that verify seeded trait categories and their flags exist correctly.
  Extracted from traits_test.exs for better organization.
  """
  use Animina.DataCase, async: true

  alias Animina.Traits

  import Animina.AccountsFixtures

  # Helper to find a seeded category by name
  defp find_category(name) do
    Traits.list_categories() |> Enum.find(fn c -> c.name == name end)
  end

  # Helper to get flags for a category
  defp flags_for(category), do: Traits.list_top_level_flags_by_category(category)

  # Helper to get flag names for a category
  defp flag_names_for(category), do: flags_for(category) |> Enum.map(& &1.name)

  describe "seeded category: Relationship Status" do
    test "category uses single_white selection mode" do
      category = find_category("Relationship Status")

      assert category != nil
      assert category.selection_mode == "single_white"
    end
  end

  describe "seeded category: What I'm Looking For" do
    test "category exists with correct attributes" do
      category = find_category("What I'm Looking For")

      assert category != nil
      assert category.selection_mode == "multi"
      assert category.sensitive == false
      assert category.position == 2
    end

    test "category has all 8 flags" do
      category = find_category("What I'm Looking For")
      assert category != nil

      names = flag_names_for(category)
      assert length(names) == 8

      for name <- [
            "Long-term Relationship",
            "Marriage",
            "Something Casual",
            "Friendship",
            "Don't Know Yet",
            "Dates",
            "Shared Activities",
            "Open Relationship"
          ] do
        assert name in names
      end
    end
  end

  describe "seeded category: Political Parties" do
    test "category exists with correct name" do
      category = find_category("Political Parties")

      assert category != nil
      assert category.selection_mode == "multi"
      assert category.sensitive == true
    end

    test "category has all 7 flags" do
      category = find_category("Political Parties")
      assert category != nil

      names = flag_names_for(category)
      assert length(names) == 7

      for name <- ["CDU", "SPD", "Die Grünen", "FDP", "AfD", "The Left", "CSU"] do
        assert name in names
      end
    end
  end

  # Sensitive categories with opt-in visibility and mutual opt-in matching
  for {cat_name, flag_count, expected_flags, match_flag} <- [
        {"Sexual Preferences", 14,
         ~w(Vanilla Dominant Submissive Switch Bondage S&M Tantra Fetish Exhibitionism Voyeurism Swinging) ++
           ["Role Play", "Group Play", "Toys"], nil},
        {"Sexual Practices", 20,
         [
           "Oral Sex: Giving",
           "Oral Sex: Receiving",
           "Anal Sex: Giving",
           "Anal Sex: Receiving",
           "Fingering: Giving",
           "Fingering: Receiving",
           "Massage: Giving",
           "Massage: Receiving",
           "Vaginal Sex",
           "Kissing",
           "Dirty Talk",
           "Sexting",
           "Phone Sex",
           "Missionary",
           "Doggy Style",
           "Cowgirl",
           "Spooning",
           "69",
           "Standing",
           "Against the Wall"
         ], "Kissing"}
      ] do
    describe "seeded category: #{cat_name}" do
      test "category exists with correct attributes" do
        category = find_category(unquote(cat_name))

        assert category != nil
        assert category.selection_mode == "multi"
        assert category.sensitive == true
      end

      test "category has all expected flags" do
        category = find_category(unquote(cat_name))
        assert category != nil

        names = flag_names_for(category)
        assert length(names) == unquote(flag_count)

        for name <- unquote(expected_flags) do
          assert name in names
        end
      end

      test "category requires opt-in for visibility" do
        user = user_fixture()
        category = find_category(unquote(cat_name))

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

        category = find_category(unquote(cat_name))
        flags = flags_for(category)

        flag =
          if unquote(match_flag),
            do: Enum.find(flags, fn f -> f.name == unquote(match_flag) end),
            else: hd(flags)

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
  end

  describe "seeded category: Languages" do
    test "category exists with correct attributes" do
      category = find_category("Languages")

      assert category != nil
      assert category.selection_mode == "multi"
      assert category.sensitive == false
      assert category.core == true
    end

    test "category has all 9 language flags" do
      category = find_category("Languages")
      assert category != nil

      names = flag_names_for(category)
      assert length(names) == 9

      for name <- ~w(Deutsch English Türkçe Русский العربية Polski Français Español Українська) do
        assert name in names
      end
    end

    test "flags have correct emoji" do
      category = find_category("Languages")
      flags = flags_for(category)

      deutsch = Enum.find(flags, fn f -> f.name == "Deutsch" end)
      assert deutsch.emoji == "🇩🇪"

      english = Enum.find(flags, fn f -> f.name == "English" end)
      assert english.emoji == "🇬🇧"
    end
  end

  describe "seeded category: Body Type" do
    test "category exists with correct attributes" do
      category = find_category("Body Type")

      assert category != nil
      assert category.selection_mode == "single"
      assert category.core == true
      assert category.sensitive == false
      assert category.position == 7
    end

    test "category has all 5 flags" do
      category = find_category("Body Type")
      assert category != nil

      names = flag_names_for(category)
      assert length(names) == 5

      for name <- ~w(Slim Average Athletic Curvy Plus-Size) do
        assert name in names
      end
    end

    test "flags have correct emojis and positions" do
      category = find_category("Body Type")
      flags = flags_for(category)

      for {name, emoji, pos} <- [
            {"Slim", "🦊", 1},
            {"Average", "📏", 2},
            {"Athletic", "🏋️", 3},
            {"Curvy", "🧸", 4},
            {"Plus-Size", "🐻", 5}
          ] do
        flag = Enum.find(flags, fn f -> f.name == name end)
        assert flag.emoji == emoji
        assert flag.position == pos
      end
    end

    test "category is visible by default as a core category" do
      user = user_fixture()

      category = find_category("Body Type")
      assert category.core == true

      visible = Traits.list_visible_categories(user)
      visible_ids = Enum.map(visible, & &1.id)
      assert category.id in visible_ids
    end
  end

  describe "seeded category: Travels" do
    test "category has all 14 flags including travel style flags" do
      category = find_category("Travels")
      assert category != nil

      names = flag_names_for(category)
      assert length(names) == 14

      # Original 10 travel type flags
      for name <- [
            "Beach",
            "City Trips",
            "Hiking Vacation",
            "Cruises",
            "Bike Tours",
            "Wellness",
            "Active and Sports Vacation",
            "Camping",
            "Cultural Trips",
            "Winter Sports"
          ] do
        assert name in names
      end

      # 4 new travel style flags
      for name <- ["Luxury", "Backpacking", "Low-Budget", "Adventure Travel"] do
        assert name in names
      end
    end
  end

  describe "seeded category: Love Languages" do
    test "category exists with correct attributes" do
      category = find_category("Love Languages")

      assert category != nil
      assert category.selection_mode == "single_white"
      assert category.core == false
      assert category.sensitive == false
      assert category.picker_group == "lifestyle"
      assert category.position == 30
    end

    test "category has all 5 flags" do
      category = find_category("Love Languages")
      assert category != nil

      names = flag_names_for(category)
      assert length(names) == 5

      for name <- [
            "Words of Affirmation",
            "Quality Time",
            "Acts of Service",
            "Receiving Gifts",
            "Physical Touch"
          ] do
        assert name in names
      end
    end

    test "flags have correct emojis and positions" do
      category = find_category("Love Languages")
      flags = flags_for(category)

      for {name, emoji, pos} <- [
            {"Words of Affirmation", "💬", 1},
            {"Quality Time", "⏰", 2},
            {"Acts of Service", "🤝", 3},
            {"Receiving Gifts", "🎁", 4},
            {"Physical Touch", "🫂", 5}
          ] do
        flag = Enum.find(flags, fn f -> f.name == name end)
        assert flag.emoji == emoji
        assert flag.position == pos
      end
    end
  end
end
