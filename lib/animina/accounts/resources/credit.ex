defmodule Animina.Accounts.Credit do
  @moduledoc """
  This is the Credit module which we use to manage points.
  """

  alias Animina.Accounts.User
  alias Phoenix.PubSub

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :points, :integer, allow_nil?: false
    attribute :subject, :string, allow_nil?: false

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :donor, Animina.Accounts.User do
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :read]

    read :profile_view_credits_by_donor_and_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      argument :donor_id, :uuid do
        allow_nil? false
      end

      filter expr(
               donor_id == ^arg(:donor_id) and user_id == ^arg(:user_id) and
                 subject == "Profile View"
             )
    end
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :create
    define :by_id, get_by: [:id], action: :read
    define :profile_view_credits_by_donor_and_user, args: [:user_id, :donor_id]
  end

  changes do
    change after_action(fn changeset, record ->
             username =
               User.by_id!(record.user_id)
               |> Map.get(:username)
               |> Ash.CiString.value()

             PubSub.broadcast(Animina.PubSub, username, {:user, User.by_id!(record.user_id)})

             {:ok, record}
           end),
           on: [:create]
  end

  postgres do
    table "credits"
    repo Animina.Repo

    references do
      reference :user, on_delete: :delete
    end
  end
end
