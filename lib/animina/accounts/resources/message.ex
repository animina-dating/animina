defmodule Animina.Accounts.Message do
  @moduledoc """
  This is the Message module which we use to manage messages between users.
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer

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
      api Animina.Accounts
      attribute_writable? true
      allow_nil? false
    end

    belongs_to :receiver, Animina.Accounts.User do
      api Animina.Accounts
      attribute_writable? true
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read]

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

    read :messages_for_sender_and_receiver do
      argument :sender_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:sender, :receiver])

      argument :receiver_id, :uuid do
        allow_nil? false
      end

      filter expr(
               (sender_id == ^arg(:sender_id) and receiver_id == ^arg(:receiver_id)) or
                 (sender_id == ^arg(:receiver_id) and receiver_id == ^arg(:sender_id))
             )
    end

    read :unread_messages_for_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(receiver_id == ^arg(:user_id) and is_nil(read_at))
    end
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :create

    define :by_id, args: [:id]
    define :has_been_read
    define :unread_messages_for_user, args: [:user_id]

    define :messages_for_sender_and_receiver, args: [:sender_id, :receiver_id]
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

  postgres do
    table "messages"
    repo Animina.Repo

    references do
      reference :sender, on_delete: :delete
      reference :receiver, on_delete: :delete
    end
  end
end
