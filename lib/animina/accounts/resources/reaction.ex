defmodule Animina.Accounts.Reaction do
  @moduledoc """
  This is the Reaction module which we use to manage likes, block, etc.
  """

  alias Animina.Accounts.Bookmark
  alias Animina.Accounts.User
  alias Phoenix.PubSub

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer,
    domain: Animina.Accounts,
    extensions: [Ash.Notifier.PubSub]

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

  pub_sub do
    module Animina
    prefix "reaction"

    broadcast_type :phoenix_broadcast

    publish :create, ["created", [:receiver_id, nil]]
    publish :create, ["created", [:sender_id, nil]]
    publish :destroy, ["deleted", [:receiver_id, nil]]
    publish :destroy, ["deleted", [:sender_id, nil]]
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
      require_atomic? false
    end

    destroy :unblock do
      require_atomic? false
    end

    destroy :unhide do
      require_atomic? false
    end

    create :block do
      accept [:sender_id, :receiver_id]
      change set_attribute(:name, :block)
    end

    create :hide do
      accept [:sender_id, :receiver_id]
      change set_attribute(:name, :hide)
    end

    read :profiles_liked_by_user do
      argument :sender_id, :uuid do
        allow_nil? false
      end

      filter expr(name == :like and sender_id == ^arg(:sender_id))
    end

    read :likes_received_by_user_in_seven_days do
      argument :receiver_id, :uuid do
        allow_nil? false
      end

      filter expr(
               name == :like and
                 receiver_id == ^arg(:receiver_id) and
                 created_at >= ^DateTime.add(DateTime.utc_now(), -7, :day)
             )
    end

    read :total_likes_received_by_user do
      argument :receiver_id, :uuid do
        allow_nil? false
      end

      filter expr(
               name == :like and
                 receiver_id == ^arg(:receiver_id)
             )
    end
  end

  code_interface do
    domain Animina.Accounts
    define :read
    define :like
    define :unlike
    define :unblock
    define :unhide
    define :block
    define :hide
    define :destroy
    define :profiles_liked_by_user, args: [:sender_id]
    define :likes_received_by_user_in_seven_days, args: [:receiver_id]
    define :total_likes_received_by_user, args: [:receiver_id]
    define :by_id, get_by: [:id], action: :read
    define :by_sender_and_receiver_id, get_by: [:sender_id, :receiver_id], action: :read
  end

  changes do
    change after_action(fn changeset, record, _context ->
             PubSub.broadcast(
               Animina.PubSub,
               record.sender_id,
               {:user, User.by_id!(record.sender_id)}
             )

             PubSub.broadcast(
               Animina.PubSub,
               record.receiver_id,
               {:user, User.by_id!(record.receiver_id)}
             )

             {:ok, record}
           end),
           on: [:create, :destroy]

    change after_transaction(fn
             _changeset, {:ok, result}, _context ->
               if result.name == :like do
                 Bookmark.like(
                   %{
                     owner_id: result.sender_id,
                     user_id: result.receiver_id
                   },
                   authorize?: false
                 )
               end

               {:ok, result}

             _changeset, {:error, error}, _context ->
               {:error, error}
           end),
           on: :create

    change after_transaction(fn
             _changeset, {:ok, result}, _context ->
               if result.name == :like do
                 case Bookmark.by_owner_user_and_reason(
                        result.sender_id,
                        result.receiver_id,
                        :liked,
                        authorize?: false
                      ) do
                   {:ok, bookmark} ->
                     Bookmark.unlike(bookmark, authorize?: false)

                   {:error, _error} ->
                     :ok
                 end
               end

               {:ok, result}

             _changeset, {:error, error}, _context ->
               {:error, error}
           end),
           on: :destroy
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
