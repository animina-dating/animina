defmodule Animina.Wingman.PromptTemplate do
  @moduledoc """
  Renders per-language wingman prompt templates from EEx files in priv/ai_prompts/wingman/.

  Each template is a complete LLM prompt that can be read top-to-bottom in a single file.
  """

  @supported_locales ~w(de en)

  defp templates_dir do
    Application.app_dir(:animina, "priv/ai_prompts/wingman")
  end

  @doc """
  Renders the wingman prompt for the given locale with the provided assigns map.

  Falls back to `"de"` if the locale is not supported.
  """
  def render(locale, assigns) when is_map(assigns) do
    locale = if locale in @supported_locales, do: locale, else: "de"
    path = Path.join(templates_dir(), "#{locale}.eex")
    EEx.eval_file(path, assigns: assigns) |> String.trim()
  end
end
