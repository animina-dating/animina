defmodule Animina.Notifiers.Photo do
  @moduledoc """
  The [Animina.Accounts.Photo] notifier module
  """
  use Ash.Notifier

  alias Animina.GenServers.Photo

  require Logger

  def notify(%Ash.Notifier.Notification{
        resource: _resource,
        data: photo,
        action: %{type: action_type},
        actor: _actor,
        api: _api,
        changeset: _changeset,
        for: _for,
        from: _from,
        metadata: _metadata
      }) do
    case action_type do
      :create ->
        Photo.add_photo(photo)

      _ ->
        :ok
    end
  end
end
