defmodule Animina.GenServers.PhotoTagConsumer do
  @moduledoc """
  Receives photos to process
  """
  alias Animina.Accounts.Photo

  def start_link(photo) do
    Task.start_link(fn ->
      Photo.create_photo_flags(photo)
    end)
  end
end
