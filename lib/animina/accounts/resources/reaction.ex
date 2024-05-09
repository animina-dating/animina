defmodule Animina.Accounts.Reaction do
  @moduledoc """
  This is the Reaction module which we use to manage likes, block, etc.
  """

  alias Phoenix.PubSub
  alias Animina.Accounts.User

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer

  attributes do
    uuid_primary_key :id

    attribute :name, :atom do
      constraints one_of: [:like, :block, :hide]
      allow_nil? false
    end

    create_timestamp :created_at
  end

  relationships do
    belongs_to :sender, Animina.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :receiver, Animina.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_reaction, [:sender_id, :receiver_id, :name]
  end

  actions do
    defaults [:read, :destroy]

    create :like do
      accept [:sender_id, :receiver_id]
      change set_attribute(:name, :like)
    end

    destroy :unlike do
    end

    destroy :unblock do
    end

    destroy :unhide do
    end

    create :block do
      accept [:sender_id, :receiver_id]
      change set_attribute(:name, :block)
    end

    create :hide do
      accept [:sender_id, :receiver_id]
      change set_attribute(:name, :hide)
    end
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :like
    define :unlike
    define :unblock
    define :unhide
    define :block
    define :hide
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :by_sender_and_receiver_id, get_by: [:sender_id, :receiver_id], action: :read
  end

  changes do
    change after_action(fn changeset, record ->
             sender_username =
               User.by_id!(record.sender_id)
               |> Map.get(:username)
               |> Ash.CiString.value()

             receiver_username =
               User.by_id!(record.receiver_id)
               |> Map.get(:username)
               |> Ash.CiString.value()

             PubSub.broadcast(
               Animina.PubSub,
               sender_username,
               {:user, User.by_id!(record.sender_id)}
             )

             PubSub.broadcast(
               Animina.PubSub,
               receiver_username,
               {:user, User.by_id!(record.receiver_id)}
             )

             {:ok, record}
           end),
           on: [:create, :destroy]
  end

  policies do
    policy action_type(:create) do
      authorize_if Animina.Checks.CreateReactionCheck
    end

    policy action_type(:destroy) do
      authorize_if Animina.Checks.DestroyReactionCheck
    end
  end

  postgres do
    table "reactions"
    repo Animina.Repo

    references do
      reference :sender, on_delete: :delete
      reference :receiver, on_delete: :delete
    end
  end
end
