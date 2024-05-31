defmodule Animina.Changes.PostSlug do
  use Ash.Resource.Change

  alias Animina.Calculations.PostUrl
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
  def change(changeset, opts, context) do
    case Ash.Changeset.fetch_change(changeset, opts[:attribute]) do
      {:ok, title} ->
        title_slug =
          String.replace(title, ~r/(?:'s)?[^\p{L}\-\d_]+|\.+$/u, "-") |> String.downcase()

        today = DateTime.utc_now()

        post =
          Post.by_slug_user_and_date!(title_slug, context[:actor].id, today,
            not_found_error?: false,
            load: [:user, :url]
          )

        cond do
          post == nil ->
            Ash.Changeset.force_change_attribute(changeset, :slug, title_slug)

          post.url == PostUrl.calculate_post_url(post) ->
            Ash.Changeset.add_error(changeset, field: :title, message: "Already exists")

          true ->
            Ash.Changeset.force_change_attribute(changeset, :slug, title_slug)
        end

      :error ->
        changeset
    end
  end
end
