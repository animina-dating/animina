defmodule Animina.Test do
  def update_array(state, map) do
    case Enum.find(state, fn x -> x["user_id"] == map["user_id"] end) do
      nil ->
        state ++ [map]

      _ ->
        Enum.drop_while(state, fn x -> x["user_id"] == map["user_id"] end)
        |> List.insert_at(0, map)
    end
  end
end
