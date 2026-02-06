defmodule Animina.Discovery.CandidateFilterTest do
  use Animina.DataCase

  alias Animina.Discovery.CandidateFilter
  alias Animina.Traits

  import Animina.AccountsFixtures
  import Animina.TraitsFixtures

  describe "filter_by_hard_green/2" do
    setup do
      category = category_fixture(%{name: "Green Filter Sports", position: 1, core: true})
      flag1 = flag_fixture(%{name: "Guitar", emoji: "🎸", category_id: category.id})
      flag2 = flag_fixture(%{name: "Piano", emoji: "🎹", category_id: category.id})

      %{category: category, flag1: flag1, flag2: flag2}
    end

    test "candidate WITH viewer's required trait is included", %{flag1: flag1} do
      viewer = user_fixture()
      candidate = user_fixture()

      # Viewer marks Guitar as green-hard (required)
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: viewer.id,
          flag_id: flag1.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      # Candidate has Guitar as white
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: candidate.id,
          flag_id: flag1.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      result = CandidateFilter.filter_by_hard_green([candidate], viewer)

      assert length(result) == 1
      assert hd(result).id == candidate.id
    end

    test "candidate WITHOUT viewer's required trait is excluded", %{flag1: flag1} do
      viewer = user_fixture()
      candidate = user_fixture()

      # Viewer marks Guitar as green-hard (required)
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: viewer.id,
          flag_id: flag1.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      # Candidate has NO flags at all

      result = CandidateFilter.filter_by_hard_green([candidate], viewer)

      assert result == []
    end

    test "multiple green-hard flags require ALL to match (AND logic)", %{
      flag1: flag1,
      flag2: flag2
    } do
      viewer = user_fixture()
      candidate_both = user_fixture()
      candidate_one = user_fixture()

      # Viewer requires both Guitar AND Piano
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: viewer.id,
          flag_id: flag1.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: viewer.id,
          flag_id: flag2.id,
          color: "green",
          intensity: "hard",
          position: 2
        })

      # candidate_both has both
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: candidate_both.id,
          flag_id: flag1.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: candidate_both.id,
          flag_id: flag2.id,
          color: "white",
          intensity: "hard",
          position: 2
        })

      # candidate_one has only Guitar
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: candidate_one.id,
          flag_id: flag1.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      result = CandidateFilter.filter_by_hard_green([candidate_both, candidate_one], viewer)

      assert length(result) == 1
      assert hd(result).id == candidate_both.id
    end

    test "parent flag as green-hard is satisfied by child match" do
      category = category_fixture(%{name: "Green Filter Music", position: 2, core: true})

      {parent, children} =
        flag_with_children_fixture(%{
          name: "Music",
          emoji: "🎵",
          category_id: category.id
        })

      viewer = user_fixture()
      candidate = user_fixture()

      # Viewer marks parent "Music" as green-hard
      # expand_on_write will create inherited children as green-hard
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: viewer.id,
          flag_id: parent.id,
          color: "green",
          intensity: "hard",
          position: 1
        })

      # Candidate has one of the children as white
      child = hd(children)

      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: candidate.id,
          flag_id: child.id,
          color: "white",
          intensity: "hard",
          position: 1
        })

      result = CandidateFilter.filter_by_hard_green([candidate], viewer)

      # Should pass: child match satisfies parent requirement
      assert length(result) == 1
      assert hd(result).id == candidate.id
    end

    test "no green-hard flags means all candidates pass", %{flag1: flag1} do
      viewer = user_fixture()
      candidate = user_fixture()

      # Viewer has green-SOFT flag only (not hard)
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: viewer.id,
          flag_id: flag1.id,
          color: "green",
          intensity: "soft",
          position: 1
        })

      result = CandidateFilter.filter_by_hard_green([candidate], viewer)

      assert length(result) == 1
      assert hd(result).id == candidate.id
    end

    test "green-soft flags do not filter candidates", %{flag1: flag1} do
      viewer = user_fixture()
      candidate = user_fixture()

      # Viewer has green-soft (not a filter, just scoring)
      {:ok, _} =
        Traits.add_user_flag(%{
          user_id: viewer.id,
          flag_id: flag1.id,
          color: "green",
          intensity: "soft",
          position: 1
        })

      # Candidate does NOT have this flag
      result = CandidateFilter.filter_by_hard_green([candidate], viewer)

      # Should still pass since it's soft, not hard
      assert length(result) == 1
    end
  end
end
