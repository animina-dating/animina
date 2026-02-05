defmodule AniminaWeb.PhotoStatus do
  @moduledoc """
  Shared photo status helpers for LiveComponents.

  Provides consistent status badge rendering across photo components.
  """

  use Gettext, backend: AniminaWeb.Gettext

  # States where the processed .webp file exists and can be served
  @servable_states ~w(approved ollama_checking pending_ollama needs_manual_review no_face_error error appeal_pending appeal_rejected)

  # States where AI analysis is actively in progress
  @analyzing_states ~w(ollama_checking pending_ollama)

  # States that indicate processing/uploading
  @processing_states ~w(pending processing)

  @doc """
  Returns true if the photo's processed .webp file can be served.
  """
  def servable?(photo), do: photo.state in @servable_states

  @doc """
  Returns true if the photo is currently being analyzed by AI.
  """
  def analyzing?(photo), do: photo.state in @analyzing_states

  @doc """
  Returns true if the photo is still being processed/uploaded.
  """
  def processing?(photo), do: photo.state in @processing_states

  @doc """
  Returns true if the photo is approved and ready for public display.
  """
  def approved?(photo), do: photo.state == "approved"

  @doc """
  Returns a status badge map for the given photo state.

  Returns nil for approved photos or unknown states.
  """
  def badge_for_state(state, error_message \\ nil)

  def badge_for_state("pending", _),
    do: %{type: :processing, text: gettext("Processing..."), spinner: true, icon: nil}

  def badge_for_state("processing", _),
    do: %{type: :processing, text: gettext("Processing..."), spinner: true, icon: nil}

  def badge_for_state("ollama_checking", _),
    do: %{type: :analyzing, text: gettext("Analyzing..."), spinner: true, icon: nil}

  def badge_for_state("pending_ollama", _),
    do: %{type: :analyzing, text: gettext("Analyzing..."), spinner: true, icon: nil}

  def badge_for_state("needs_manual_review", _),
    do: %{type: :info, text: gettext("Under review"), spinner: false, icon: "hero-clock"}

  def badge_for_state("no_face_error", error_message) do
    text = error_message || gettext("No face detected")
    %{type: :warning, text: text, spinner: false, icon: "hero-exclamation-triangle"}
  end

  def badge_for_state("error", error_message) do
    text = error_message || gettext("Photo rejected")
    %{type: :error, text: text, spinner: false, icon: "hero-x-circle"}
  end

  def badge_for_state("appeal_pending", _),
    do: %{type: :info, text: gettext("Appeal pending"), spinner: false, icon: "hero-clock"}

  def badge_for_state("appeal_rejected", _),
    do: %{type: :error, text: gettext("Appeal rejected"), spinner: false, icon: "hero-x-circle"}

  def badge_for_state(_, _), do: nil

  @doc """
  Returns the CSS class for a badge overlay based on badge type.
  """
  def badge_overlay_class(:analyzing), do: "bg-black/40"
  def badge_overlay_class(:error), do: "bg-error/60"
  def badge_overlay_class(:warning), do: "bg-warning/60"
  def badge_overlay_class(:info), do: "bg-info/60"
  def badge_overlay_class(_), do: "bg-black/40"
end
