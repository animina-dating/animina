defmodule Animina.Calculations.VisitLogEntriesTotalDuration do
  @moduledoc """
  This is a module for getting the total duration of visit log entries for a bookmark.
  """

  use Ash.Calculation
  alias Animina.Accounts.VisitLogEntry

  def calculate(records, opts, _) do
    Enum.map(records, fn record ->
      get_visit_log_entries_total_duration(Map.get(record, opts[:field]))
    end)
  end

  defp get_visit_log_entries_total_duration(bookmark_id) do
    VisitLogEntry.by_bookmark_id!(bookmark_id)
    |> Enum.map(& &1.duration)
    |> Enum.sum()
  end
end
