defmodule Animina.Traits.Category do
  @moduledoc """
  Name of all the trait categories.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Traits

  attributes do
    uuid_primary_key :id
    attribute :name, :ci_string, allow_nil?: false
  end

  relationships do
    has_many :category_translations, Animina.Traits.CategoryTranslation
    has_many :flags, Animina.Traits.Flag
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :name
      ]

      primary? true
    end
  end

  code_interface do
    domain Animina.Traits
    define :read
    define :create
    define :by_id, get_by: [:id], action: :read
    define :by_name, get_by: [:name], action: :read
  end

  identities do
    identity :unique_name, [:name]
  end

  preparations do
    prepare build(load: [:category_translations, :flags])
  end

  postgres do
    table "traits_categories"
    repo Animina.Repo
  end
end
