defmodule Animina.Accounts.MessageTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.Message
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.User

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

    test "A user can only read messages that they are the sender or receiver of" do
      third_user = create_third_user()
      fourth_user = create_fourth_user()
      fifth_user = create_fifth_user()

      create_message(
        third_user.id,
        fourth_user.id,
        third_user
      )

      assert {:ok, _} =
               Message.messages_for_sender_and_receiver(
                 third_user.id,
                 fourth_user.id,
                 actor: third_user
               )

      assert {:error, _} =
               Message.messages_for_sender_and_receiver(
                 third_user.id,
                 fourth_user.id,
                 actor: fifth_user
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

  defp create_third_user do
    {:ok, user} =
      User.create(%{
        email: "three@example.com",
        username: "three",
        name: "three",
        hashed_password: "zzzzzzzzzzz",
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-22345678",
        language: "de",
        legal_terms_accepted: true,
        preapproved_communication_only: false
      })

    user
  end

  defp create_fourth_user do
    {:ok, user} =
      User.create(%{
        email: "four@example.com",
        username: "four",
        name: "four",
        hashed_password: "zzzzzzzzzzz",
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-21345678",
        language: "de",
        legal_terms_accepted: true,
        preapproved_communication_only: false
      })

    user
  end

  defp create_fifth_user do
    {:ok, user} =
      User.create(%{
        email: "fifth@example.com",
        username: "fifth",
        name: "fifth",
        hashed_password: "zzzzzzzzzzz",
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-21445678",
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
    Reaction.like(%{
      sender_id: sender_id,
      receiver_id: receiver_id
    })
  end
end
