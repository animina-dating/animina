defmodule Animina.MailQueueChecker.Parser do
  @moduledoc """
  Parses Postfix `mailq` output into structured entries.
  """

  # Match deferred (no marker) and held (!) entries, but NOT active (*) entries.
  # Active entries are still being delivered and should not be treated as failures.
  @queue_id_regex ~r/^([A-Za-z0-9]+)!?\s+\d+\s+(\w{3}\s+\w{3}\s+\d+\s+\d+:\d+:\d+)\s+\S+/

  @doc """
  Parses mailq output and returns a list of maps with
  `:queue_id`, `:recipient`, `:reason`, and `:arrived_at`.
  """
  def parse(nil), do: []
  def parse(""), do: []

  def parse(output) do
    output
    |> String.split("\n")
    |> parse_lines([])
    |> Enum.reverse()
  end

  defp parse_lines([], acc), do: acc

  defp parse_lines([line | rest], acc) do
    case Regex.run(@queue_id_regex, line) do
      [_, queue_id, arrived_at] ->
        {reason_lines, rest} = collect_reason(rest, [])
        {recipient, rest} = find_recipient(rest)

        entry = %{
          queue_id: queue_id,
          recipient: recipient && String.downcase(String.trim(recipient)),
          reason: reason_lines |> Enum.join(" ") |> String.trim(),
          arrived_at: arrived_at
        }

        parse_lines(rest, [entry | acc])

      nil ->
        parse_lines(rest, acc)
    end
  end

  defp collect_reason([], acc), do: {Enum.reverse(acc), []}

  defp collect_reason([line | rest] = lines, acc) do
    trimmed = String.trim(line)

    cond do
      # Start of reason line: (reason text...)
      String.starts_with?(trimmed, "(") ->
        # Might be single-line: (reason)  or multi-line: (reason\n  continued)
        collect_reason_continuation(rest, [extract_reason_text(trimmed) | acc])

      # Continuation of reason (indented, not starting with parenthesis)
      acc != [] && trimmed != "" && !String.contains?(trimmed, "@") ->
        collect_reason(rest, [extract_reason_text(trimmed) | acc])

      true ->
        {Enum.reverse(acc), lines}
    end
  end

  defp collect_reason_continuation([], acc), do: {Enum.reverse(acc), []}

  defp collect_reason_continuation([line | rest] = lines, acc) do
    trimmed = String.trim(line)

    # Continuation lines of a reason are indented and don't contain @ (not a recipient)
    if trimmed != "" && !String.contains?(trimmed, "@") && !Regex.match?(@queue_id_regex, line) do
      collect_reason_continuation(rest, [extract_reason_text(trimmed) | acc])
    else
      {Enum.reverse(acc), lines}
    end
  end

  defp extract_reason_text(text) do
    text
    |> String.trim_leading("(")
    |> String.trim_trailing(")")
    |> String.trim()
  end

  defp find_recipient([]), do: {nil, []}

  defp find_recipient([line | rest] = lines) do
    trimmed = String.trim(line)

    cond do
      # Stop if we hit another queue entry or summary line
      Regex.match?(@queue_id_regex, line) ->
        {nil, lines}

      String.starts_with?(trimmed, "--") ->
        {nil, lines}

      # Recipient line: contains @ and is not a reason line
      String.contains?(trimmed, "@") && !String.starts_with?(trimmed, "(") ->
        {trimmed, rest}

      true ->
        find_recipient(rest)
    end
  end
end
