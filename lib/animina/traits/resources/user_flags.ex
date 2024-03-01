defmodule Animina.Traits.UserFlags do
  @moduledoc """
  This is the UserFlags module which we use to manage a user's flags.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :flag_id, :uuid, allow_nil?: false
    attribute :user_id, :uuid, allow_nil?: false
    attribute :position, :integer, allow_nil?: false

    attribute :color, :atom do
      constraints one_of: [:white, :green, :red]
      allow_nil? false
    end
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      api Animina.Accounts
      allow_nil? false
      attribute_writable? true
    end

    has_one :flag, Animina.Traits.Flag do
      source_attribute :flag_id
      destination_attribute :id
    end
  end

  actions do
    defaults [:create, :read]
  end

  code_interface do
    define_for Animina.Traits
    define :read
    define :create
    define :by_id, get_by: [:id], action: :read
  end

  preparations do
    prepare build(load: [:flag, :user_id])
  end

  postgres do
    table "user_flags"
    repo Animina.Repo

    references do
      reference :user, on_delete: :delete
      reference :flag, on_delete: :delete
    end

    custom_indexes do
      index [:user_id]
      index [:flag_id]
      index [:flag_id, :user_id]
      index [:color, :user_id]
    end
  end
end
