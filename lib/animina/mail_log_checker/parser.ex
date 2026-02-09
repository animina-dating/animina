defmodule Animina.MailLogChecker.Parser do
  @moduledoc """
  Parses Postfix `/var/log/mail.log` for bounce entries (status=bounced).
  """

  @bounce_regex ~r/postfix\/smtp\[\d+\]:\s+([A-F0-9]+):\s+to=<([^>]+)>,.*status=bounced\s+\((.+)\)$/

  @doc """
  Parses mail.log content and returns a list of bounce entries.

  Each entry is a map with `:queue_id`, `:recipient`, `:reason`, and `:timestamp`.
  """
  def parse(nil), do: []
  def parse(""), do: []

  def parse(content) do
    content
    |> String.split("\n")
    |> Enum.reduce([], fn line, acc ->
      case Regex.run(@bounce_regex, line) do
        [_, queue_id, recipient, reason] ->
          timestamp = extract_timestamp(line)

          entry = %{
            queue_id: queue_id,
            recipient: String.downcase(recipient),
            reason: reason,
            timestamp: timestamp
          }

          [entry | acc]

        nil ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp extract_timestamp(line) do
    case Regex.run(~r/^(\w{3}\s+\d+\s+\d+:\d+:\d+)/, line) do
      [_, timestamp] -> timestamp
      nil -> nil
    end
  end
end
