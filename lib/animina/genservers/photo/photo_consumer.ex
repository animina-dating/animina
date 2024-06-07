defmodule Animina.GenServers.PhotoConsumer do
  @moduledoc """
  Receives photos to process
  """

  alias Animina.Accounts

  def start_link(photo) do
    Task.start_link(fn ->
      photo
      |> Ash.Changeset.for_update(:process, %{})
      |> Accounts.update(authorize?: false)
    end)
  end
end
