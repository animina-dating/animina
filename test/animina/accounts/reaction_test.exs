defmodule Animina.Accounts.ReactionTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.Reaction
  alias Animina.Accounts.User

  describe "Tests for the Message Resource" do
    setup do
      [
        user_one: create_user_one(),
        user_two: create_user_two()
      ]
    end

    test "The like action creates a reaction with the name :like", %{
      user_one: user_one,
      user_two: user_two
    } do
      assert {:ok, reaction} =
               create_like_reaction(
                 user_one.id,
                 user_two.id,
                 user_one
               )

      assert reaction.name == :like
    end

    test "The block action creates a reaction with the name :block", %{
      user_one: user_one,
      user_two: user_two
    } do
      assert {:ok, reaction} =
               create_block_reaction(
                 user_one.id,
                 user_two.id,
                 user_one
               )

      assert reaction.name == :block
    end

    test "The hide action creates a reaction with the name :hide", %{
      user_one: user_one,
      user_two: user_two
    } do
      assert {:ok, reaction} =
               create_hide_reaction(
                 user_one.id,
                 user_two.id,
                 user_one
               )

      assert reaction.name == :hide
    end

    test "The unlike action deletes a reaction", %{
      user_one: user_one,
      user_two: user_two
    } do
      assert {:ok, reaction} =
               create_block_reaction(
                 user_one.id,
                 user_two.id,
                 user_one
               )

      assert :ok =
               Reaction.unlike(reaction)
    end

    test "A user cannot create reactions for their own profiles",
         %{
           user_one: user_one,
           user_two: user_two
         } do
      assert {:error, _} =
               create_like_reaction(
                 user_one,
                 user_one,
                 user_one
               )
    end

    test "A user cannot create reactions for other profiles",
         %{
           user_one: user_one,
           user_two: user_two
         } do
      assert {:error, _} =
               create_like_reaction(
                 user_one,
                 user_two,
                 user_two
               )
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

  defp create_like_reaction(sender_id, receiver_id, actor) do
    Reaction.like(
      %{
        sender_id: sender_id,
        receiver_id: receiver_id
      },
      actor: actor
    )
  end

  defp create_block_reaction(sender_id, receiver_id, actor) do
    Reaction.block(
      %{
        sender_id: sender_id,
        receiver_id: receiver_id
      },
      actor: actor
    )
  end

  defp create_hide_reaction(sender_id, receiver_id, actor) do
    Reaction.hide(
      %{
        sender_id: sender_id,
        receiver_id: receiver_id
      },
      actor: actor
    )
  end
end
