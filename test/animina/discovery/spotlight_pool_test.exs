defmodule Animina.Discovery.SpotlightPoolTest do
  use Animina.DataCase, async: true

  import Animina.AccountsFixtures

  alias Animina.Accounts.ContactBlacklist
  alias Animina.Discovery.SpotlightPool
  alias Animina.Traits
  alias Animina.Traits.UserFlag

  # Helper to activate a user (change state from waitlisted to normal)
  defp activate_user(user) do
    user
    |> Ecto.Changeset.change(state: "normal")
    |> Repo.update!()
  end

  # Helper to preload locations (needed for coordinate lookups)
  defp preload_locations(user) do
    Repo.preload(user, :locations)
  end

  # Helper to create a trait flag for testing
  defp create_test_flag!(name) do
    {:ok, category} =
      Traits.create_category(%{
        name: "Test Category #{System.unique_integer([:positive])}",
        position: 1
      })

    {:ok, flag} =
      Traits.create_flag(%{
        name: name,
        category_id: category.id,
        position: 1
      })

    flag
  end

  # Helper to add a user flag directly via Repo (bypassing validations for test speed)
  defp add_flag!(user, flag, color, intensity \\ "hard") do
    %UserFlag{}
    |> UserFlag.changeset(%{
      user_id: user.id,
      flag_id: flag.id,
      color: color,
      intensity: intensity,
      position: 1
    })
    |> Repo.insert!()
  end

  describe "blacklist filter" do
    setup do
      viewer =
        user_fixture(%{gender: "male", preferred_partner_gender: ["female"]})
        |> activate_user()
        |> preload_locations()

      candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          display_name: "Candidate"
        })
        |> activate_user()
        |> preload_locations()

      %{viewer: viewer, candidate: candidate}
    end

    test "viewer blacklists candidate → excluded", %{viewer: viewer, candidate: candidate} do
      {:ok, _} = ContactBlacklist.add_entry(viewer, %{value: candidate.email})

      results = SpotlightPool.build(viewer)
      ids = Enum.map(results, & &1.id)

      refute candidate.id in ids
    end

    test "candidate blacklists viewer → excluded", %{viewer: viewer, candidate: candidate} do
      {:ok, _} = ContactBlacklist.add_entry(candidate, %{value: viewer.email})

      results = SpotlightPool.build(viewer)
      ids = Enum.map(results, & &1.id)

      refute candidate.id in ids
    end
  end

  describe "hard red conflicts" do
    setup do
      viewer =
        user_fixture(%{gender: "male", preferred_partner_gender: ["female"]})
        |> activate_user()
        |> preload_locations()

      candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          display_name: "Candidate"
        })
        |> activate_user()
        |> preload_locations()

      flag = create_test_flag!("Test Trait")

      %{viewer: viewer, candidate: candidate, flag: flag}
    end

    test "viewer hard-red + candidate white → excluded", %{
      viewer: viewer,
      candidate: candidate,
      flag: flag
    } do
      add_flag!(viewer, flag, "red", "hard")
      add_flag!(candidate, flag, "white")

      results = SpotlightPool.build(viewer)
      ids = Enum.map(results, & &1.id)

      refute candidate.id in ids
    end

    test "candidate hard-red + viewer white → excluded", %{
      viewer: viewer,
      candidate: candidate,
      flag: flag
    } do
      add_flag!(candidate, flag, "red", "hard")
      add_flag!(viewer, flag, "white")

      results = SpotlightPool.build(viewer)
      ids = Enum.map(results, & &1.id)

      refute candidate.id in ids
    end

    test "soft-red does NOT exclude", %{viewer: viewer, candidate: candidate, flag: flag} do
      add_flag!(viewer, flag, "red", "soft")
      add_flag!(candidate, flag, "white")

      results = SpotlightPool.build(viewer)
      ids = Enum.map(results, & &1.id)

      assert candidate.id in ids
    end
  end

  describe "gender filter (bidirectional)" do
    test "both match each other's preferences → included" do
      viewer =
        user_fixture(%{gender: "male", preferred_partner_gender: ["female"]})
        |> activate_user()
        |> preload_locations()

      candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          display_name: "Match"
        })
        |> activate_user()

      results = SpotlightPool.build(viewer)
      ids = Enum.map(results, & &1.id)

      assert candidate.id in ids
    end

    test "viewer's gender not in candidate's preferences → excluded" do
      viewer =
        user_fixture(%{gender: "male", preferred_partner_gender: ["female"]})
        |> activate_user()
        |> preload_locations()

      _candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["female"],
          display_name: "No Match"
        })
        |> activate_user()

      results = SpotlightPool.build(viewer)

      # Candidate only wants females, viewer is male → excluded
      refute Enum.any?(results, fn u -> u.display_name == "No Match" end)
    end

    test "candidate's gender not in viewer's preferences → excluded" do
      viewer =
        user_fixture(%{gender: "male", preferred_partner_gender: ["female"]})
        |> activate_user()
        |> preload_locations()

      _candidate =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["male"],
          display_name: "Same Gender"
        })
        |> activate_user()

      results = SpotlightPool.build(viewer)

      # Viewer only wants females, candidate is male → excluded
      refute Enum.any?(results, fn u -> u.display_name == "Same Gender" end)
    end

    test "empty preferences → no filtering on that side" do
      viewer =
        user_fixture(%{gender: "male", preferred_partner_gender: []})
        |> activate_user()
        |> preload_locations()

      candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: [],
          display_name: "Open"
        })
        |> activate_user()

      results = SpotlightPool.build(viewer)
      ids = Enum.map(results, & &1.id)

      assert candidate.id in ids
    end
  end

  describe "age filter (bidirectional)" do
    test "both in range → included" do
      # Viewer is ~36 years old (born 1990), default offsets: min -6, max +2
      # → accepts ages 30-38
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          birthday: ~D[1990-01-01]
        })
        |> activate_user()
        |> preload_locations()

      # Candidate is ~33 years old → within viewer's range
      # Candidate's range: 33-6=27 to 33+2=35 → viewer at 36... borderline
      # Use wider offsets for candidate to ensure mutual match
      _candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          birthday: ~D[1993-01-01],
          partner_minimum_age_offset: 6,
          partner_maximum_age_offset: 5,
          display_name: "Age Match"
        })
        |> activate_user()

      results = SpotlightPool.build(viewer)

      assert Enum.any?(results, fn u -> u.display_name == "Age Match" end)
    end

    test "candidate outside viewer's age range → excluded" do
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          birthday: ~D[1990-01-01],
          partner_minimum_age_offset: 2,
          partner_maximum_age_offset: 2
        })
        |> activate_user()
        |> preload_locations()

      # Candidate is ~20 years old → outside viewer's narrow range (34-38)
      _candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          birthday: ~D[2006-01-01],
          partner_minimum_age_offset: 20,
          partner_maximum_age_offset: 20,
          display_name: "Too Young"
        })
        |> activate_user()

      results = SpotlightPool.build(viewer)

      refute Enum.any?(results, fn u -> u.display_name == "Too Young" end)
    end

    test "viewer outside candidate's age range → excluded" do
      # Viewer is ~36 years old
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          birthday: ~D[1990-01-01],
          partner_minimum_age_offset: 20,
          partner_maximum_age_offset: 20
        })
        |> activate_user()
        |> preload_locations()

      # Candidate is ~33, only accepts ages 32-34 (very narrow)
      _candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          birthday: ~D[1993-01-01],
          partner_minimum_age_offset: 1,
          partner_maximum_age_offset: 1,
          display_name: "Narrow Range"
        })
        |> activate_user()

      results = SpotlightPool.build(viewer)

      refute Enum.any?(results, fn u -> u.display_name == "Narrow Range" end)
    end
  end

  describe "height filter (bidirectional)" do
    test "both in range → included" do
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          height: 180,
          partner_height_min: 150,
          partner_height_max: 190
        })
        |> activate_user()
        |> preload_locations()

      candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          height: 165,
          partner_height_min: 170,
          partner_height_max: 200,
          display_name: "Height Match"
        })
        |> activate_user()

      results = SpotlightPool.build(viewer)
      ids = Enum.map(results, & &1.id)

      assert candidate.id in ids
    end

    test "candidate outside viewer's height range → excluded" do
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          height: 180,
          partner_height_min: 170,
          partner_height_max: 185
        })
        |> activate_user()
        |> preload_locations()

      _candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          height: 155,
          partner_height_min: 160,
          partner_height_max: 200,
          display_name: "Too Short"
        })
        |> activate_user()

      results = SpotlightPool.build(viewer)

      refute Enum.any?(results, fn u -> u.display_name == "Too Short" end)
    end

    test "viewer outside candidate's height range → excluded" do
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          height: 180,
          partner_height_min: 150,
          partner_height_max: 200
        })
        |> activate_user()
        |> preload_locations()

      _candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          height: 165,
          partner_height_min: 185,
          partner_height_max: 200,
          display_name: "Wants Taller"
        })
        |> activate_user()

      results = SpotlightPool.build(viewer)

      refute Enum.any?(results, fn u -> u.display_name == "Wants Taller" end)
    end
  end

  describe "distance filter (bidirectional)" do
    test "within both radii → included" do
      # Both users in Berlin (same zip code area), within default 60km radius
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          search_radius: 100
        })
        |> activate_user()
        |> preload_locations()

      candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          search_radius: 100,
          display_name: "Near"
        })
        |> activate_user()

      results = SpotlightPool.build(viewer)
      ids = Enum.map(results, & &1.id)

      assert candidate.id in ids
    end

    test "outside viewer's radius → excluded" do
      # Viewer has very small radius
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          search_radius: 1,
          locations: [%{country_id: germany_id(), zip_code: "10115"}]
        })
        |> activate_user()
        |> preload_locations()

      # Candidate in Munich (far from Berlin)
      _candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          search_radius: 1000,
          locations: [%{country_id: germany_id(), zip_code: "80331"}],
          display_name: "Far Away"
        })
        |> activate_user()

      results = SpotlightPool.build(viewer)

      refute Enum.any?(results, fn u -> u.display_name == "Far Away" end)
    end

    test "outside candidate's radius → excluded" do
      # Viewer has large radius, candidate has tiny radius
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          search_radius: 1000,
          locations: [%{country_id: germany_id(), zip_code: "10115"}]
        })
        |> activate_user()
        |> preload_locations()

      # Candidate in Munich with tiny search radius
      _candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          search_radius: 1,
          locations: [%{country_id: germany_id(), zip_code: "80331"}],
          display_name: "Small Radius"
        })
        |> activate_user()

      results = SpotlightPool.build(viewer)

      refute Enum.any?(results, fn u -> u.display_name == "Small Radius" end)
    end
  end

  describe "full pipeline integration" do
    test "filters correctly with multiple criteria" do
      flag = create_test_flag!("Dealbreaker Trait")

      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          height: 180,
          partner_height_min: 150,
          partner_height_max: 200,
          search_radius: 100
        })
        |> activate_user()
        |> preload_locations()

      # Good match — should be included
      good_match =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          height: 165,
          partner_height_min: 170,
          partner_height_max: 195,
          search_radius: 100,
          display_name: "Good Match"
        })
        |> activate_user()

      # Wrong gender preference — should be excluded
      _wrong_gender =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["female"],
          display_name: "Wrong Gender Pref"
        })
        |> activate_user()

      # Hard red conflict — should be excluded
      hard_red_conflict =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          height: 170,
          partner_height_min: 170,
          partner_height_max: 195,
          search_radius: 100,
          display_name: "Red Conflict"
        })
        |> activate_user()

      add_flag!(viewer, flag, "red", "hard")
      add_flag!(hard_red_conflict, flag, "white")

      # Blacklisted — should be excluded
      blacklisted =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          search_radius: 100,
          display_name: "Blacklisted"
        })
        |> activate_user()

      {:ok, _} = ContactBlacklist.add_entry(viewer, %{value: blacklisted.email})

      results = SpotlightPool.build(viewer)
      ids = Enum.map(results, & &1.id)

      assert good_match.id in ids
      refute hard_red_conflict.id in ids
      refute blacklisted.id in ids
      refute Enum.any?(results, fn u -> u.display_name == "Wrong Gender Pref" end)
    end

    test "excludes self" do
      viewer =
        user_fixture(%{gender: "male", preferred_partner_gender: []})
        |> activate_user()
        |> preload_locations()

      results = SpotlightPool.build(viewer)
      ids = Enum.map(results, & &1.id)

      refute viewer.id in ids
    end

    test "excludes soft-deleted users" do
      viewer =
        user_fixture(%{gender: "male", preferred_partner_gender: ["female"]})
        |> activate_user()
        |> preload_locations()

      deleted =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          display_name: "Deleted"
        })
        |> activate_user()

      # Soft-delete the user
      deleted
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second))
      |> Repo.update!()

      results = SpotlightPool.build(viewer)

      refute Enum.any?(results, fn u -> u.display_name == "Deleted" end)
    end

    test "excludes non-normal state users" do
      viewer =
        user_fixture(%{gender: "male", preferred_partner_gender: ["female"]})
        |> activate_user()
        |> preload_locations()

      # This user stays in "waitlisted" state (default from fixture)
      _waitlisted =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          display_name: "Waitlisted"
        })

      results = SpotlightPool.build(viewer)

      refute Enum.any?(results, fn u -> u.display_name == "Waitlisted" end)
    end
  end

  describe "build_with_funnel/1" do
    test "returns correct structure {steps, candidates}" do
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          search_radius: 100
        })
        |> activate_user()
        |> preload_locations()

      _candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          search_radius: 100,
          display_name: "Funnel Candidate"
        })
        |> activate_user()

      {steps, candidates} = SpotlightPool.build_with_funnel(viewer)

      assert is_list(steps)
      assert is_list(candidates)
      assert length(steps) == 9

      # Each step has the expected keys
      for step <- steps do
        assert Map.has_key?(step, :name)
        assert Map.has_key?(step, :count)
        assert Map.has_key?(step, :drop)
        assert Map.has_key?(step, :drop_pct)
        assert is_integer(step.count)
        assert is_integer(step.drop)
        assert is_float(step.drop_pct) or step.drop_pct == 0.0
      end
    end

    test "step counts are monotonically non-increasing" do
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          search_radius: 100
        })
        |> activate_user()
        |> preload_locations()

      _candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          search_radius: 100,
          display_name: "Funnel Mono"
        })
        |> activate_user()

      {steps, _candidates} = SpotlightPool.build_with_funnel(viewer)

      counts = Enum.map(steps, & &1.count)

      # Each count should be <= the previous count
      counts
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [prev, curr] ->
        assert prev >= curr,
               "Step counts should be non-increasing, got #{prev} then #{curr}"
      end)
    end

    test "final step count matches length of candidates" do
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          search_radius: 100
        })
        |> activate_user()
        |> preload_locations()

      _candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          search_radius: 100,
          display_name: "Funnel Final"
        })
        |> activate_user()

      {steps, candidates} = SpotlightPool.build_with_funnel(viewer)

      last_step = List.last(steps)
      assert last_step.count == length(candidates)
    end
  end

  describe "build_with_pool_count/1" do
    test "returns pool count and final candidates" do
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          search_radius: 100
        })
        |> activate_user()
        |> preload_locations()

      candidate =
        user_fixture(%{
          gender: "female",
          preferred_partner_gender: ["male"],
          search_radius: 100,
          display_name: "Pool Candidate"
        })
        |> activate_user()

      {pool_count, results} = SpotlightPool.build_with_pool_count(viewer)

      # Pool count includes everyone through distance (before gender/age/height/red filters)
      assert is_integer(pool_count)
      assert pool_count >= 1

      # Results are the final filtered list
      assert is_list(results)
      assert candidate.id in Enum.map(results, & &1.id)
    end

    test "pool count >= final candidate count" do
      viewer =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["female"],
          search_radius: 100
        })
        |> activate_user()
        |> preload_locations()

      # Create a candidate that passes distance but fails gender filter
      _wrong_gender =
        user_fixture(%{
          gender: "male",
          preferred_partner_gender: ["male"],
          search_radius: 100,
          display_name: "Same Gender"
        })
        |> activate_user()

      {pool_count, results} = SpotlightPool.build_with_pool_count(viewer)

      # Pool count should be >= final results since pool is before gender/age/height filters
      assert pool_count >= length(results)
    end
  end
end
