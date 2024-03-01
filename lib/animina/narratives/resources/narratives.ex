defmodule Animina.Narratives do
  @moduledoc """
  This is the narratives module.
  """

  use Ash.Api

  resources do
    resource Animina.Narratives.Headline
  end
end
