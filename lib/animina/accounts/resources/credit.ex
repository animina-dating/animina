defmodule Animina.Accounts.Credit do
  @moduledoc """
  This is the Credit module which we use to manage points.
  """
  alias Animina.Accounts.FastUser
  alias Phoenix.PubSub

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Accounts

  postgres do
    table "credits"
    repo Animina.Repo

    references do
      reference :user, on_delete: :delete
      reference :donor, on_delete: :delete
    end

    custom_indexes do
      index [:donor_id]
      index [:user_id]
    end
  end

  code_interface do
    domain Animina.Accounts
    define :read
    define :create
    define :by_id, get_by: [:id], action: :read
    define :profile_view_credits_by_donor_and_user, args: [:donor_id, :user_id]
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :points,
        :user_id,
        :subject,
        :donor_id
      ]

      primary? true
    end

    read :profile_view_credits_by_donor_and_user do
      argument :donor_id, :uuid do
        allow_nil? false
      end

      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(donor_id == ^arg(:donor_id) and user_id == ^arg(:user_id))
    end
  end

  changes do
    change after_action(fn changeset, record, _context ->
             user = get_user(record.user_id)

             PubSub.broadcast(
               Animina.PubSub,
               record.user_id,
               {:user, user}
             )

             PubSub.broadcast(
               Animina.PubSub,
               "credits",
               {:credit_updated, %{"points" => user.credit_points, "user_id" => record.user_id}}
             )

             {:ok, record}
           end),
           on: [:create]
  end

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

  defp get_user(user_id) do
    {:ok, user} =
      FastUser
      |> Ash.ActionInput.for_action(:by_id_email_or_username, %{id: user_id})
      |> Ash.run_action()

    user
  end
end
