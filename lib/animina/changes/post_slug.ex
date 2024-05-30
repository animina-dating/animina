defmodule Animina.Changes.PostSlug do
  use Ash.Resource.Change

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
        cond do
          title == nil ->
            changeset

          true ->
            # slugify post title, replaces special characters with '-'
            title_slug =
              String.replace(title, ~r/(?:'s)?[^\p{L}\-\d_]+|\.+$/u, "-") |> String.downcase()

            Ash.Changeset.force_change_attribute(changeset, :slug, title_slug)
        end

      :error ->
        changeset
    end
  end
end
