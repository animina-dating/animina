defmodule Animina.Traits do
  @moduledoc """
  This is the Traits module.
  """

  use Ash.Domain

  resources do
    resource Animina.Traits.Category
    resource Animina.Traits.CategoryTranslation
    resource Animina.Traits.Flag
    resource Animina.Traits.FlagTranslation
    resource Animina.Traits.UserFlags
  end
  authorization do
    authorize :when_requested
  end
end
