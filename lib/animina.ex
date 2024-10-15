defmodule Animina do
  @moduledoc """
  Animina keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Pubsub broadcast
  """
  def broadcast(topic, _event, payload) do
    Phoenix.PubSub.broadcast(Animina.PubSub, topic, payload)
  end

  @doc """
  Converts string keys in a map to atoms recursively
  """
  def keys_to_atoms(string_key_map) when is_map(string_key_map) do
    for {key, val} <- string_key_map, into: %{}, do: {String.to_atom(key), keys_to_atoms(val)}
  end

  def keys_to_atoms(string_key_list) when is_list(string_key_list) do
    string_key_list
    |> Enum.map(&keys_to_atoms/1)
  end

  def keys_to_atoms(value), do: value
end
