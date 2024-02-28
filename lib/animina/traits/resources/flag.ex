defmodule Animina.Traits.Flag do
  @moduledoc """
  Flags
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :name, :ci_string, allow_nil?: false
    attribute :emoji, :string, allow_nil?: true
  end

  relationships do
    has_many :flag_translations, Animina.Traits.FlagTranslation

    belongs_to :category, Animina.Traits.Category do
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  code_interface do
    define_for Animina.Traits
    define :read
    define :create
    define :update
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :by_name, get_by: [:name], action: :read
  end

  identities do
    identity :unique_name, [:name, :category_id]
  end

  preparations do
    prepare build(load: [:flag_translations])
  end

  postgres do
    table "traits_flags"
    repo Animina.Repo
  end
end
