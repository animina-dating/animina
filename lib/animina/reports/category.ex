defmodule Animina.Reports.Category do
  @moduledoc """
  Single source of truth for report categories.

  Centralizes category keys, display labels (EN/DE), and priority levels.
  Used by filing, moderation, email notifications, and admin UI.
  """

  @categories [
    %{key: "harassment", en: "Harassment", de: "Belästigung", priority: "high"},
    %{
      key: "inappropriate_content",
      en: "Inappropriate content",
      de: "Unangemessene Inhalte",
      priority: "medium"
    },
    %{
      key: "fake_profile",
      en: "Fake / misleading profile",
      de: "Gefälschtes Profil",
      priority: "low"
    },
    %{key: "scam_spam", en: "Scam / spam", de: "Betrug / Spam", priority: "medium"},
    %{
      key: "underage_suspicion",
      en: "Underage suspicion",
      de: "Verdacht auf Minderjährigkeit",
      priority: "critical"
    },
    %{
      key: "threatening_behavior",
      en: "Threatening behavior",
      de: "Bedrohliches Verhalten",
      priority: "critical"
    },
    %{
      key: "serial_false_reporter",
      en: "Serial false reporting",
      de: "Serielle Falschmeldungen",
      priority: "medium"
    },
    %{key: "other", en: "Other", de: "Sonstiges", priority: "low"}
  ]

  @by_key Map.new(@categories, &{&1.key, &1})

  @doc "Returns all category keys (for schema validation)."
  def keys, do: Enum.map(@categories, & &1.key)

  @doc "Returns user-facing categories as `{key, label}` pairs (excludes system-only categories)."
  def user_options do
    @categories
    |> Enum.reject(&(&1.key == "serial_false_reporter"))
    |> Enum.map(&{&1.key, &1.en})
  end

  @doc "Returns the priority level for a category."
  def priority(category), do: Map.get(@by_key, category, %{priority: "low"}).priority

  @doc "Returns the localized display label for a category."
  def label(category, locale \\ "en")
  def label(category, "de"), do: Map.get(@by_key, category, %{de: category}).de
  def label(category, _), do: Map.get(@by_key, category, %{en: category}).en
end
