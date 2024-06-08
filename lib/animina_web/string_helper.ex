defmodule Animina.StringHelper do
  alias Animina.Markdown
  @moduledoc """
  String helper functions.
  """

  @doc """
  Slices the string at the specified length, ensuring it ends at a word boundary.
  Optionally appends "..." if the string was truncated.
  The Elipses are wrapped in an anchor tag with the link to the user profile.

  ## Examples

      iex> Animina.StringHelper.slice_at_word_boundary("This is a long string that should be sliced properly.", 30)
      "This is a long string that"

      iex> Animina.StringHelper.slice_at_word_boundary("This is a long string that should be sliced properly.", 30, true)
      "This is a long string that ..."

  """
  def slice_at_word_boundary(str, max_length, profile_username ,  add_ellipsis \\ false) do
    if String.length(str) <= max_length do
      str
    else
      sliced_str =
        str
        |> String.slice(0, max_length)
        |> ensure_word_boundary()

      if add_ellipsis do
        sliced_str <> "<a href=#{"/#{profile_username}"}>[...]</a>"
      else
        sliced_str
      end
    end
  end

  defp ensure_word_boundary(sliced_str) do
    words = String.split(sliced_str, ~r/\s+/)

    words
    |> Enum.drop(-1)
    |> Enum.join(" ")
  end

  def add_link_to_hashtags(link) do
    Markdown.format("<a href=#{link}>#{link}</a>")
  end
end
