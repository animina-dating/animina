defmodule Animina.Accounts.AccountSecurityEvent do
  @moduledoc """
  Schema for account security events (email/password changes).

  When a user changes their email or password, a security event is created with
  cryptographic undo and confirm tokens. The old email receives a notification
  with links to undo (revert) or confirm (approve) the change within 48 hours.
  """

  use Ecto.Schema
  import Ecto.Query

  alias __MODULE__

  @hash_algorithm :sha256
  @rand_size 32
  @cooldown_hours 48

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "account_security_events" do
    belongs_to :user, Animina.Accounts.User

    field :event_type, :string
    field :undo_token_hash, :binary
    field :confirm_token_hash, :binary
    field :old_email, :string
    field :old_value, :string
    field :new_value, :string
    field :expires_at, :utc_datetime
    field :resolved_at, :utc_datetime
    field :resolution, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Builds a security event struct with cryptographic undo and confirm tokens.

  Returns `{undo_token, confirm_token, %AccountSecurityEvent{}}`.
  The raw tokens are URL-safe base64 encoded for use in email links.
  Only the SHA-256 hashes are stored in the database.
  """
  def build(user_id, event_type, attrs \\ %{}) do
    undo_token = :crypto.strong_rand_bytes(@rand_size)
    confirm_token = :crypto.strong_rand_bytes(@rand_size)

    event = %AccountSecurityEvent{
      user_id: user_id,
      event_type: event_type,
      undo_token_hash: :crypto.hash(@hash_algorithm, undo_token),
      confirm_token_hash: :crypto.hash(@hash_algorithm, confirm_token),
      old_email: Map.get(attrs, :old_email),
      old_value: Map.get(attrs, :old_value),
      new_value: Map.get(attrs, :new_value),
      expires_at: DateTime.utc_now(:second) |> DateTime.add(@cooldown_hours, :hour)
    }

    {Base.url_encode64(undo_token, padding: false),
     Base.url_encode64(confirm_token, padding: false), event}
  end

  @doc """
  Returns a query that finds an unresolved, unexpired event by undo token.
  Returns `:error` if the token cannot be decoded.
  """
  def verify_undo_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded} ->
        hashed = :crypto.hash(@hash_algorithm, decoded)

        query =
          from e in AccountSecurityEvent,
            where: e.undo_token_hash == ^hashed,
            where: is_nil(e.resolved_at),
            where: e.expires_at > ^DateTime.utc_now(:second)

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Returns a query that finds an unresolved, unexpired event by confirm token.
  Returns `:error` if the token cannot be decoded.
  """
  def verify_confirm_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded} ->
        hashed = :crypto.hash(@hash_algorithm, decoded)

        query =
          from e in AccountSecurityEvent,
            where: e.confirm_token_hash == ^hashed,
            where: is_nil(e.resolved_at),
            where: e.expires_at > ^DateTime.utc_now(:second)

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Returns a query for active (unresolved, unexpired) security events for a user.
  """
  def active_events_query(user_id) do
    from e in AccountSecurityEvent,
      where: e.user_id == ^user_id,
      where: is_nil(e.resolved_at),
      where: e.expires_at > ^DateTime.utc_now(:second)
  end

  @doc "Returns the cooldown duration in hours."
  def cooldown_hours, do: @cooldown_hours
end
