defmodule Animina.Narratives.Headline do
  @moduledoc """
  This is the headline resource.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :subject, :string, allow_nil?: false
    attribute :position, :integer, allow_nil?: false
    attribute :is_active, :boolean, default: true
  end

  actions do
    defaults [:create, :read]
  end

  code_interface do
    define_for Animina.Narratives
    define :read
    define :create
    define :by_id, get_by: [:id], action: :read
  end

  identities do
    identity :unique_subject, [:subject]
    identity :unique_position, [:position]
  end

  postgres do
    table "headlines"
    repo Animina.Repo
  end
end
