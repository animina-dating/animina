defmodule Animina.GenServers.PhotoConsumer do
  @moduledoc """
  Receives photos to process
  """

  def start_link(photo) do
    Task.start_link(fn ->
      photo
      |> Ash.Changeset.for_update(:process, %{})
      |> Ash.update(authorize?: false)
    end)
  end
end
