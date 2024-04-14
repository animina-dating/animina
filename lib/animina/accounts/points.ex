defmodule Animina.Accounts.Points do
  @moduledoc """
  This is the module to handle the credit points
  """

  def humanized_points(nil) do
    "0"
  end

  def humanized_points(points) when is_integer(points) and points < 1_000 do
    Integer.to_string(points)
  end

  def humanized_points(points) when is_integer(points) and points < 1_000_000 do
    Integer.to_string(div(points, 1_000)) <> "\u{00a0}k"
  end

  def humanized_points(points) when is_integer(points) do
    Integer.to_string(div(points, 1_000_000)) <> "\u{00a0}M"
  end
end
