defmodule Animina.Calculations.VisitLogEntriesCount do
  @moduledoc """
  This is a module for getting the count of visit log entries for a bookmark.
  """

  use Ash.Calculation
  alias Animina.Accounts.VisitLogEntry

  def calculate(records, opts, _) do
    Enum.map(records, fn record -> get_visit_log_entries_count(Map.get(record, opts[:field])) end)
  end

  defp get_visit_log_entries_count(bookmark_id) do
    Enum.count(VisitLogEntry.by_bookmark_id!(bookmark_id))
  end
end
