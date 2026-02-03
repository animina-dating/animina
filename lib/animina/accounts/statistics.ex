defmodule Animina.Accounts.Statistics do
  @moduledoc """
  User statistics and counting functions.
  """

  import Ecto.Query

  alias Animina.Accounts.{OnlineUserCount, User}
  alias Animina.Repo
  alias Animina.Utils.Timezone
  alias Ecto.Adapters.SQL

  @doc """
  Counts confirmed users whose `inserted_at` falls within today (Europe/Berlin).
  """
  def count_confirmed_users_today_berlin do
    {start_utc, end_utc} = Timezone.berlin_today_utc_range()

    from(u in User,
      where: not is_nil(u.confirmed_at),
      where: u.inserted_at >= ^start_utc,
      where: u.inserted_at < ^end_utc,
      select: count()
    )
    |> Repo.one()
  end

  @doc """
  Returns the 30-day rolling daily average of confirmed users, excluding today.
  """
  def average_daily_confirmed_users_last_30_days do
    {today_start_utc, _} = Timezone.berlin_today_utc_range()
    thirty_days_ago = DateTime.add(today_start_utc, -30, :day)

    result =
      from(u in User,
        where: not is_nil(u.confirmed_at),
        where: u.inserted_at >= ^thirty_days_ago,
        where: u.inserted_at < ^today_start_utc,
        select: count()
      )
      |> Repo.one()

    (result || 0) / 30.0
  end

  @doc """
  Returns today's confirmed users grouped by Berlin hour as `[{hour, count}]`.
  """
  def confirmed_users_today_by_hour_berlin do
    {start_utc, end_utc} = Timezone.berlin_today_utc_range()
    offset_seconds = Timezone.berlin_utc_offset_seconds()

    %{rows: rows} =
      SQL.query!(
        Repo,
        """
        SELECT CAST(EXTRACT(HOUR FROM inserted_at + INTERVAL '1 second' * $1) AS INTEGER) AS berlin_hour,
               COUNT(*)
        FROM users
        WHERE confirmed_at IS NOT NULL
          AND inserted_at >= $2
          AND inserted_at < $3
        GROUP BY berlin_hour
        ORDER BY berlin_hour
        """,
        [offset_seconds, start_utc, end_utc]
      )

    Enum.map(rows, fn [hour, count] -> {hour, count} end)
  end

  @doc """
  Counts confirmed users whose `inserted_at` falls within yesterday (Europe/Berlin).
  """
  def count_confirmed_users_yesterday_berlin do
    {today_start_utc, _} = Timezone.berlin_today_utc_range()
    yesterday_start_utc = DateTime.add(today_start_utc, -1, :day)

    from(u in User,
      where: not is_nil(u.confirmed_at),
      where: u.inserted_at >= ^yesterday_start_utc,
      where: u.inserted_at < ^today_start_utc,
      select: count()
    )
    |> Repo.one()
  end

  @doc """
  Counts the number of users who registered and confirmed within the last 24 hours.
  """
  def count_confirmed_users_last_24h do
    count_confirmed_users_since(DateTime.utc_now() |> DateTime.add(-24, :hour))
  end

  @doc """
  Counts confirmed users whose `inserted_at` falls within the last 7 days.
  """
  def count_confirmed_users_last_7_days do
    count_confirmed_users_since(DateTime.utc_now() |> DateTime.add(-7, :day))
  end

  @doc """
  Counts confirmed users whose `inserted_at` falls within the last 28 days.
  """
  def count_confirmed_users_last_28_days do
    count_confirmed_users_since(DateTime.utc_now() |> DateTime.add(-28, :day))
  end

  defp count_confirmed_users_since(cutoff) do
    from(u in User,
      where: not is_nil(u.confirmed_at),
      where: u.inserted_at >= ^cutoff,
      select: count()
    )
    |> Repo.one()
  end

  @doc """
  Counts all active (non-deleted) users.
  """
  def count_active_users do
    from(u in User, where: is_nil(u.deleted_at), select: count())
    |> Repo.one()
  end

  @doc """
  Counts all confirmed, non-deleted users.
  """
  def count_confirmed_users do
    from(u in User,
      where: is_nil(u.deleted_at),
      where: not is_nil(u.confirmed_at),
      select: count()
    )
    |> Repo.one()
  end

  @doc """
  Counts all unconfirmed, non-deleted users.
  """
  def count_unconfirmed_users do
    from(u in User,
      where: is_nil(u.deleted_at),
      where: is_nil(u.confirmed_at),
      select: count()
    )
    |> Repo.one()
  end

  @doc """
  Counts confirmed, non-deleted users grouped by state.
  Returns a map like `%{"normal" => 10, "waitlisted" => 5}`.
  """
  def count_confirmed_users_by_state do
    from(u in User,
      where: is_nil(u.deleted_at),
      where: not is_nil(u.confirmed_at),
      group_by: u.state,
      select: {u.state, count()}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Counts confirmed, non-deleted users grouped by gender.
  Returns a map like `%{"male" => 10, "female" => 8, "diverse" => 2}`.
  """
  def count_confirmed_users_by_gender do
    from(u in User,
      where: is_nil(u.deleted_at),
      where: not is_nil(u.confirmed_at),
      group_by: u.gender,
      select: {u.gender, count()}
    )
    |> Repo.all()
    |> Map.new()
  end

  # --- Online user counts ---

  @doc """
  Records a snapshot of the current online user count.
  """
  def record_online_user_count(count) do
    %OnlineUserCount{}
    |> OnlineUserCount.changeset(%{count: count, recorded_at: DateTime.utc_now(:second)})
    |> Repo.insert()
  end

  @doc """
  Returns aggregated online user counts since the given datetime,
  bucketed by `bucket_minutes` intervals.

  Returns a list of `%{bucket: DateTime.t(), avg_count: integer()}`.
  """
  def online_user_counts_since(since, bucket_minutes) do
    bucket_seconds = bucket_minutes * 60

    %{rows: rows} =
      SQL.query!(
        Repo,
        """
        SELECT
          to_timestamp(floor(extract(epoch FROM recorded_at) / $1) * $1) AS bucket,
          CAST(round(avg(count)) AS INTEGER) AS avg_count
        FROM online_user_counts
        WHERE recorded_at >= $2
        GROUP BY bucket
        ORDER BY bucket
        """,
        [bucket_seconds, since]
      )

    Enum.map(rows, fn [bucket, avg_count] ->
      %{bucket: DateTime.from_naive!(bucket, "Etc/UTC"), avg_count: avg_count}
    end)
  end

  @doc """
  Returns aggregated registration counts (by inserted_at) since the given datetime,
  bucketed by `bucket_minutes` intervals.

  Returns a list of `%{bucket: DateTime.t(), avg_count: integer()}`.
  """
  def registration_counts_since(since, bucket_minutes) do
    bucket_seconds = bucket_minutes * 60

    %{rows: rows} =
      SQL.query!(
        Repo,
        """
        SELECT
          to_timestamp(floor(extract(epoch FROM inserted_at) / $1) * $1) AS bucket,
          CAST(count(*) AS INTEGER) AS count
        FROM users
        WHERE inserted_at >= $2
        GROUP BY bucket
        ORDER BY bucket
        """,
        [bucket_seconds, since]
      )

    Enum.map(rows, fn [bucket, count] ->
      %{bucket: DateTime.from_naive!(bucket, "Etc/UTC"), avg_count: count}
    end)
  end

  @doc """
  Returns aggregated confirmation counts (by confirmed_at) since the given datetime,
  bucketed by `bucket_minutes` intervals.

  Returns a list of `%{bucket: DateTime.t(), avg_count: integer()}`.
  """
  def confirmation_counts_since(since, bucket_minutes) do
    bucket_seconds = bucket_minutes * 60

    %{rows: rows} =
      SQL.query!(
        Repo,
        """
        SELECT
          to_timestamp(floor(extract(epoch FROM confirmed_at) / $1) * $1) AS bucket,
          CAST(count(*) AS INTEGER) AS count
        FROM users
        WHERE confirmed_at IS NOT NULL
          AND confirmed_at >= $2
        GROUP BY bucket
        ORDER BY bucket
        """,
        [bucket_seconds, since]
      )

    Enum.map(rows, fn [bucket, count] ->
      %{bucket: DateTime.from_naive!(bucket, "Etc/UTC"), avg_count: count}
    end)
  end

  @doc """
  Deletes online user count records older than `days` days. Defaults to 30.
  """
  def purge_old_online_user_counts(days \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days, :day)

    from(o in OnlineUserCount, where: o.recorded_at < ^cutoff)
    |> Repo.delete_all()
  end
end
