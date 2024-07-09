defmodule Animina.Narratives.PostTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.User
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Post
  alias Animina.Narratives.Story

  describe "Tests for the Post Resource" do
    setup do
      [
        user_one: create_user_one(),
        user_two: create_user_two()
      ]
    end

    test "A user can create a post if they have 3 or more stories", %{
      user_one: user_one
    } do
      # create a post
      post = create_post_with_three_stories(user_one)

      assert {:ok, _} = post
    end

    test "A user cannot create a post if they less than 3  stories", %{
      user_one: user_one
    } do
      # create a post
      post = create_post_with_two_stories(user_one)

      assert {:error, _} = post
    end

    test "A user can edit their own post", %{
      user_one: user_one
    } do
      # create a post
      {:ok, post} = create_post_with_three_stories(user_one)

      # update user post title
      result = update_post_title(post, user_one)

      assert {:ok, _} = result
    end

    test "A user can delete their own post", %{
      user_one: user_one
    } do
      # create a post
      {:ok, post} = create_post_with_three_stories(user_one)

      # delete user post
      result = delete_post(post, user_one)

      assert :ok = result
    end

    test "A user cannot edit another user's post", %{
      user_one: user_one,
      user_two: user_two
    } do
      # create some posts for user one
      Enum.each(1..4, fn _ ->
        create_post_with_three_stories(user_one)
      end)

      # get user one posts
      {:ok, posts} = get_posts_for_user(user_one.id)
      post = posts |> hd

      # update user one post title with user two as actor
      result = update_post_title(post, user_two)

      assert {:error, _} = result
    end

    test "A user cannot delete another user's post", %{
      user_one: user_one,
      user_two: user_two
    } do
      # create some posts for user two
      Enum.each(1..4, fn _ ->
        create_post_with_three_stories(user_two)
      end)

      # get user two posts
      {:ok, posts} = get_posts_for_user(user_two.id)
      post = posts |> hd

      # delete user two post with user one as actor
      result = delete_post(post, user_one)

      assert {:error, _} = result
    end

    test "Unique slug for post by user", %{
      user_one: user_one
    } do
      title = random_title()

      # create first post
      {:ok, _post} = create_post_with_three_stories_with_title(user_one, title)

      # create second post with same title
      result = create_post_with_three_stories_with_title(user_one, title)

      assert {:error, _} = result
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

  defp create_post_with_three_stories(user) do
    title = random_title()
    content = random_lorem_ipsum()

    create_three_stories(user.id)

    Post.create(
      %{
        title: title,
        content: content
      },
      actor: user
    )
  end

  defp create_post_with_two_stories(user) do
    title = random_title()
    content = random_lorem_ipsum()

    create_two_stories(user.id)

    Post.create(
      %{
        title: title,
        content: content
      },
      actor: user
    )
  end

  defp create_post_with_three_stories_with_title(user, title) do
    content = random_lorem_ipsum()
    create_three_stories(user.id)

    Post.create(
      %{
        title: title,
        content: content
      },
      actor: user
    )
  end

  defp delete_post(post, user) do
    Post.destroy(
      post,
      actor: user
    )
  end

  defp update_post_title(post, user) do
    title = random_title()
    Post.update(post, %{title: title}, actor: user)
  end

  defp get_posts_for_user(user_id) do
    Post.by_user_id(user_id)
  end

  def random_title do
    Enum.take_random(
      [
        "Exploring the Mysteries of Lorem Ipsum: An Unexpected Journey",
        "The Hidden Meanings Behind 'Lorem Ipsum Dolor Sit Amet'",
        "From Ancient Text to Modern Usage: The Evolution of Lorem Ipsum",
        "Understanding Lorem Ipsum: A Designer's Best Kept Secret",
        "The Art of Placeholder Text: Why Lorem Ipsum Endures",
        "Lorem Ipsum and the Quest for Perfect Typography",
        "How Lorem Ipsum Shapes the World of Web Design",
        "Decoding the Enigmatic Words: A Deep Dive into Lorem Ipsum",
        "The History and Purpose of Lorem Ipsum in Publishing",
        "Why 'Lorem Ipsum' Remains Relevant in Contemporary Design"
      ],
      1
    )
    |> hd
  end

  defp random_lorem_ipsum do
    lorem_ipsum =
      """
      Lorem ipsum dolor sit amet, **consectetur adipiscing** elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. *Ut enim ad minim veniam*, quis nostrud [exercitation](https://www.heise.de) ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

      Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
      """

    # Step 1: Split the text into sentences
    sentences = String.split(lorem_ipsum, ". ")

    # Step 2: Generate a random number of sentences to take
    # Make sure to add 1 because Enum.take/2 can take negative values for taking from the end
    random_count = :rand.uniform(length(sentences))

    # Step 3: Take that many sentences randomly
    selected_sentences = Enum.take(sentences, random_count)

    # Join the selected sentences back into a string if needed
    Enum.join(selected_sentences, ". ") <> "."
  end

  defp create_three_stories(user_id) do
     about_me_headline = get_about_me_headline()
     non_about_me_headline = get_non_about_me_headline()
     create_about_me_story(user_id, about_me_headline.id)
     create_non_about_me_story(user_id, non_about_me_headline.id, 2)
     create_non_about_me_story(user_id, non_about_me_headline.id, 3)
  end

  defp create_two_stories(user_id) do
    about_me_headline = get_about_me_headline()
    non_about_me_headline = get_non_about_me_headline()
    create_about_me_story(user_id, about_me_headline.id)
    create_non_about_me_story(user_id, non_about_me_headline.id, 4)
  end

  defp get_about_me_headline do
    case Headline.by_subject("About me") do
      {:ok, headline} ->
        headline

      _ ->
        {:ok, headline} =
          Headline.create(%{
            subject: "About me",
            position: 90
          })

        headline
    end
  end

  defp get_non_about_me_headline do
    {:ok, headlines} = Headline.read()

    case headlines do
      [] ->
        {:ok, headline} =
          Headline.create(%{
            subject: "Non About me",
            position: 91
          })

        headline

      _ ->
        headlines
        |> Enum.filter(&(&1.subject != "About me"))
        |> Enum.random()
    end
  end

  defp create_about_me_story(user_id, headline_id) do
    Story.create(%{
      user_id: user_id,
      headline_id: headline_id,
      content: "This is a story about me",
      position: 1
    })
  end

  defp create_non_about_me_story(user_id, headline_id, position) do
    Story.create(%{
      user_id: user_id,
      headline_id: headline_id,
      content: "This is a story about me",
      position: position
    })
  end
end
