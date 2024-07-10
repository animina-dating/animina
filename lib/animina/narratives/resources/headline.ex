defmodule Animina.Narratives.Headline do
  @moduledoc """
  This is the headline resource.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Narratives

  attributes do
    uuid_primary_key :id
    attribute :subject, :string, allow_nil?: false
    attribute :position, :integer, allow_nil?: false
    attribute :is_active, :boolean, default: true
  end

  actions do
    create :create do
      accept [:subject, :position, :is_active]
    end

    read :read do
      primary? true

      pagination offset?: true, keyset?: true, required?: false
    end

    read :by_subject do
      argument :subject, :string, allow_nil?: false

      filter expr(subject == ^arg(:subject))
    end
  end

  code_interface do
    domain Animina.Narratives
    define :read
    define :create
    define :by_id, get_by: [:id], action: :read
    define :by_subject, get_by: [:subject], action: :read
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
