defmodule Animina.Accounts.Token do
  @moduledoc """
  This is the Toke module.
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  actions do
    defaults [:read, :destroy]
  end

  code_interface do
    define_for Animina.Accounts
    define :destroy
  end

  token do
    api Animina.Accounts
  end

  postgres do
    table "tokens"
    repo Animina.Repo
  end
end
