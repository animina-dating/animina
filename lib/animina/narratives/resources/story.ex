defmodule Animina.Narratives.Story do
  @moduledoc """
  This is the story resource.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :content, :string, allow_nil?: false
    attribute :position, :integer, allow_nil?: false
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      api Animina.Accounts
      attribute_writable? true
    end

    belongs_to :headline, Animina.Narratives.Headline do
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :update, :destroy, :read]
  end

  code_interface do
    define_for Animina.Narratives
    define :read
    define :create
    define :update
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :by_user_id, get_by: [:user_id], action: :read
  end

  identities do
    identity :unique_position, [:position, :user_id]
  end

  postgres do
    table "stories"
    repo Animina.Repo
  end
end
