defmodule Animina.Accounts.VisitLogEntryTest do
  use Animina.DataCase, async: true
  alias Animina.Accounts.Bookmark
  alias Animina.Accounts.User
  alias Animina.Accounts.VisitLogEntry

  describe "Tests for the VisitLogEntry Resource" do
    setup do
      [
        user_one: create_user_one(),
        user_two: create_user_two()
      ]
    end

    test "A User Cannot create a visit log entry for a bookmark they do not own", %{
      user_one: user_one,
      user_two: user_two
    } do
      {:ok, bookmark} = create_bookmark(user_one.id, user_two.id)

      assert {:error, _} = create_visit_log_entry(user_one.id, bookmark.id, user_one)

      assert {:ok, _} = create_visit_log_entry(user_two.id, bookmark.id, user_two)
    end

    test "A User Cannot update a visit log entry that they did not create", %{
      user_one: user_one,
      user_two: user_two
    } do
      {:ok, bookmark} = create_bookmark(user_one.id, user_two.id)

      assert {:ok, visit_log_entry} = create_visit_log_entry(user_two.id, bookmark.id, user_two)

      assert {:error, _} = update_visit_log_entry(visit_log_entry, 20, user_one)

      assert {:ok, _} = update_visit_log_entry(visit_log_entry, 20, user_two)
    end
  end

  defp create_user_one do
    {:ok, user} =
      User.create(%{
        email: "bob@example.com",
        username: "bob",
        name: "Bob",
        hashed_password: "zzzzzzzzzzz",
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12345678",
        language: "de",
        legal_terms_accepted: true
      })

    user
  end

  defp create_user_two do
    {:ok, user} =
      User.create(%{
        email: "mike@example.com",
        username: "mike",
        name: "Mike",
        hashed_password: "zzzzzzzzzzz",
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12341678",
        language: "de",
        legal_terms_accepted: true
      })

    user
  end

  defp create_bookmark(user_id, owner_id) do
    Bookmark.visit(%{
      user_id: user_id,
      owner_id: owner_id,
      last_visit_at: DateTime.utc_now()
    })
  end

  defp create_visit_log_entry(user_id, bookmark_id, actor) do
    VisitLogEntry.create(
      %{
        user_id: user_id,
        bookmark_id: bookmark_id,
        duration: 10
      },
      actor: actor
    )
  end

  defp update_visit_log_entry(visit_log_entry, duration, actor) do
    VisitLogEntry.update(
      visit_log_entry,
      %{
        duration: duration
      },
      actor: actor
    )
  end
end
