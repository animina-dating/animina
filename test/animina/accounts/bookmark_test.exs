defmodule Animina.Accounts.BookmarkTest do
  use Animina.DataCase, async: true
  alias Animina.Accounts.Bookmark
  alias Animina.Accounts.User
  alias Animina.Accounts.VisitLogEntry

  describe "Tests for the Bookmark Resource" do
    setup do
      [
        user_one: create_user_one(),
        user_two: create_user_two(),
        user_three: create_user_three()
      ]
    end

    test "most_often_visited_by_user/1 lists the bookmarks most often visited by a user in the order of the number of visit log entries they have",
         %{
           user_one: user_one,
           user_two: user_two,
           user_three: user_three
         } do
      {:ok, bookmark} = create_bookmark(user_one.id, user_two.id)

      # for this bookmark , we create 10 visit log entries with random durations
      Enum.each(1..10, fn _ ->
        create_visit_log_entry(user_two.id, bookmark.id, 10, user_two)
      end)

      # we then create another bookmark and create 5 visit log entries for it
      {:ok, bookmark_two} = create_bookmark(user_three.id, user_two.id)

      Enum.each(1..5, fn _ ->
        create_visit_log_entry(user_two.id, bookmark_two.id, 10, user_two)
      end)

      bookmark_two = Bookmark.by_id!(bookmark_two.id)

      assert {:ok, most_visited_bookmarks} =
               Bookmark.most_often_visited_by_user(bookmark.owner_id)

      assert length(most_visited_bookmarks.results) == 2

      assert Enum.map(most_visited_bookmarks.results, & &1.id) == [bookmark.id, bookmark_two.id]
    end

    test "longest_overall_duration_visited_by_user/1 lists the bookmarks most often visited by a user in the order of the number of visit log entries they have",
         %{
           user_one: user_one,
           user_two: user_two,
           user_three: user_three
         } do
      {:ok, bookmark} = create_bookmark(user_one.id, user_two.id)

      # for this bookmark , we create 10 visit log entries with random durations
      Enum.each(1..10, fn _ ->
        create_visit_log_entry(user_two.id, bookmark.id, 10, user_two)
      end)

      # we then create another bookmark and create 5 visit log entries for it
      {:ok, bookmark_two} = create_bookmark(user_three.id, user_two.id)

      Enum.each(1..5, fn _ ->
        create_visit_log_entry(user_two.id, bookmark_two.id, 100, user_two)
      end)

      bookmark_two = Bookmark.by_id!(bookmark_two.id)

      Bookmark.longest_overall_duration_visited_by_user(bookmark_two.owner_id)

      assert {:ok, most_visited_bookmarks} =
               Bookmark.longest_overall_duration_visited_by_user(bookmark_two.owner_id)

      assert length(most_visited_bookmarks.results) == 2

      assert Enum.map(most_visited_bookmarks.results, & &1.id) == [bookmark_two.id, bookmark.id]
    end

    test "like/2 creates a bookmark with liked as the reason after taking owner_id and user_id",
         %{
           user_one: user_one,
           user_two: user_two
         } do
      assert {:ok, bookmark} =
               Bookmark.like(%{
                 owner_id: user_two.id,
                 user_id: user_one.id
               })

      assert bookmark.reason == :liked
    end

    test "visit/3 creates a bookmark with visited as the reason after taking owner_id and user_id and last visit at",
         %{
           user_one: user_one,
           user_two: user_two
         } do
      assert {:ok, bookmark} =
               Bookmark.visit(%{
                 owner_id: user_two.id,
                 user_id: user_one.id,
                 last_visit_at: DateTime.utc_now()
               })

      assert bookmark.reason == :visited
    end

    test "update_last_visit/3 updates the last visit at attribute of a bookmark",
         %{
           user_one: user_one,
           user_two: user_two
         } do
      assert {:ok, bookmark} =
               Bookmark.visit(%{
                 owner_id: user_two.id,
                 user_id: user_one.id,
                 last_visit_at: DateTime.utc_now()
               })

      assert bookmark.reason == :visited

      assert {:ok, _updated_bookmark} =
               Bookmark.update_last_visit(bookmark, %{
                 last_visit_at: DateTime.utc_now()
               })
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
        legal_terms_accepted: true,
        country: "Germany"
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
        legal_terms_accepted: true,
        country: "Germany"
      })

    user
  end

  defp create_user_three do
    {:ok, user} =
      User.create(%{
        email: "three@example.com",
        username: "three",
        name: "Three",
        hashed_password: "zzzzzzzzzzz",
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12342678",
        language: "de",
        legal_terms_accepted: true,
        country: "Germany"
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

  defp create_visit_log_entry(user_id, bookmark_id, duration, actor) do
    VisitLogEntry.create(
      %{
        user_id: user_id,
        bookmark_id: bookmark_id,
        duration: duration
      },
      actor: actor
    )
  end
end
