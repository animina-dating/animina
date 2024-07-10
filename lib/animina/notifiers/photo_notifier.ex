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
        domain: _domain,
        changeset: _changeset,
        for: _for,
        from: _from,
        metadata: _metadata
      }) do
    case action_type do
      :create ->
        if System.get_env("DISABLE_ML_FEATURES") == false do
          Photo.add_photo(photo)
        end

      _ ->
        :ok
    end
  end
end
