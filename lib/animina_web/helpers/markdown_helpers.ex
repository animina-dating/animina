defmodule AniminaWeb.Helpers.MarkdownHelpers do
  @moduledoc """
  Shared markdown rendering helpers.
  """

  import Phoenix.HTML, only: [raw: 1]

  @doc """
  Renders markdown safely for chat messages.

  Prefixes HTML-only lines with a zero-width space to prevent Earmark
  from treating them as raw HTML blocks (bypassing `escape: true`).
  """
  def render_message_markdown(content) do
    content
    |> String.split("\n")
    |> Enum.map_join("\n", fn line ->
      if Regex.match?(~r/^\s*</, line), do: "\u200B" <> line, else: line
    end)
    |> Earmark.as_html!(escape: true, smartypants: true, breaks: true)
    |> raw()
  end

  @doc """
  Renders markdown for moodboard stories with heading downgrade.

  Headings are reduced by one level (h1 -> h2, etc.) to maintain
  proper document structure within cards.
  """
  def render_story_markdown(nil), do: ""

  def render_story_markdown(content) do
    content
    |> Earmark.as_html!(escape: true, smartypants: true, breaks: true)
    |> downgrade_headings()
  end

  @doc """
  Strips markdown formatting for plain-text previews (e.g. conversation list).
  """
  def strip_markdown(content) do
    content
    |> String.replace(~r/[*_`~#\[\]()]/, "")
    |> String.replace(~r/\n+/, " ")
  end

  defp downgrade_headings(html) do
    html
    |> String.replace(~r/<(\/?)h5>/i, "<\\1h6>")
    |> String.replace(~r/<(\/?)h4>/i, "<\\1h5>")
    |> String.replace(~r/<(\/?)h3>/i, "<\\1h4>")
    |> String.replace(~r/<(\/?)h2>/i, "<\\1h3>")
    |> String.replace(~r/<(\/?)h1>/i, "<\\1h2>")
  end
end
