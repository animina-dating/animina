defmodule Animina.Accounts.Secrets do
  @moduledoc """
  This is the Secrets module.
  """

  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Animina.Accounts.User, _) do
    case Application.fetch_env(:animina, AniminaWeb.Endpoint) do
      {:ok, endpoint_config} ->
        Keyword.fetch(endpoint_config, :secret_key_base)

      :error ->
        :error
    end
  end

  def secret_for([:authentication, :tokens, :signing_secret], Animina.Accounts.BasicUser, _) do
    case Application.fetch_env(:animina, AniminaWeb.Endpoint) do
      {:ok, endpoint_config} ->
        Keyword.fetch(endpoint_config, :secret_key_base)

      :error ->
        :error
    end
  end
end
