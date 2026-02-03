defmodule Animina.Utils.PaperTrail do
  @moduledoc """
  Shared helpers for PaperTrail audit logging.
  """

  alias Animina.Accounts.User

  @doc """
  Builds PaperTrail options from keyword options.

  If `opts` contains an `:originator` key with a `%User{}`, returns
  `[originator: user]`. Otherwise returns an empty list.

  ## Examples

      iex> opts([originator: %User{id: "123"}])
      [originator: %User{id: "123"}]

      iex> opts([])
      []
  """
  def opts(keyword_opts) do
    case Keyword.get(keyword_opts, :originator) do
      %User{} = user -> [originator: user]
      _ -> []
    end
  end

  @doc """
  Unwraps a PaperTrail result, extracting the model from the success tuple.

  PaperTrail returns `{:ok, %{model: model, version: version}}` on success.
  This helper extracts just the model for cleaner code.

  ## Examples

      iex> unwrap({:ok, %{model: %User{id: "123"}}})
      {:ok, %User{id: "123"}}

      iex> unwrap({:error, changeset})
      {:error, changeset}
  """
  def unwrap({:ok, %{model: model}}), do: {:ok, model}
  def unwrap({:error, _} = error), do: error
end
