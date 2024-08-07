defmodule Animina.Accounts.Token do
  @moduledoc """
  This is the Token module.
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Accounts,
    extensions: [AshAuthentication.TokenResource]

  actions do
    defaults [:read, :destroy]
  end


  code_interface do
    domain Animina.Accounts
    define :destroy
  end

  token do
    domain Animina.Accounts
  end

  postgres do
    table "tokens"
    repo Animina.Repo
  end
end
