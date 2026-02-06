defmodule Animina.Discovery.Behaviours.Scorer do
  @moduledoc """
  Behaviour for scoring algorithms used in partner discovery.

  Implementations receive the viewer, a candidate user, and their computed
  flag overlap, then return a numeric score. Higher scores indicate better matches.
  """

  alias Animina.Accounts.User

  @doc """
  Computes the combined score for a candidate.

  This score balances red flag penalties (weighted higher) with green flag bonuses.
  Used for the "Combined" list.
  """
  @callback compute_combined_score(
              viewer :: User.t(),
              candidate :: User.t(),
              overlap :: map()
            ) :: integer()

  @doc """
  Computes the safe score for a candidate.

  This score is used for candidates with no red flag matches at all.
  Used for the "Safe" list.
  """
  @callback compute_safe_score(
              viewer :: User.t(),
              candidate :: User.t(),
              overlap :: map()
            ) :: integer()

  @doc """
  Computes the attracted score for a candidate.

  This score prioritizes green flag matches (viewer's green matching candidate's white).
  Used for the "Attracted" list.
  """
  @callback compute_attracted_score(
              viewer :: User.t(),
              candidate :: User.t(),
              overlap :: map()
            ) :: integer()
end
