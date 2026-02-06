defmodule Animina.MessagingFixtures do
  @moduledoc """
  Test helpers for creating messaging entities.
  """

  alias Animina.AccountsFixtures
  alias Animina.Messaging

  @doc """
  Creates a conversation between two users.
  """
  def conversation_fixture(user1 \\ nil, user2 \\ nil) do
    user1 = user1 || AccountsFixtures.user_fixture()
    user2 = user2 || AccountsFixtures.user_fixture()

    {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)
    conversation
  end

  @doc """
  Creates a message in a conversation.
  """
  def message_fixture(conversation, sender, attrs \\ %{}) do
    content = Map.get(attrs, :content, "Hello, this is a test message!")

    {:ok, message} = Messaging.send_message(conversation.id, sender.id, content)
    message
  end

  @doc """
  Creates a conversation with messages between two users.
  Returns {conversation, user1, user2, messages}.
  """
  def conversation_with_messages_fixture(message_count \\ 3) do
    user1 = AccountsFixtures.user_fixture()
    user2 = AccountsFixtures.user_fixture()

    {:ok, conversation} = Messaging.get_or_create_conversation(user1.id, user2.id)

    messages =
      Enum.map(1..message_count, fn i ->
        sender = if rem(i, 2) == 1, do: user1, else: user2
        {:ok, message} = Messaging.send_message(conversation.id, sender.id, "Message #{i}")
        message
      end)

    {conversation, user1, user2, messages}
  end
end
