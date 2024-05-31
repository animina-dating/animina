defmodule Animina.Changes.PostSlug do
  use Ash.Resource.Change

  alias Animina.Narratives.Post

  @moduledoc """
  This is a module for creating a slug from a post's title
  """

  @impl true
  def init(opts) do
    case is_atom(opts[:attribute]) do
      true -> {:ok, opts}
      _ -> {:error, "attribute must be an atom!"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    case Ash.Changeset.fetch_change(changeset, opts[:attribute]) do
      {:ok, title} ->
        if title != nil do
          # slugify post title, replaces special characters with '-'
          title_slug =
            String.replace(title, ~r/(?:'s)?[^\p{L}\-\d_]+|\.+$/u, "-") |> String.downcase()

          if Post.by_slug!(title_slug, not_found_error?: false) == nil do
            Ash.Changeset.force_change_attribute(changeset, :slug, title_slug)
          else
            Ash.Changeset.add_error(changeset, field: :title, message: "Already exists")
          end
        else
          changeset
        end

      :error ->
        changeset
    end
  end
end
