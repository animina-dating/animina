defmodule Animina.Traits do
  @moduledoc """
  This is the Traits module.
  """

  use Ash.Api

  resources do
    resource Animina.Traits.Category
    resource Animina.Traits.CategoryTranslation
    resource Animina.Traits.Flag
    resource Animina.Traits.FlagTranslation
    resource Animina.Traits.UserInterests
  end
end
