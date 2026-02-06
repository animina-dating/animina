defmodule Animina.Discovery.Popularity do
  @moduledoc """
  Context for managing popular user protection.

  This module provides functions for:
  - Recording first-contact inquiries between users
  - Tracking daily inquiry counts
  - Computing rolling popularity averages
  - Identifying users who have exceeded the daily inquiry limit

  ## Usage

  When a user sends their first message to another user:

      Popularity.record_inquiry(sender_id, receiver_id)

  To check if a user should be excluded from discovery:

      Popularity.exceeded_daily_limit?(user_id)

  To get user IDs that should be filtered from discovery:

      Popularity.users_exceeding_daily_limit()
  """

  import Ecto.Query

  alias Animina.Discovery.Schemas.{Inquiry, PopularityStat}
  alias Animina.Discovery.Settings
  alias Animina.Repo

  # --- Inquiry Recording ---

  @doc """
  Records a first-contact inquiry from sender to receiver.

  This should be called when a user sends their first message to another user.
  Subsequent messages between the same pair don't create new inquiries.

  Returns `{:ok, inquiry}` on success. If the inquiry already exists,
  returns `{:ok, existing_inquiry}` (idempotent).
  """
  def record_inquiry(sender_id, receiver_id) do
    attrs = %{
      sender_id: sender_id,
      receiver_id: receiver_id,
      inquiry_date: Date.utc_today()
    }

    %Inquiry{}
    |> Inquiry.changeset(attrs)
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: [:sender_id, :receiver_id],
      returning: true
    )
    |> case do
      {:ok, %Inquiry{id: nil}} ->
        # Conflict occurred, return existing inquiry
        {:ok, get_inquiry(sender_id, receiver_id)}

      result ->
        result
    end
  end

  @doc """
  Checks if an inquiry already exists from sender to receiver.
  """
  def inquiry_exists?(sender_id, receiver_id) do
    Inquiry
    |> where([i], i.sender_id == ^sender_id and i.receiver_id == ^receiver_id)
    |> Repo.exists?()
  end

  defp get_inquiry(sender_id, receiver_id) do
    Inquiry
    |> where([i], i.sender_id == ^sender_id and i.receiver_id == ^receiver_id)
    |> Repo.one()
  end

  # --- Daily Count Functions ---

  @doc """
  Gets the number of inquiries a user received on a specific date.
  """
  def get_daily_count(user_id, date) do
    Inquiry
    |> where([i], i.receiver_id == ^user_id and i.inquiry_date == ^date)
    |> Repo.aggregate(:count)
  end

  @doc """
  Checks if a user has exceeded the daily inquiry limit for today.

  When true, the user should be temporarily removed from discovery
  to prevent overwhelming popular users.
  """
  def exceeded_daily_limit?(user_id) do
    limit = Settings.daily_inquiry_limit()
    count = get_daily_count(user_id, Date.utc_today())
    count >= limit
  end

  @doc """
  Returns a list of user IDs who have exceeded the daily inquiry limit today.

  This is used by the discovery filter to exclude these users from suggestions.
  """
  def users_exceeding_daily_limit do
    limit = Settings.daily_inquiry_limit()
    today = Date.utc_today()

    Inquiry
    |> where([i], i.inquiry_date == ^today)
    |> group_by([i], i.receiver_id)
    |> having([i], count(i.id) >= ^limit)
    |> select([i], i.receiver_id)
    |> Repo.all()
  end

  # --- Rolling Averages ---

  @doc """
  Gets the rolling averages for a user.

  Returns `{avg_7_day, avg_30_day}` tuple.
  Returns `{0.0, 0.0}` if no stats exist.
  """
  def get_rolling_averages(user_id) do
    case get_latest_stat(user_id) do
      nil -> {0.0, 0.0}
      stat -> {stat.avg_7_day || 0.0, stat.avg_30_day || 0.0}
    end
  end

  defp get_latest_stat(user_id) do
    PopularityStat
    |> where([s], s.user_id == ^user_id)
    |> order_by([s], desc: s.stat_date)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Computes and stores rolling averages for a user as of the given date.

  This calculates:
  - The daily inquiry count for the specified date
  - The 7-day rolling average (inquiries over past 7 days / 7)
  - The 30-day rolling average (inquiries over past 30 days / 30)
  """
  def compute_rolling_averages(user_id, date) do
    # Get inquiry counts for rolling windows
    seven_days_ago = Date.add(date, -6)
    thirty_days_ago = Date.add(date, -29)

    # Count inquiries in 7-day window
    count_7 =
      Inquiry
      |> where([i], i.receiver_id == ^user_id)
      |> where([i], i.inquiry_date >= ^seven_days_ago and i.inquiry_date <= ^date)
      |> Repo.aggregate(:count)

    # Count inquiries in 30-day window
    count_30 =
      Inquiry
      |> where([i], i.receiver_id == ^user_id)
      |> where([i], i.inquiry_date >= ^thirty_days_ago and i.inquiry_date <= ^date)
      |> Repo.aggregate(:count)

    # Get today's count
    daily_count = get_daily_count(user_id, date)

    # Compute averages
    avg_7 = count_7 / 7
    avg_30 = count_30 / 30

    attrs = %{
      user_id: user_id,
      stat_date: date,
      daily_inquiry_count: daily_count,
      avg_7_day: avg_7,
      avg_30_day: avg_30
    }

    %PopularityStat{}
    |> PopularityStat.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:daily_inquiry_count, :avg_7_day, :avg_30_day, :updated_at]},
      conflict_target: [:user_id, :stat_date]
    )
  end

  # --- Batch Aggregation ---

  @doc """
  Aggregates daily inquiry counts for all users who received inquiries on the given date.

  This is typically called by the nightly background worker to update stats
  for the previous day.

  Returns `{:ok, count}` where count is the number of users processed.
  """
  def aggregate_daily_counts(date) do
    # Find all users who received inquiries on this date
    user_ids =
      Inquiry
      |> where([i], i.inquiry_date == ^date)
      |> distinct([i], i.receiver_id)
      |> select([i], i.receiver_id)
      |> Repo.all()

    # Compute and store stats for each user
    Enum.each(user_ids, fn user_id ->
      compute_rolling_averages(user_id, date)
    end)

    {:ok, length(user_ids)}
  end

  @doc """
  Cleans up old popularity stats to keep the table size manageable.

  Deletes stats older than the specified number of days (default: 60).
  """
  def cleanup_old_stats(days_to_keep \\ 60) do
    cutoff = Date.add(Date.utc_today(), -days_to_keep)

    {count, _} =
      PopularityStat
      |> where([s], s.stat_date < ^cutoff)
      |> Repo.delete_all()

    {:ok, count}
  end
end
