defmodule Animina.Accounts.BadPassword do
  @moduledoc """
  This is the modul to store and check for really bad passwords.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Accounts

  postgres do
    table "bad_passwords"
    repo Animina.Repo
  end

  code_interface do
    domain Animina.Accounts
    define :read
    define :create
    define :by_id, get_by: [:id], action: :read
    define :by_value, get_by: [:value], action: :read
  end

  actions do
    defaults [:create, :read]
  end

  attributes do
    uuid_primary_key :id
    attribute :value, :ci_string, allow_nil?: false
  end

  identities do
    identity :value, [:value]
  end
end
