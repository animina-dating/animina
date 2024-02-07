defmodule Animina.Accounts.Credit do
  @moduledoc """
  This is the Credit module which we use to manage points.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :points, :integer do
      constraints min: 1,
                  max: 10_000
    end

    attribute :subject, :string do
      constraints max_length: 50,
                  min_length: 1,
                  trim?: true,
                  allow_empty?: false
    end
  end

  relationships do
    belongs_to :user, Animina.Accounts.User
  end

  postgres do
    table "credits"
    repo Animina.Repo
  end

  actions do
    defaults [:create, :read]
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :create
    define :by_id, get_by: [:id], action: :read
  end
end
