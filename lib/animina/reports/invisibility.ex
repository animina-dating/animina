defmodule Animina.Reports.Invisibility do
  @moduledoc """
  Manages bidirectional invisibility between users involved in reports.

  Uses both user_id (fast lookup for active users) and phone_hash
  (persists after account deletion) for each invisibility entry.
  """

  import Ecto.Query

  alias Animina.Reports.IdentityHash
  alias Animina.Reports.ReportInvisibility
  alias Animina.Repo

  @doc """
  Creates mutual invisibility entries (two rows) for a report.
  """
  def create_mutual_invisibility(user_a, user_b, report) do
    hash_a = IdentityHash.hash_phone(user_a.mobile_phone)
    hash_b = IdentityHash.hash_phone(user_b.mobile_phone)

    # A hidden from B
    entry_a = %{
      user_id: user_a.id,
      hidden_user_id: user_b.id,
      user_phone_hash: hash_a,
      hidden_phone_hash: hash_b,
      report_id: report.id
    }

    # B hidden from A
    entry_b = %{
      user_id: user_b.id,
      hidden_user_id: user_a.id,
      user_phone_hash: hash_b,
      hidden_phone_hash: hash_a,
      report_id: report.id
    }

    with {:ok, _} <-
           %ReportInvisibility{}
           |> ReportInvisibility.changeset(entry_a)
           |> Repo.insert(
             on_conflict: :nothing,
             conflict_target: [:user_phone_hash, :hidden_phone_hash]
           ),
         {:ok, _} <-
           %ReportInvisibility{}
           |> ReportInvisibility.changeset(entry_b)
           |> Repo.insert(
             on_conflict: :nothing,
             conflict_target: [:user_phone_hash, :hidden_phone_hash]
           ) do
      :ok
    end
  end

  @doc """
  Checks if one user is hidden from another (fast user_id-based lookup).
  """
  def hidden?(user_id, other_id) do
    ReportInvisibility
    |> where([i], i.user_id == ^user_id and i.hidden_user_id == ^other_id)
    |> Repo.exists?()
  end

  @doc """
  Returns a list of user IDs hidden from the given user.
  Used for discovery filter integration.
  """
  def hidden_user_ids(user_id) do
    ReportInvisibility
    |> where([i], i.user_id == ^user_id)
    |> where([i], not is_nil(i.hidden_user_id))
    |> select([i], i.hidden_user_id)
    |> Repo.all()
  end

  @doc """
  Called on registration to restore invisibility links for a re-registering user.

  Finds rows where the user's phone hash matches either side and fills in
  the user_id / hidden_user_id.
  """
  def restore_invisibilities_for_new_user(user) do
    phone_hash = IdentityHash.hash_phone(user.mobile_phone)

    # Rows where the new user was the "user" side
    from(i in ReportInvisibility,
      where: i.user_phone_hash == ^phone_hash and is_nil(i.user_id)
    )
    |> Repo.update_all(set: [user_id: user.id])

    # Rows where the new user was the "hidden" side
    from(i in ReportInvisibility,
      where: i.hidden_phone_hash == ^phone_hash and is_nil(i.hidden_user_id)
    )
    |> Repo.update_all(set: [hidden_user_id: user.id])

    :ok
  end
end
