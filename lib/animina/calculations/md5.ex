defmodule Animina.Calculations.Md5 do
  @moduledoc """
  This is a module for calculating the MD5 hash of an email address.
  """

  use Ash.Calculation

  def calculate(records, opts, _) do
    Enum.map(records, fn record -> md5(Map.get(record, opts[:field])) end)
  end

  defp md5(data) do
    # Convert data to a string, handling Ash.CiString or any other type correctly
    string_data = to_string(data)

    :crypto.hash(:sha256, string_data)
    |> Base.encode16()
    |> String.downcase()
  end
end
