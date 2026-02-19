defmodule Animina.Relationships do
  @moduledoc """
  Context for managing relationships between users.

  A relationship tracks the shared status between two users (chatting, dating,
  couple, married, etc.) and controls permissions for profile visibility,
  messaging, and discovery. Upgrades require mutual agreement (propose/accept);
  downgrades are unilateral.

  ## Canonical ordering

  `user_a_id` is always the lexicographically smaller UUID. This ensures
  exactly one row per pair. Use `canonical_pair/2` to get the correct ordering.
  """

  import Ecto.Query

  alias Animina.ActivityLog
  alias Animina.Repo
  alias Animina.TimeMachine

  alias Animina.Relationships.Schemas.{
    Relationship,
    RelationshipEvent,
    RelationshipOverride
  }

  # --- Status Defaults ---

  @status_defaults %{
    "chatting" => %{can_see_profile: true, can_message: true, visible_in_discovery: true},
    "dating" => %{can_see_profile: true, can_message: true, visible_in_discovery: false},
    "couple" => %{can_see_profile: true, can_message: true, visible_in_discovery: false},
    "married" => %{can_see_profile: true, can_message: true, visible_in_discovery: false},
    "separated" => %{can_see_profile: true, can_message: false, visible_in_discovery: false},
    "divorced" => %{can_see_profile: false, can_message: false, visible_in_discovery: true},
    "ex" => %{can_see_profile: false, can_message: false, visible_in_discovery: false},
    "friend" => %{can_see_profile: true, can_message: true, visible_in_discovery: false},
    "blocked" => %{can_see_profile: false, can_message: false, visible_in_discovery: false},
    "ended" => %{can_see_profile: false, can_message: false, visible_in_discovery: false}
  }

  # Upgrades require proposal/accept
  @upgrade_transitions %{
    "chatting" => ["dating"],
    "dating" => ["couple"],
    "couple" => ["married"],
    "ex" => ["friend"],
    "ended" => ["friend"],
    "separated" => ["friend"],
    "divorced" => ["friend"]
  }

  # Downgrades are unilateral
  @downgrade_transitions %{
    "chatting" => ["ex", "ended", "blocked"],
    "dating" => ["ex", "ended", "blocked"],
    "couple" => ["separated", "blocked"],
    "married" => ["separated", "blocked"],
    "separated" => ["divorced", "ex", "ended", "blocked"],
    "divorced" => ["ex", "ended", "blocked"],
    "ex" => ["ended", "blocked"],
    "friend" => ["ended", "blocked"],
    "blocked" => ["ended"],
    "ended" => ["blocked"]
  }

  # Active statuses for chat slot counting
  @active_statuses ~w(chatting dating couple married friend)

  # Statuses where visible_in_discovery defaults to false (derived from @status_defaults)
  @hidden_in_discovery_statuses @status_defaults
                                |> Enum.filter(fn {_status, defaults} ->
                                  defaults.visible_in_discovery == false
                                end)
                                |> Enum.map(fn {status, _} -> status end)

  # --- PubSub Topics ---

  @doc """
  Returns the PubSub topic for a relationship.
  """
  def relationship_topic(relationship_id), do: "relationship:#{relationship_id}"

  # --- Canonical Ordering ---

  @doc """
  Returns `{user_a_id, user_b_id}` with canonical ordering (smaller UUID first).
  """
  def canonical_pair(id1, id2) when id1 < id2, do: {id1, id2}
  def canonical_pair(id1, id2), do: {id2, id1}

  # --- Core Queries ---

  @doc """
  Gets the relationship between two users (handles canonical ordering).
  """
  def get_relationship(user1_id, user2_id) do
    {user_a_id, user_b_id} = canonical_pair(user1_id, user2_id)

    Relationship
    |> where([r], r.user_a_id == ^user_a_id and r.user_b_id == ^user_b_id)
    |> Repo.one()
  end

  @doc """
  Gets the relationship between two users or raises if not found.
  """
  def get_relationship!(user1_id, user2_id) do
    case get_relationship(user1_id, user2_id) do
      nil -> raise "No relationship found between #{user1_id} and #{user2_id}"
      relationship -> relationship
    end
  end

  @doc """
  Lists all relationships for a user.

  Options:
  - `:status` - filter by status (string or list of strings)
  """
  def list_relationships(user_id, opts \\ []) do
    query =
      Relationship
      |> where([r], r.user_a_id == ^user_id or r.user_b_id == ^user_id)
      |> order_by([r], desc: r.status_changed_at, desc: r.updated_at)

    query =
      case Keyword.get(opts, :status) do
        nil -> query
        statuses when is_list(statuses) -> where(query, [r], r.status in ^statuses)
        status when is_binary(status) -> where(query, [r], r.status == ^status)
      end

    Repo.all(query)
  end

  @doc """
  Gets relationships between a user and a list of other user IDs (batch query).

  Returns a list of `%Relationship{}` structs.
  """
  def get_relationships_for_user(user_id, other_user_ids) when is_list(other_user_ids) do
    if other_user_ids == [] do
      []
    else
      Relationship
      |> where([r],
        (r.user_a_id == ^user_id and r.user_b_id in ^other_user_ids) or
        (r.user_b_id == ^user_id and r.user_a_id in ^other_user_ids)
      )
      |> Repo.all()
    end
  end

  @doc """
  Returns the relationship status between two users, or nil if no relationship.
  """
  def relationship_status(user1_id, user2_id) do
    case get_relationship(user1_id, user2_id) do
      nil -> nil
      rel -> rel.status
    end
  end

  # --- Permission Resolution ---

  @doc """
  Returns the effective permissions for `user_id` regarding `other_user_id`.

  Merges status defaults with any per-user overrides.
  Returns `%{can_see_profile: bool, can_message: bool, visible_in_discovery: bool}`.

  When no relationship exists, returns all-true (no restrictions).
  """
  def effective_permissions(user_id, other_user_id) do
    no_relationship = %{can_see_profile: true, can_message: true, visible_in_discovery: true}

    case get_relationship(user_id, other_user_id) do
      nil ->
        no_relationship

      relationship ->
        defaults = Map.get(@status_defaults, relationship.status, no_relationship)

        # Get the override set by the OTHER user (they control what user_id can do)
        other_override = get_override(other_user_id, relationship.id)
        # Get the override set by THIS user (they control discovery visibility)
        my_override = get_override(user_id, relationship.id)

        %{
          can_see_profile:
            resolve_permission(other_override, :can_see_profile, defaults.can_see_profile),
          can_message:
            resolve_permission(other_override, :can_message_me, defaults.can_message),
          visible_in_discovery:
            resolve_permission(my_override, :visible_in_discovery, defaults.visible_in_discovery)
        }
    end
  end

  @doc """
  Returns whether `viewer_id` can see `target_id`'s profile.
  """
  def can_see_profile?(viewer_id, target_id) do
    effective_permissions(viewer_id, target_id).can_see_profile
  end

  @doc """
  Returns whether `sender_id` can message `recipient_id`.
  """
  def can_message?(sender_id, recipient_id) do
    effective_permissions(sender_id, recipient_id).can_message
  end

  @doc """
  Returns whether `candidate_id` is visible in `viewer_id`'s discovery.
  """
  def visible_in_discovery?(viewer_id, candidate_id) do
    effective_permissions(viewer_id, candidate_id).visible_in_discovery
  end

  defp resolve_permission(nil, _field, default), do: default
  defp resolve_permission(override, field, default) do
    case Map.get(override, field) do
      nil -> default
      value -> value
    end
  end

  # --- Status Transitions ---

  @doc """
  Creates a new relationship between two users with the given initial status.

  Returns `{:ok, relationship}` or `{:error, changeset}`.
  If a relationship already exists, returns it unchanged.
  """
  def create_relationship(user1_id, user2_id, initial_status \\ "chatting") do
    if user1_id == user2_id do
      {:error, :cannot_relate_to_self}
    else
      {user_a_id, user_b_id} = canonical_pair(user1_id, user2_id)

      case get_relationship(user1_id, user2_id) do
        nil ->
          Repo.transaction(fn ->
            attrs = %{
              user_a_id: user_a_id,
              user_b_id: user_b_id,
              status: initial_status,
              status_changed_at: TimeMachine.utc_now(:second),
              status_changed_by: user1_id
            }

            case %Relationship{} |> Relationship.changeset(attrs) |> Repo.insert() do
              {:ok, relationship} ->
                log_event(relationship.id, user1_id, nil, initial_status, "created")
                relationship

              {:error, %Ecto.Changeset{errors: errors} = changeset} ->
                # Handle race condition: another process created it concurrently
                if Keyword.has_key?(errors, :user_a_id) || Keyword.has_key?(errors, :user_b_id) do
                  case get_relationship(user1_id, user2_id) do
                    nil -> Repo.rollback(changeset)
                    existing -> existing
                  end
                else
                  Repo.rollback(changeset)
                end
            end
          end)

        existing ->
          {:ok, existing}
      end
    end
  end

  @doc """
  Transitions a relationship to a new status (unilateral downgrade).

  Returns `{:ok, relationship}` or `{:error, reason}`.
  """
  def transition_status(relationship, new_status, actor_id) do
    allowed = Map.get(@downgrade_transitions, relationship.status, [])

    cond do
      not participant?(relationship, actor_id) ->
        {:error, :not_participant}

      new_status not in allowed ->
        {:error, :invalid_transition}

      true ->
        old_status = relationship.status

        case relationship
             |> Relationship.transition_changeset(new_status, actor_id)
             |> Repo.update() do
          {:ok, updated} ->
            log_event(updated.id, actor_id, old_status, new_status, "transition")
            broadcast_relationship_changed(updated)
            log_activity(old_status, new_status, actor_id, updated)
            {:ok, updated}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Reopens a relationship back to "chatting" (e.g., via Love Emergency).

  This is a special transition that bypasses normal transition rules,
  only allowed from "ended" or "blocked" statuses.

  Returns `{:ok, relationship}` or `{:error, reason}`.
  """
  def reopen_relationship(relationship, actor_id) do
    cond do
      not participant?(relationship, actor_id) ->
        {:error, :not_participant}

      relationship.status not in ["ended", "blocked"] ->
        {:error, :cannot_reopen}

      true ->
        old_status = relationship.status

        case relationship
             |> Relationship.transition_changeset("chatting", actor_id)
             |> Repo.update() do
          {:ok, updated} ->
            log_event(updated.id, actor_id, old_status, "chatting", "transition",
              %{"reason" => "reopened"})
            broadcast_relationship_changed(updated)
            log_activity(old_status, "chatting", actor_id, updated)
            {:ok, updated}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Proposes an upgrade for the relationship.

  Returns `{:ok, relationship}` or `{:error, reason}`.
  """
  def propose_upgrade(relationship, proposed_status, proposer_id) do
    allowed = Map.get(@upgrade_transitions, relationship.status, [])

    cond do
      not participant?(relationship, proposer_id) ->
        {:error, :not_participant}

      proposed_status not in allowed ->
        {:error, :invalid_transition}

      relationship.pending_status != nil ->
        {:error, :proposal_already_pending}

      true ->
        case relationship
             |> Relationship.proposal_changeset(proposed_status, proposer_id)
             |> Repo.update() do
          {:ok, updated} ->
            log_event(updated.id, proposer_id, relationship.status, proposed_status, "proposal")
            broadcast_relationship_changed(updated)

            other_id = other_user_id(updated, proposer_id)

            ActivityLog.log("social", "relationship_proposed",
              "Relationship upgrade proposed: #{relationship.status} -> #{proposed_status}",
              actor_id: proposer_id,
              subject_id: other_id,
              metadata: %{
                "relationship_id" => updated.id,
                "from_status" => relationship.status,
                "proposed_status" => proposed_status
              }
            )

            {:ok, updated}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Accepts a pending proposal.

  Returns `{:ok, relationship}` or `{:error, reason}`.
  """
  def accept_proposal(relationship, accepter_id) do
    cond do
      not participant?(relationship, accepter_id) ->
        {:error, :not_participant}

      relationship.pending_status == nil ->
        {:error, :no_pending_proposal}

      relationship.pending_proposed_by == accepter_id ->
        {:error, :cannot_accept_own_proposal}

      true ->
        old_status = relationship.status
        new_status = relationship.pending_status

        case relationship
             |> Relationship.transition_changeset(new_status, accepter_id)
             |> Repo.update() do
          {:ok, updated} ->
            log_event(updated.id, accepter_id, old_status, new_status, "proposal_accepted")
            broadcast_relationship_changed(updated)

            proposer_id = relationship.pending_proposed_by

            ActivityLog.log("social", "relationship_accepted",
              "Relationship upgrade accepted: #{old_status} -> #{new_status}",
              actor_id: accepter_id,
              subject_id: proposer_id,
              metadata: %{
                "relationship_id" => updated.id,
                "from_status" => old_status,
                "to_status" => new_status
              }
            )

            {:ok, updated}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Cancels a pending proposal (by the proposer themselves).

  Returns `{:ok, relationship}` or `{:error, reason}`.
  """
  def cancel_proposal(relationship, canceller_id) do
    cond do
      not participant?(relationship, canceller_id) ->
        {:error, :not_participant}

      relationship.pending_status == nil ->
        {:error, :no_pending_proposal}

      relationship.pending_proposed_by != canceller_id ->
        {:error, :cannot_cancel_others_proposal}

      true ->
        proposed_status = relationship.pending_status

        case relationship
             |> Relationship.clear_proposal_changeset()
             |> Repo.update() do
          {:ok, updated} ->
            log_event(updated.id, canceller_id, relationship.status, proposed_status, "proposal_cancelled")
            broadcast_relationship_changed(updated)
            {:ok, updated}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Declines a pending proposal.

  Returns `{:ok, relationship}` or `{:error, reason}`.
  """
  def decline_proposal(relationship, decliner_id) do
    cond do
      not participant?(relationship, decliner_id) ->
        {:error, :not_participant}

      relationship.pending_status == nil ->
        {:error, :no_pending_proposal}

      relationship.pending_proposed_by == decliner_id ->
        {:error, :cannot_decline_own_proposal}

      true ->
        proposed_status = relationship.pending_status

        case relationship
             |> Relationship.clear_proposal_changeset()
             |> Repo.update() do
          {:ok, updated} ->
            log_event(updated.id, decliner_id, relationship.status, proposed_status, "proposal_declined")
            broadcast_relationship_changed(updated)

            proposer_id = relationship.pending_proposed_by

            ActivityLog.log("social", "relationship_declined",
              "Relationship upgrade declined: proposed #{proposed_status}",
              actor_id: decliner_id,
              subject_id: proposer_id,
              metadata: %{
                "relationship_id" => updated.id,
                "proposed_status" => proposed_status
              }
            )

            {:ok, updated}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  # --- Override Management ---

  @doc """
  Sets permission overrides for a user in a relationship.

  Attrs can include: `:can_see_profile`, `:can_message_me`, `:visible_in_discovery`.
  """
  def set_override(user_id, relationship_id, attrs) do
    case get_override(user_id, relationship_id) do
      nil ->
        %RelationshipOverride{}
        |> RelationshipOverride.changeset(
          Map.merge(attrs, %{relationship_id: relationship_id, user_id: user_id})
        )
        |> Repo.insert()

      existing ->
        existing
        |> RelationshipOverride.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Clears all overrides for a user in a relationship.
  """
  def clear_override(user_id, relationship_id) do
    case get_override(user_id, relationship_id) do
      nil -> {:ok, nil}
      override -> Repo.delete(override)
    end
  end

  @doc """
  Gets the override for a user in a relationship.
  """
  def get_override(user_id, relationship_id) do
    RelationshipOverride
    |> where([o], o.relationship_id == ^relationship_id and o.user_id == ^user_id)
    |> Repo.one()
  end

  # --- Discovery Integration ---

  @doc """
  Returns a list of user IDs that should be hidden from this user's discovery.

  A user is hidden if their relationship status default says `visible_in_discovery: false`
  and there is no override setting it to `true`.
  """
  def hidden_from_discovery_ids(user_id) do
    # Get all relationships with hidden statuses in a single query
    relationships =
      Relationship
      |> where([r], r.user_a_id == ^user_id or r.user_b_id == ^user_id)
      |> where([r], r.status in ^@hidden_in_discovery_statuses)
      |> Repo.all()

    if relationships == [] do
      []
    else
      relationship_ids = Enum.map(relationships, & &1.id)

      # Batch-load all overrides for this user in one query
      overrides_by_rel_id =
        RelationshipOverride
        |> where([o], o.user_id == ^user_id and o.relationship_id in ^relationship_ids)
        |> Repo.all()
        |> Map.new(&{&1.relationship_id, &1})

      # Determine which are hidden (no override making them visible)
      Enum.reduce(relationships, [], fn rel, acc ->
        other_id = other_user_id(rel, user_id)
        override = Map.get(overrides_by_rel_id, rel.id)

        # Default is false (hidden) since we pre-filtered to hidden statuses
        visible = resolve_permission(override, :visible_in_discovery, false)

        if visible, do: acc, else: [other_id | acc]
      end)
    end
  end

  @doc """
  Returns the list of active statuses (for chat slot counting).
  """
  def active_statuses, do: @active_statuses

  @doc """
  Returns the status defaults map.
  """
  def status_defaults, do: @status_defaults

  @doc """
  Returns the valid upgrade transitions from a given status.
  """
  def upgrade_transitions(status), do: Map.get(@upgrade_transitions, status, [])

  @doc """
  Returns the valid downgrade transitions from a given status.
  """
  def downgrade_transitions(status), do: Map.get(@downgrade_transitions, status, [])

  @doc """
  Returns the list of statuses where visible_in_discovery defaults to false.
  """
  def hidden_in_discovery_statuses, do: @hidden_in_discovery_statuses

  # --- Event History ---

  @milestone_event_types ~w(created transition proposal_accepted)

  @doc """
  Lists milestone events for a relationship (actual status changes only).

  Excludes intermediate events like proposals, declines, and cancellations.
  Returns events ordered chronologically.
  """
  def list_milestones(relationship_id) do
    RelationshipEvent
    |> where([e], e.relationship_id == ^relationship_id)
    |> where([e], e.event_type in ^@milestone_event_types)
    |> order_by([e], asc: e.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists all events for a relationship, ordered by insertion time.
  """
  def list_events(relationship_id) do
    RelationshipEvent
    |> where([e], e.relationship_id == ^relationship_id)
    |> order_by([e], asc: e.inserted_at)
    |> Repo.all()
  end

  # --- Helpers ---

  @doc """
  Returns the other user's ID in a relationship.
  """
  def other_user_id(%Relationship{user_a_id: user_a_id, user_b_id: user_b_id}, user_id) do
    if user_a_id == user_id, do: user_b_id, else: user_a_id
  end

  @doc """
  Returns whether the given user is a participant in the relationship.
  """
  def participant?(%Relationship{user_a_id: user_a_id, user_b_id: user_b_id}, user_id) do
    user_id == user_a_id or user_id == user_b_id
  end

  defp log_event(relationship_id, actor_id, from_status, to_status, event_type, metadata \\ %{}) do
    %RelationshipEvent{}
    |> RelationshipEvent.changeset(%{
      relationship_id: relationship_id,
      actor_id: actor_id,
      from_status: from_status,
      to_status: to_status,
      event_type: event_type,
      metadata: metadata
    })
    |> Repo.insert()
  end

  defp log_activity(old_status, new_status, actor_id, relationship) do
    other_id = other_user_id(relationship, actor_id)

    ActivityLog.log("social", "relationship_changed",
      "Relationship changed: #{old_status} -> #{new_status}",
      actor_id: actor_id,
      subject_id: other_id,
      metadata: %{
        "relationship_id" => relationship.id,
        "from_status" => old_status,
        "to_status" => new_status
      }
    )
  end

  defp broadcast_relationship_changed(relationship) do
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      relationship_topic(relationship.id),
      {:relationship_changed, relationship}
    )

    # Also notify both users
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      "messages:user:#{relationship.user_a_id}",
      {:relationship_changed, relationship}
    )

    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      "messages:user:#{relationship.user_b_id}",
      {:relationship_changed, relationship}
    )
  end
end
