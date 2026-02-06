defmodule Animina.Discovery.Behaviours.Filter do
  @moduledoc """
  Behaviour for filter strategies used in partner discovery.

  Implementations receive an Ecto query and the viewer user, then apply
  various filters to narrow down candidate users.
  """

  @doc """
  Applies all configured filters to the query.

  Options:
  - `:list_type` - The type of list being generated ("combined", "safe", "attracted")
  - `:exclude_soft_red` - If true, exclude candidates with soft-red matches (for Safe list)

  Returns a filtered query containing only valid candidates.
  """
  @callback filter_candidates(
              query :: Ecto.Query.t(),
              viewer :: map(),
              opts :: keyword()
            ) :: Ecto.Query.t()
end
