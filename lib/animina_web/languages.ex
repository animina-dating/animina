defmodule AniminaWeb.Languages do
  @moduledoc """
  Canonical list of supported languages used across the application.
  Each entry is a 4-tuple: `{code, abbreviation, flag_emoji, native_name}`.
  """

  @languages [
    {"de", "DE", "🇩🇪", "Deutsch"},
    {"en", "EN", "🇬🇧", "English"},
    {"tr", "TR", "🇹🇷", "Türkçe"},
    {"ru", "RU", "🇷🇺", "Русский"},
    {"ar", "AR", "🇸🇦", "العربية"},
    {"pl", "PL", "🇵🇱", "Polski"},
    {"fr", "FR", "🇫🇷", "Français"},
    {"es", "ES", "🇪🇸", "Español"},
    {"uk", "UK", "🇺🇦", "Українська"}
  ]

  @doc """
  Returns the full list of supported languages as 4-tuples.
  """
  def all, do: @languages

  @doc """
  Returns a list of all supported language codes.
  """
  def codes, do: Enum.map(@languages, &elem(&1, 0))

  @doc """
  Returns the display name for a locale code (e.g. "🇩🇪 Deutsch").
  Falls back to the code itself if not found.
  """
  def display_name(code) do
    case Enum.find(@languages, fn {c, _, _, _} -> c == code end) do
      {_, _, flag, name} -> "#{flag} #{name}"
      nil -> code
    end
  end
end
