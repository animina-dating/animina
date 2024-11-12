defmodule Animina.Traits.Flag do
  @moduledoc """
  Flags
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Traits

  postgres do
    table "traits_flags"
    repo Animina.Repo

    custom_indexes do
      index [:category_id]
    end
  end

  code_interface do
    domain Animina.Traits
    define :read
    define :create
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :by_name, get_by: [:name], action: :read
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :emoji,
        :category_id,
        :photo_flagable
      ]

      primary? true
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :ci_string, allow_nil?: false
    attribute :emoji, :string, allow_nil?: true
    attribute :photo_flagable, :boolean, default: false
  end

  relationships do
    belongs_to :category, Animina.Traits.Category do
      attribute_writable? true
    end
  end

  identities do
    identity :unique_name, [:name, :category_id]
  end
end
