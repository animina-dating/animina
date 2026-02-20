defmodule Animina.AI.PerformanceStats do
  @moduledoc """
  Queries historical AI job data to compute performance statistics
  used for intelligent GPU vs CPU routing decisions.

  All queries use a 24-hour lookback window so stats reflect current
  conditions rather than stale data from model/hardware changes.
  """

  import Ecto.Query

  alias Animina.AI.Client
  alias Animina.AI.Job
  alias Animina.Repo

  @lookback_hours 24

  @doc """
  Returns average duration (ms) for completed jobs of `job_type`
  on instances tagged with `tag`. Returns nil if no data.
  """
  @spec avg_duration_ms(String.t(), String.t()) :: non_neg_integer() | nil
  def avg_duration_ms(tag, job_type) do
    urls = urls_for_tag(tag)
    if urls == [], do: nil, else: query_avg(urls, job_type)
  end

  @doc """
  Returns average duration (ms) across all completed jobs
  on instances tagged with `tag`. Used to estimate how long
  the currently-running GPU job will take overall.
  Returns nil if no data.
  """
  @spec avg_duration_ms_all(String.t()) :: non_neg_integer() | nil
  def avg_duration_ms_all(tag) do
    urls = urls_for_tag(tag)
    if urls == [], do: nil, else: query_avg_all(urls)
  end

  @doc """
  Returns elapsed time (ms) since the oldest currently-running job
  was marked as running. Returns nil if no jobs are running.
  """
  @spec oldest_running_elapsed_ms() :: non_neg_integer() | nil
  def oldest_running_elapsed_ms do
    Job
    |> where([j], j.status == "running")
    |> order_by([j], asc: j.updated_at)
    |> limit(1)
    |> select([j], j.updated_at)
    |> Repo.one()
    |> case do
      nil -> nil
      started_at -> DateTime.diff(DateTime.utc_now(), started_at, :millisecond)
    end
  end

  @doc """
  Returns true if the number of currently running jobs is at least
  as many as the number of GPU instances (i.e., all GPUs are likely busy).
  """
  @spec gpu_busy?() :: boolean()
  def gpu_busy? do
    gpu_count = length(urls_for_tag("gpu"))

    if gpu_count == 0 do
      false
    else
      running_count = Repo.aggregate(where(Job, [j], j.status == "running"), :count)
      running_count >= gpu_count
    end
  end

  # --- Private ---

  defp query_avg(urls, job_type) do
    since = DateTime.utc_now() |> DateTime.add(-@lookback_hours, :hour)

    Job
    |> where([j], j.status == "completed" and j.job_type == ^job_type)
    |> where([j], j.server_url in ^urls)
    |> where([j], not is_nil(j.duration_ms) and j.duration_ms > 0)
    |> where([j], j.updated_at >= ^since)
    |> select([j], fragment("CAST(AVG(?) AS BIGINT)", j.duration_ms))
    |> Repo.one()
  end

  defp query_avg_all(urls) do
    since = DateTime.utc_now() |> DateTime.add(-@lookback_hours, :hour)

    Job
    |> where([j], j.status == "completed")
    |> where([j], j.server_url in ^urls)
    |> where([j], not is_nil(j.duration_ms) and j.duration_ms > 0)
    |> where([j], j.updated_at >= ^since)
    |> select([j], fragment("CAST(AVG(?) AS BIGINT)", j.duration_ms))
    |> Repo.one()
  end

  defp urls_for_tag(tag) do
    Client.ollama_instances()
    |> Enum.filter(fn inst -> tag in Map.get(inst, :tags, []) end)
    |> Enum.map(& &1.url)
  end
end
