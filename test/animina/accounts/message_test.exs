defmodule Animina.Accounts.MessageTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.User
  alias Animina.Accounts.Message
  alias Animina.Accounts.Reaction

  describe "Tests for the Message Resource" do
    setup do
      [
        user_with_true_preapproved_communication:
          create_user_with_true_preapproved_communication(),
        user_with_false_preapproved_communication:
          create_user_with_false_preapproved_communication()
      ]
    end

    test "A user who has set the preapproved_communication to false can receive messages from any user",
         %{
           user_with_true_preapproved_communication: user_with_true_preapproved_communication,
           user_with_false_preapproved_communication: user_with_false_preapproved_communication
         } do
      assert {:ok, _message} =
               create_message(
                 user_with_true_preapproved_communication.id,
                 user_with_false_preapproved_communication.id,
                 user_with_true_preapproved_communication
               )
    end

    test "A user who has set the preapproved_communication to true cannot receive messages from users they have not liked",
         %{
           user_with_true_preapproved_communication: user_with_true_preapproved_communication,
           user_with_false_preapproved_communication: user_with_false_preapproved_communication
         } do
      assert {:error, _} =
               create_message(
                 user_with_false_preapproved_communication.id,
                 user_with_true_preapproved_communication.id,
                 user_with_false_preapproved_communication
               )
    end

    test "A user who has set the preapproved_communication to true can receive messages from users they have  liked",
         %{
           user_with_true_preapproved_communication: user_with_true_preapproved_communication,
           user_with_false_preapproved_communication: user_with_false_preapproved_communication
         } do
      # we first add a like reaction

      create_like_reaction(
        user_with_true_preapproved_communication.id,
        user_with_false_preapproved_communication.id
      )

      # now since the like is added , a message can be sent

      assert {:ok, _} =
               create_message(
                 user_with_false_preapproved_communication.id,
                 user_with_true_preapproved_communication.id,
                 user_with_false_preapproved_communication
               )
    end

    test "A user  cannot send a message to themselves",
         %{
           user_with_true_preapproved_communication: user_with_true_preapproved_communication,
           user_with_false_preapproved_communication: user_with_false_preapproved_communication
         } do
      assert {:error, _} =
               create_message(
                 user_with_false_preapproved_communication.id,
                 user_with_false_preapproved_communication.id,
                 user_with_false_preapproved_communication
               )

      assert {:error, _} =
               create_message(
                 user_with_true_preapproved_communication.id,
                 user_with_true_preapproved_communication.id,
                 user_with_true_preapproved_communication
               )
    end
  end

  # for this user , other users can send messages to them without needing the user to like that profile
  defp create_user_with_true_preapproved_communication do
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
        preapproved_communication_only: true
      })

    user
  end

  defp create_user_with_false_preapproved_communication do
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
        preapproved_communication_only: false
      })

    user
  end

  defp create_message(sender_id, receiver_id, actor) do
    Message.create(
      %{
        sender_id: sender_id,
        receiver_id: receiver_id,
        content: "New Message"
      },
      actor: actor
    )
  end

  defp create_like_reaction(sender_id, receiver_id) do
    Reaction.create(%{
      sender_id: sender_id,
      receiver_id: receiver_id,
      name: :like
    })
  end
end
