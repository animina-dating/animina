defmodule Animina.RelationshipsTest do
  use Animina.DataCase, async: true

  alias Animina.AccountsFixtures
  alias Animina.Relationships

  # --- Helpers ---

  defp create_pair do
    user1 = AccountsFixtures.user_fixture()
    user2 = AccountsFixtures.user_fixture()
    {user1, user2}
  end

  defp create_relationship(user1, user2, status \\ "chatting") do
    {:ok, rel} = Relationships.create_relationship(user1.id, user2.id, status)
    rel
  end

  # --- Canonical Ordering ---

  describe "canonical_pair/2" do
    test "returns smaller UUID first" do
      {a, b} = Relationships.canonical_pair("aaa", "bbb")
      assert a == "aaa"
      assert b == "bbb"
    end

    test "swaps when first UUID is larger" do
      {a, b} = Relationships.canonical_pair("bbb", "aaa")
      assert a == "aaa"
      assert b == "bbb"
    end
  end

  # --- Create Relationship ---

  describe "create_relationship/3" do
    test "creates a relationship with canonical ordering" do
      {user1, user2} = create_pair()
      {:ok, rel} = Relationships.create_relationship(user1.id, user2.id)

      assert rel.status == "chatting"
      assert rel.status_changed_at != nil
      {expected_a, expected_b} = Relationships.canonical_pair(user1.id, user2.id)
      assert rel.user_a_id == expected_a
      assert rel.user_b_id == expected_b
    end

    test "returns existing relationship if one exists" do
      {user1, user2} = create_pair()
      {:ok, rel1} = Relationships.create_relationship(user1.id, user2.id)
      {:ok, rel2} = Relationships.create_relationship(user2.id, user1.id)

      assert rel1.id == rel2.id
    end

    test "creates an initial event" do
      {user1, user2} = create_pair()
      {:ok, rel} = Relationships.create_relationship(user1.id, user2.id)

      events = Relationships.list_events(rel.id)
      assert length(events) == 1
      event = hd(events)
      assert event.event_type == "created"
      assert event.to_status == "chatting"
      assert event.from_status == nil
    end

    test "creates with custom initial status" do
      {user1, user2} = create_pair()
      {:ok, rel} = Relationships.create_relationship(user1.id, user2.id, "friend")

      assert rel.status == "friend"
    end

    test "rejects self-relationship" do
      user = AccountsFixtures.user_fixture()

      assert {:error, :cannot_relate_to_self} =
               Relationships.create_relationship(user.id, user.id)
    end
  end

  # --- Get Relationship ---

  describe "get_relationship/2" do
    test "finds relationship regardless of argument order" do
      {user1, user2} = create_pair()
      {:ok, rel} = Relationships.create_relationship(user1.id, user2.id)

      assert Relationships.get_relationship(user1.id, user2.id).id == rel.id
      assert Relationships.get_relationship(user2.id, user1.id).id == rel.id
    end

    test "returns nil when no relationship exists" do
      {user1, user2} = create_pair()
      assert Relationships.get_relationship(user1.id, user2.id) == nil
    end
  end

  describe "relationship_status/2" do
    test "returns the status string" do
      {user1, user2} = create_pair()
      create_relationship(user1, user2)

      assert Relationships.relationship_status(user1.id, user2.id) == "chatting"
    end

    test "returns nil when no relationship exists" do
      {user1, user2} = create_pair()
      assert Relationships.relationship_status(user1.id, user2.id) == nil
    end
  end

  # --- List Relationships ---

  describe "list_relationships/2" do
    test "lists all relationships for a user" do
      {user1, user2} = create_pair()
      user3 = AccountsFixtures.user_fixture()

      create_relationship(user1, user2)
      create_relationship(user1, user3)

      rels = Relationships.list_relationships(user1.id)
      assert length(rels) == 2
    end

    test "filters by status" do
      {user1, user2} = create_pair()
      user3 = AccountsFixtures.user_fixture()

      create_relationship(user1, user2, "chatting")
      create_relationship(user1, user3, "friend")

      rels = Relationships.list_relationships(user1.id, status: "chatting")
      assert length(rels) == 1
      assert hd(rels).status == "chatting"
    end

    test "filters by multiple statuses" do
      {user1, user2} = create_pair()
      user3 = AccountsFixtures.user_fixture()
      user4 = AccountsFixtures.user_fixture()

      create_relationship(user1, user2, "chatting")
      create_relationship(user1, user3, "friend")
      rel = create_relationship(user1, user4, "chatting")
      {:ok, _} = Relationships.transition_status(rel, "ended", user1.id)

      rels = Relationships.list_relationships(user1.id, status: ["chatting", "friend"])
      assert length(rels) == 2
    end
  end

  # --- Downgrade Transitions (Unilateral) ---

  describe "transition_status/3" do
    test "allows valid downgrade transitions" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")

      assert {:ok, updated} = Relationships.transition_status(rel, "ended", user1.id)
      assert updated.status == "ended"
      assert updated.status_changed_by == user1.id
      assert updated.status_changed_at != nil
    end

    test "chatting can transition to ended, blocked, or ex" do
      for target <- ~w(ended blocked ex) do
        {user1, user2} = create_pair()
        rel = create_relationship(user1, user2, "chatting")
        assert {:ok, updated} = Relationships.transition_status(rel, target, user1.id)
        assert updated.status == target
      end
    end

    test "couple can transition to separated or blocked" do
      for target <- ~w(separated blocked) do
        {user1, user2} = create_pair()
        rel = create_relationship(user1, user2, "couple")
        assert {:ok, updated} = Relationships.transition_status(rel, target, user1.id)
        assert updated.status == target
      end
    end

    test "married can transition to separated or blocked" do
      for target <- ~w(separated blocked) do
        {user1, user2} = create_pair()
        rel = create_relationship(user1, user2, "married")
        assert {:ok, updated} = Relationships.transition_status(rel, target, user1.id)
        assert updated.status == target
      end
    end

    test "separated can transition to divorced, ex, ended, or blocked" do
      for target <- ~w(divorced ex ended blocked) do
        {user1, user2} = create_pair()
        rel = create_relationship(user1, user2, "separated")
        assert {:ok, updated} = Relationships.transition_status(rel, target, user1.id)
        assert updated.status == target
      end
    end

    test "blocked can transition to ended" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "blocked")
      assert {:ok, updated} = Relationships.transition_status(rel, "ended", user1.id)
      assert updated.status == "ended"
    end

    test "rejects invalid transitions" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")

      assert {:error, :invalid_transition} =
               Relationships.transition_status(rel, "married", user1.id)
    end

    test "rejects upgrade attempts via transition_status" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")

      assert {:error, :invalid_transition} =
               Relationships.transition_status(rel, "dating", user1.id)
    end

    test "logs a transition event" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, _} = Relationships.transition_status(rel, "ended", user1.id)

      events = Relationships.list_events(rel.id)
      transition = Enum.find(events, &(&1.event_type == "transition"))
      assert transition.from_status == "chatting"
      assert transition.to_status == "ended"
      assert transition.actor_id == user1.id
    end

    test "rejects transition by non-participant" do
      {user1, user2} = create_pair()
      outsider = AccountsFixtures.user_fixture()
      rel = create_relationship(user1, user2, "chatting")

      assert {:error, :not_participant} =
               Relationships.transition_status(rel, "ended", outsider.id)
    end

    test "clears pending proposal on transition" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)
      assert rel.pending_status == "dating"

      {:ok, updated} = Relationships.transition_status(rel, "ended", user2.id)
      assert updated.pending_status == nil
      assert updated.pending_proposed_by == nil
    end
  end

  # --- Proposal System (Upgrades) ---

  describe "propose_upgrade/3" do
    test "creates a pending proposal" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")

      assert {:ok, updated} = Relationships.propose_upgrade(rel, "dating", user1.id)
      assert updated.pending_status == "dating"
      assert updated.pending_proposed_by == user1.id
      assert updated.pending_proposed_at != nil
    end

    test "rejects invalid upgrade" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")

      assert {:error, :invalid_transition} =
               Relationships.propose_upgrade(rel, "married", user1.id)
    end

    test "rejects proposal by non-participant" do
      {user1, user2} = create_pair()
      outsider = AccountsFixtures.user_fixture()
      rel = create_relationship(user1, user2, "chatting")

      assert {:error, :not_participant} =
               Relationships.propose_upgrade(rel, "dating", outsider.id)
    end

    test "rejects proposal when one is already pending" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)

      assert {:error, :proposal_already_pending} =
               Relationships.propose_upgrade(rel, "dating", user2.id)
    end

    test "logs a proposal event" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, _} = Relationships.propose_upgrade(rel, "dating", user1.id)

      events = Relationships.list_events(rel.id)
      proposal = Enum.find(events, &(&1.event_type == "proposal"))
      assert proposal.from_status == "chatting"
      assert proposal.to_status == "dating"
    end

    test "valid upgrade paths" do
      transitions = [
        {"chatting", "dating"},
        {"dating", "couple"},
        {"couple", "married"},
        {"ex", "friend"},
        {"ended", "friend"},
        {"separated", "friend"},
        {"divorced", "friend"}
      ]

      for {from, to} <- transitions do
        {user1, user2} = create_pair()
        rel = create_relationship(user1, user2, from)
        assert {:ok, updated} = Relationships.propose_upgrade(rel, to, user1.id)
        assert updated.pending_status == to
      end
    end
  end

  describe "accept_proposal/2" do
    test "accepts a pending proposal and changes status" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)

      assert {:ok, updated} = Relationships.accept_proposal(rel, user2.id)
      assert updated.status == "dating"
      assert updated.pending_status == nil
      assert updated.pending_proposed_by == nil
    end

    test "rejects accept by non-participant" do
      {user1, user2} = create_pair()
      outsider = AccountsFixtures.user_fixture()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)

      assert {:error, :not_participant} =
               Relationships.accept_proposal(rel, outsider.id)
    end

    test "rejects accept from the proposer" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)

      assert {:error, :cannot_accept_own_proposal} =
               Relationships.accept_proposal(rel, user1.id)
    end

    test "rejects accept when no proposal is pending" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")

      assert {:error, :no_pending_proposal} =
               Relationships.accept_proposal(rel, user2.id)
    end

    test "logs a proposal_accepted event" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)
      {:ok, _} = Relationships.accept_proposal(rel, user2.id)

      events = Relationships.list_events(rel.id)
      accepted = Enum.find(events, &(&1.event_type == "proposal_accepted"))
      assert accepted.from_status == "chatting"
      assert accepted.to_status == "dating"
      assert accepted.actor_id == user2.id
    end
  end

  describe "decline_proposal/2" do
    test "declines a pending proposal, keeps current status" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)

      assert {:ok, updated} = Relationships.decline_proposal(rel, user2.id)
      assert updated.status == "chatting"
      assert updated.pending_status == nil
    end

    test "rejects decline by non-participant" do
      {user1, user2} = create_pair()
      outsider = AccountsFixtures.user_fixture()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)

      assert {:error, :not_participant} =
               Relationships.decline_proposal(rel, outsider.id)
    end

    test "rejects decline from the proposer" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)

      assert {:error, :cannot_decline_own_proposal} =
               Relationships.decline_proposal(rel, user1.id)
    end

    test "rejects decline when no proposal is pending" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")

      assert {:error, :no_pending_proposal} =
               Relationships.decline_proposal(rel, user2.id)
    end

    test "logs a proposal_declined event" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)
      {:ok, _} = Relationships.decline_proposal(rel, user2.id)

      events = Relationships.list_events(rel.id)
      declined = Enum.find(events, &(&1.event_type == "proposal_declined"))
      assert declined != nil
      assert declined.actor_id == user2.id
    end
  end

  describe "cancel_proposal/2" do
    test "proposer can cancel their own proposal" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)

      assert {:ok, updated} = Relationships.cancel_proposal(rel, user1.id)
      assert updated.status == "chatting"
      assert updated.pending_status == nil
      assert updated.pending_proposed_by == nil
    end

    test "non-proposer cannot cancel the proposal" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)

      assert {:error, :cannot_cancel_others_proposal} =
               Relationships.cancel_proposal(rel, user2.id)
    end

    test "cannot cancel when no pending proposal" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")

      assert {:error, :no_pending_proposal} =
               Relationships.cancel_proposal(rel, user1.id)
    end

    test "logs a proposal_cancelled event" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)
      {:ok, _} = Relationships.cancel_proposal(rel, user1.id)

      events = Relationships.list_events(rel.id)
      cancelled = Enum.find(events, &(&1.event_type == "proposal_cancelled"))
      assert cancelled != nil
      assert cancelled.actor_id == user1.id
    end
  end

  describe "get_relationships_for_user/2" do
    test "returns relationships for user with given other user ids" do
      {user1, user2} = create_pair()
      user3 = AccountsFixtures.user_fixture()
      _rel1 = create_relationship(user1, user2)
      _rel2 = create_relationship(user1, user3)

      results = Relationships.get_relationships_for_user(user1.id, [user2.id, user3.id])
      assert length(results) == 2
    end

    test "returns empty list for empty other_user_ids" do
      {user1, _user2} = create_pair()
      assert Relationships.get_relationships_for_user(user1.id, []) == []
    end

    test "does not return unrelated relationships" do
      {user1, user2} = create_pair()
      {user3, user4} = create_pair()
      _rel1 = create_relationship(user1, user2)
      _rel2 = create_relationship(user3, user4)

      results = Relationships.get_relationships_for_user(user1.id, [user3.id])
      assert results == []
    end
  end

  # --- Reopen Relationship ---

  describe "reopen_relationship/2" do
    test "reopens an ended relationship back to chatting" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.transition_status(rel, "ended", user1.id)

      assert {:ok, updated} = Relationships.reopen_relationship(rel, user1.id)
      assert updated.status == "chatting"
    end

    test "reopens a blocked relationship back to chatting" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "blocked")

      assert {:ok, updated} = Relationships.reopen_relationship(rel, user1.id)
      assert updated.status == "chatting"
    end

    test "rejects reopen from non-ended/blocked status" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")

      assert {:error, :cannot_reopen} = Relationships.reopen_relationship(rel, user1.id)
    end

    test "rejects reopen by non-participant" do
      {user1, user2} = create_pair()
      outsider = AccountsFixtures.user_fixture()
      rel = create_relationship(user1, user2, "ended")

      assert {:error, :not_participant} =
               Relationships.reopen_relationship(rel, outsider.id)
    end

    test "logs a transition event with reopen metadata" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "ended")
      {:ok, _} = Relationships.reopen_relationship(rel, user1.id)

      events = Relationships.list_events(rel.id)
      reopen = Enum.find(events, &(&1.event_type == "transition" && &1.to_status == "chatting"))
      assert reopen != nil
      assert reopen.metadata["reason"] == "reopened"
    end
  end

  # --- Full Proposal Lifecycle ---

  describe "full proposal lifecycle" do
    test "chatting -> dating -> couple -> married via proposals" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")

      # Propose dating
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)
      {:ok, rel} = Relationships.accept_proposal(rel, user2.id)
      assert rel.status == "dating"

      # Propose couple
      {:ok, rel} = Relationships.propose_upgrade(rel, "couple", user2.id)
      {:ok, rel} = Relationships.accept_proposal(rel, user1.id)
      assert rel.status == "couple"

      # Propose married
      {:ok, rel} = Relationships.propose_upgrade(rel, "married", user1.id)
      {:ok, rel} = Relationships.accept_proposal(rel, user2.id)
      assert rel.status == "married"

      # Full event history
      events = Relationships.list_events(rel.id)
      # created + 3x(proposal + accepted)
      assert length(events) == 7
    end

    test "married -> separated -> divorced -> friend via mixed transitions" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "married")

      # Unilateral separation
      {:ok, rel} = Relationships.transition_status(rel, "separated", user1.id)
      assert rel.status == "separated"

      # Unilateral divorce
      {:ok, rel} = Relationships.transition_status(rel, "divorced", user1.id)
      assert rel.status == "divorced"

      # Propose friendship (requires agreement)
      {:ok, rel} = Relationships.propose_upgrade(rel, "friend", user1.id)
      {:ok, rel} = Relationships.accept_proposal(rel, user2.id)
      assert rel.status == "friend"
    end
  end

  # --- Permission Resolution ---

  describe "effective_permissions/2" do
    test "returns defaults for chatting status" do
      {user1, user2} = create_pair()
      create_relationship(user1, user2, "chatting")

      perms = Relationships.effective_permissions(user1.id, user2.id)
      assert perms.can_see_profile == true
      assert perms.can_message == true
      assert perms.visible_in_discovery == true
    end

    test "returns defaults for blocked status" do
      {user1, user2} = create_pair()
      create_relationship(user1, user2, "blocked")

      perms = Relationships.effective_permissions(user1.id, user2.id)
      assert perms.can_see_profile == false
      assert perms.can_message == false
      assert perms.visible_in_discovery == false
    end

    test "returns defaults for dating status" do
      {user1, user2} = create_pair()
      create_relationship(user1, user2, "dating")

      perms = Relationships.effective_permissions(user1.id, user2.id)
      assert perms.can_see_profile == true
      assert perms.can_message == true
      assert perms.visible_in_discovery == false
    end

    test "returns all-true when no relationship exists" do
      {user1, user2} = create_pair()

      perms = Relationships.effective_permissions(user1.id, user2.id)
      assert perms.can_see_profile == true
      assert perms.can_message == true
      assert perms.visible_in_discovery == true
    end
  end

  describe "can_see_profile?/2" do
    test "returns true for chatting" do
      {user1, user2} = create_pair()
      create_relationship(user1, user2, "chatting")
      assert Relationships.can_see_profile?(user1.id, user2.id) == true
    end

    test "returns false for blocked" do
      {user1, user2} = create_pair()
      create_relationship(user1, user2, "blocked")
      assert Relationships.can_see_profile?(user1.id, user2.id) == false
    end
  end

  describe "can_message?/2" do
    test "returns true for chatting" do
      {user1, user2} = create_pair()
      create_relationship(user1, user2, "chatting")
      assert Relationships.can_message?(user1.id, user2.id) == true
    end

    test "returns false for separated" do
      {user1, user2} = create_pair()
      create_relationship(user1, user2, "separated")
      assert Relationships.can_message?(user1.id, user2.id) == false
    end
  end

  describe "visible_in_discovery?/2" do
    test "returns true for chatting" do
      {user1, user2} = create_pair()
      create_relationship(user1, user2, "chatting")
      assert Relationships.visible_in_discovery?(user1.id, user2.id) == true
    end

    test "returns false for couple" do
      {user1, user2} = create_pair()
      create_relationship(user1, user2, "couple")
      assert Relationships.visible_in_discovery?(user1.id, user2.id) == false
    end
  end

  # --- Overrides ---

  describe "set_override/3" do
    test "creates a new override" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "blocked")

      assert {:ok, override} =
               Relationships.set_override(user1.id, rel.id, %{can_see_profile: true})

      assert override.can_see_profile == true
      assert override.can_message_me == nil
    end

    test "updates an existing override" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "blocked")

      {:ok, _} = Relationships.set_override(user1.id, rel.id, %{can_see_profile: true})

      {:ok, updated} =
        Relationships.set_override(user1.id, rel.id, %{can_see_profile: false})

      assert updated.can_see_profile == false
    end

    test "override affects permission resolution" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "blocked")

      # Default for blocked: can_see_profile = false
      assert Relationships.can_see_profile?(user1.id, user2.id) == false

      # user2 overrides to allow user1 to see profile
      {:ok, _} = Relationships.set_override(user2.id, rel.id, %{can_see_profile: true})

      assert Relationships.can_see_profile?(user1.id, user2.id) == true
    end
  end

  describe "clear_override/2" do
    test "removes an override" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "blocked")

      {:ok, _} = Relationships.set_override(user1.id, rel.id, %{can_see_profile: true})
      {:ok, _} = Relationships.clear_override(user1.id, rel.id)

      assert Relationships.get_override(user1.id, rel.id) == nil
    end

    test "succeeds when no override exists" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2)

      assert {:ok, nil} = Relationships.clear_override(user1.id, rel.id)
    end
  end

  # --- Discovery Integration ---

  describe "hidden_from_discovery_ids/1" do
    test "returns IDs hidden by status defaults" do
      {user1, user2} = create_pair()
      user3 = AccountsFixtures.user_fixture()

      # couple => visible_in_discovery: false
      create_relationship(user1, user2, "couple")
      # chatting => visible_in_discovery: true
      create_relationship(user1, user3, "chatting")

      hidden = Relationships.hidden_from_discovery_ids(user1.id)
      assert user2.id in hidden
      refute user3.id in hidden
    end

    test "override can make a hidden user visible" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "couple")

      # Default: hidden
      hidden = Relationships.hidden_from_discovery_ids(user1.id)
      assert user2.id in hidden

      # User1 overrides to make visible in their discovery
      {:ok, _} = Relationships.set_override(user1.id, rel.id, %{visible_in_discovery: true})

      hidden = Relationships.hidden_from_discovery_ids(user1.id)
      refute user2.id in hidden
    end

    test "returns empty list when no relationships" do
      user = AccountsFixtures.user_fixture()
      assert Relationships.hidden_from_discovery_ids(user.id) == []
    end
  end

  # --- Milestones ---

  describe "list_milestones/1" do
    test "returns only status-change events (created + proposal_accepted)" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")

      # Propose dating (creates proposal event)
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)
      # Accept proposal (creates proposal_accepted event)
      {:ok, _rel} = Relationships.accept_proposal(rel, user2.id)

      milestones = Relationships.list_milestones(rel.id)
      event_types = Enum.map(milestones, & &1.event_type)

      assert "created" in event_types
      assert "proposal_accepted" in event_types
      refute "proposal" in event_types
    end

    test "includes transition (downgrade) events" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "couple")
      {:ok, _rel} = Relationships.transition_status(rel, "separated", user1.id)

      milestones = Relationships.list_milestones(rel.id)
      event_types = Enum.map(milestones, & &1.event_type)

      assert "created" in event_types
      assert "transition" in event_types
    end

    test "excludes proposal, proposal_declined, proposal_cancelled" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")

      # Propose and decline
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)
      {:ok, rel} = Relationships.decline_proposal(rel, user2.id)

      # Propose and cancel
      {:ok, rel} = Relationships.propose_upgrade(rel, "dating", user1.id)
      {:ok, _rel} = Relationships.cancel_proposal(rel, user1.id)

      milestones = Relationships.list_milestones(rel.id)
      event_types = Enum.map(milestones, & &1.event_type)

      refute "proposal" in event_types
      refute "proposal_declined" in event_types
      refute "proposal_cancelled" in event_types
      # Only the created event should remain
      assert event_types == ["created"]
    end

    test "returns empty list for nonexistent relationship" do
      fake_id = Ecto.UUID.generate()
      assert Relationships.list_milestones(fake_id) == []
    end
  end

  # --- Event History ---

  describe "list_events/1" do
    test "returns events in chronological order" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2, "chatting")
      {:ok, rel} = Relationships.transition_status(rel, "ended", user1.id)

      events = Relationships.list_events(rel.id)
      assert length(events) == 2
      assert Enum.at(events, 0).event_type == "created"
      assert Enum.at(events, 1).event_type == "transition"
    end
  end

  # --- Other User ID ---

  describe "other_user_id/2" do
    test "returns the other user's ID" do
      {user1, user2} = create_pair()
      rel = create_relationship(user1, user2)

      {expected_a, expected_b} = Relationships.canonical_pair(user1.id, user2.id)

      assert Relationships.other_user_id(rel, expected_a) == expected_b
      assert Relationships.other_user_id(rel, expected_b) == expected_a
    end
  end
end
