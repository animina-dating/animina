defmodule Animina.Accounts.Message do
  @moduledoc """
  This is the Message module which we use to manage messages between users.
  """

  alias Phoenix.PubSub
  require Ash.Query

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer,
    domain: Animina.Accounts

  postgres do
    table "messages"
    repo Animina.Repo

    references do
      reference :sender, on_delete: :delete
      reference :receiver, on_delete: :delete
    end
  end

  code_interface do
    domain Animina.Accounts
    define :read
    define :create

    define :by_id, args: [:id]
    define :has_been_read
    define :unread_messages_for_user, args: [:user_id]

    define :last_unread_message_by_receiver, args: [:receiver_id], get?: true

    define :messages_for_sender_and_receiver, args: [:sender_id, :receiver_id]
    define :messages_sent_to_a_user_by_sender, args: [:sender_id, :receiver_id]

    define :messages_sent_by_user, args: [:sender_id]
    define :conversation_with_user, args: [:user_id]
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :content,
        :sender_id,
        :receiver_id,
        :read_at
      ]

      primary? true
    end

    update :has_been_read do
      change set_attribute(:read_at, DateTime.utc_now())
    end

    read :by_id do
      argument :id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:sender, :receiver])

      filter expr(id == ^arg(:id))
    end

    read :conversation_with_user do
      argument :user_id, :uuid, allow_nil?: false

      filter expr(sender_id == ^arg(:user_id) or receiver_id == ^arg(:user_id))

      prepare build(sort: [created_at: :desc])
      prepare build(load: [:sender, :receiver])
    end

    read :messages_for_sender_and_receiver do
      argument :sender_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:sender, :receiver])

      prepare build(sort: [created_at: :desc])

      argument :receiver_id, :uuid do
        allow_nil? false
      end

      pagination offset?: true, default_limit: 400

      filter expr(
               (sender_id == ^arg(:sender_id) and receiver_id == ^arg(:receiver_id)) or
                 (sender_id == ^arg(:receiver_id) and receiver_id == ^arg(:sender_id))
             )
    end

    read :messages_sent_to_a_user_by_sender do
      argument :sender_id, :uuid do
        allow_nil? false
      end

      argument :receiver_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:sender, :receiver])

      filter expr(sender_id == ^arg(:sender_id) and receiver_id == ^arg(:receiver_id))
    end

    read :messages_sent_by_user do
      argument :sender_id, :uuid do
        allow_nil? false
      end

      filter expr(sender_id == ^arg(:sender_id))
    end

    read :unread_messages_for_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:sender, :receiver])
      prepare build(sort: [created_at: :desc])

      filter expr(receiver_id == ^arg(:user_id) and is_nil(read_at))
    end

    read :last_unread_message_by_receiver do
      argument :receiver_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:sender])

      prepare build(sort: [created_at: :desc], limit: 1)

      filter expr(receiver_id == ^arg(:receiver_id) and is_nil(read_at))
    end
  end

  policies do
    policy action_type(:create) do
      authorize_if Animina.Checks.CreateMessageCheck
    end

    policy action(:messages_for_sender_and_receiver) do
      authorize_if Animina.Checks.ReadMessageCheck
    end

    policy action(:has_been_read) do
      authorize_if Animina.Checks.UpdateReadAtCheck
    end
  end

  changes do
    change after_action(fn changeset, record, _context ->
             PubSub.broadcast(Animina.PubSub, "messages", {:new_message, record})

             {:ok, record}
           end),
           on: [:create]
  end

  def unique_new_messages_for_user(user_id) do
    messages = unread_messages_for_user!(user_id)

    messages
    |> Enum.group_by(& &1.sender_id)
    |> Enum.map(fn {_, messages} -> List.first(messages) end)
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      constraints max_length: 1_024
      allow_nil? false
    end

    attribute :read_at, :utc_datetime_usec do
      allow_nil? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :sender, Animina.Accounts.User do
      domain Animina.Accounts
      attribute_writable? true
      allow_nil? false
    end

    belongs_to :receiver, Animina.Accounts.User do
      domain Animina.Accounts
      attribute_writable? true
      allow_nil? false
    end
  end

  def get_conversations(user_id) do
    messages =
      conversation_with_user!(user_id)

    messages
    |> Enum.group_by(fn msg -> if msg.sender_id == user_id, do: msg.receiver, else: msg.sender end)
    |> Enum.map(fn {user, msgs} ->
      # Get the first message, not the entire list
      first_message = List.first(msgs)
      {user, first_message, first_message.created_at}
    end)
    |> Enum.sort_by(fn {_, _, last_message_at} -> last_message_at end, {:desc, DateTime})
  end
end
