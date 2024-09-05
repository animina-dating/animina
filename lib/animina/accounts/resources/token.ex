defmodule Animina.Accounts.Token do
  @moduledoc """
  This is the Token module.
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Accounts,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "tokens"
    repo Animina.Repo
  end

  token do
    domain Animina.Accounts
  end

  code_interface do
    domain Animina.Accounts
    define :destroy
  end

  actions do
    defaults [:read, :destroy]
  end
end
