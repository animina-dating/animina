defmodule Animina.Narratives do
  @moduledoc """
  This is the narratives module.
  """

  use Ash.Domain

  resources do
    resource Animina.Narratives.Headline
    resource Animina.Narratives.Story
    resource Animina.Narratives.Post
  end
  authorization do
    authorize :when_requested
  end
end
