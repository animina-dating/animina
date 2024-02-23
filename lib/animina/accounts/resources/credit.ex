defmodule Animina.Accounts.Credit do
  @moduledoc """
  This is the Credit module which we use to manage points.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :points, :integer, allow_nil?: false

    attribute :subject, :string, allow_nil?: false
    # attribute :subject, :string do
    #   constraints max_length: 255,
    #               min_length: 1,
    #               trim?: true,
    #               allow_empty?: false
    # end
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
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

  postgres do
    table "credits"
    repo Animina.Repo

    references do
      reference :user, on_delete: :delete
    end
  end
end
