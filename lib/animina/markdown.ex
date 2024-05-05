defmodule Animina.Markdown do
  @moduledoc """
  This is the markdown module that converts markdown to html
  """
  def format(text) do
    MDEx.to_html(text,
      extension: [strikethrough: true, autolink: true],
      render: [unsafe_: true],
      features: [sanitize: true, syntax_highlight_theme: "github_light"]
    )
    |> HtmlSanitizeEx.basic_html()
    |> String.replace(~r/\<img.*>/, "")
    |> String.replace(~r/\<p/, "<p class='pt-2'")
    |> String.replace(~r/\<a/, "<a class='text-blue-800 underline decoration-blue-800'")
    |> String.replace(~r/\<ul/, "<ul class='p-2 pl-8 list-disc'")
    |> String.replace(~r/\<ol/, "<ol class='p-2 pl-8 list-disc'")
    |> String.replace(~r/\<h1/, "<h2 class='pt-4 text-xl font-bold'")
    |> String.replace(~r/\<h2/, "<h3 class='pt-4 text-base font-bold'")
    |> String.replace(~r/\<h3/, "<h4 class='pt-4 text-base font-bold'")
    |> String.replace(
      ~r/\<blockquote/,
      "<blockquote class='p-2 my-2 border-gray-300 border-s-4 bg-gray-50 dark:border-gray-500 dark:bg-gray-800'"
    )
    |> Phoenix.HTML.raw()
  end
end
