defmodule Animina.Discovery.ContactBlacklistFilterTest do
  use Animina.DataCase

  import Ecto.Query
  import Animina.AccountsFixtures

  alias Animina.Accounts.ContactBlacklist
  alias Animina.Accounts.User
  alias Animina.Discovery.Filters.FilterHelpers
  alias Animina.Repo

  # Helper to activate a user (change state from waitlisted to normal)
  defp activate_user(user) do
    user
    |> Ecto.Changeset.change(state: "normal")
    |> Repo.update!()
  end

  defp base_query, do: from(u in User)

  defp query_ids(query) do
    query |> Repo.all() |> Enum.map(& &1.id) |> MapSet.new()
  end

  describe "exclude_contact_blacklisted/2" do
    setup do
      viewer = user_fixture() |> activate_user()
      candidate = user_fixture() |> activate_user()

      %{viewer: viewer, candidate: candidate}
    end

    test "no blacklist entries — all candidates visible", %{viewer: viewer, candidate: candidate} do
      ids = base_query() |> FilterHelpers.exclude_contact_blacklisted(viewer) |> query_ids()

      assert candidate.id in ids
    end

    test "viewer blacklists candidate's email — candidate excluded", %{
      viewer: viewer,
      candidate: candidate
    } do
      {:ok, _} = ContactBlacklist.add_entry(viewer, %{value: candidate.email})

      ids = base_query() |> FilterHelpers.exclude_contact_blacklisted(viewer) |> query_ids()

      refute candidate.id in ids
    end

    test "viewer blacklists candidate's phone — candidate excluded", %{
      viewer: viewer,
      candidate: candidate
    } do
      {:ok, _} = ContactBlacklist.add_entry(viewer, %{value: candidate.mobile_phone})

      ids = base_query() |> FilterHelpers.exclude_contact_blacklisted(viewer) |> query_ids()

      refute candidate.id in ids
    end

    test "candidate blacklists viewer's email — candidate excluded", %{
      viewer: viewer,
      candidate: candidate
    } do
      {:ok, _} = ContactBlacklist.add_entry(candidate, %{value: viewer.email})

      ids = base_query() |> FilterHelpers.exclude_contact_blacklisted(viewer) |> query_ids()

      refute candidate.id in ids
    end

    test "candidate blacklists viewer's phone — candidate excluded", %{
      viewer: viewer,
      candidate: candidate
    } do
      {:ok, _} = ContactBlacklist.add_entry(candidate, %{value: viewer.mobile_phone})

      ids = base_query() |> FilterHelpers.exclude_contact_blacklisted(viewer) |> query_ids()

      refute candidate.id in ids
    end

    test "bidirectional symmetry — A blacklists B's email, check from both perspectives", %{
      viewer: viewer,
      candidate: candidate
    } do
      # Viewer blacklists candidate's email
      {:ok, _} = ContactBlacklist.add_entry(viewer, %{value: candidate.email})

      # From viewer's perspective: candidate should be excluded
      ids_from_viewer =
        base_query() |> FilterHelpers.exclude_contact_blacklisted(viewer) |> query_ids()

      refute candidate.id in ids_from_viewer

      # From candidate's perspective: viewer should also be excluded (reverse direction)
      ids_from_candidate =
        base_query() |> FilterHelpers.exclude_contact_blacklisted(candidate) |> query_ids()

      refute viewer.id in ids_from_candidate
    end

    test "non-matching entry — blacklisting a third party doesn't affect candidate", %{
      viewer: viewer,
      candidate: candidate
    } do
      # Viewer blacklists a random email that doesn't belong to candidate
      {:ok, _} = ContactBlacklist.add_entry(viewer, %{value: "nobody@example.com"})

      ids = base_query() |> FilterHelpers.exclude_contact_blacklisted(viewer) |> query_ids()

      assert candidate.id in ids
    end

    test "phone blacklist only excludes matching candidate, not others", %{
      viewer: viewer,
      candidate: candidate
    } do
      other = user_fixture() |> activate_user()

      # Viewer blacklists candidate's phone
      {:ok, _} = ContactBlacklist.add_entry(viewer, %{value: candidate.mobile_phone})

      ids = base_query() |> FilterHelpers.exclude_contact_blacklisted(viewer) |> query_ids()

      # Candidate is excluded, but other user is not
      refute candidate.id in ids
      assert other.id in ids
    end
  end
end
