defmodule Animina.Accounts.Reaction do
  @moduledoc """
  This is the Reaction module which we use to manage likes, block, etc.
  """

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
    defaults [:create, :read, :destroy]
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :create
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :by_sender_and_receiver_id, get_by: [:sender_id, :receiver_id], action: :read
  end

  policies do
    policy action_type(:create) do
      authorize_if Animina.Checks.CreateReactionCheck
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
