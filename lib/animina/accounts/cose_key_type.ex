defmodule Animina.Accounts.CoseKeyType do
  @moduledoc """
  Custom Ecto type for storing COSE public keys.

  COSE keys are Elixir maps with integer keys (e.g., %{1 => 2, 3 => -7, ...})
  which cannot be stored as JSON. This type serializes them as Erlang terms
  stored in a binary column.
  """

  use Ecto.Type

  def type, do: :binary

  def cast(value) when is_map(value), do: {:ok, value}
  def cast(_), do: :error

  def dump(value) when is_map(value) do
    {:ok, :erlang.term_to_binary(value)}
  end

  def dump(_), do: :error

  def load(binary) when is_binary(binary) do
    {:ok, :erlang.binary_to_term(binary, [:safe])}
  rescue
    _ -> :error
  end

  def load(_), do: :error
end
