defmodule Animina.Repo.Paginator do
  @moduledoc """
  Shared pagination helper for Ecto queries.

  Provides a `paginate/2` function that takes an already-filtered and
  ordered query, applies offset/limit, counts total results, and returns
  a standardized result map.

  ## Usage

      import Animina.Repo.Paginator

      query
      |> where(...)
      |> order_by(...)
      |> paginate(page: page, per_page: per_page)
  """

  import Ecto.Query

  alias Animina.Repo

  @doc """
  Paginates an Ecto query and returns a result map.

  ## Options

    * `:page` - page number (default: 1, minimum: 1)
    * `:per_page` - items per page (default: 50, clamped to 1..max_per_page)
    * `:max_per_page` - upper bound for per_page (default: 500)
    * `:preload` - associations to preload on the paginated results (default: [])

  ## Returns

      %{
        entries: [%Schema{}, ...],
        page: integer,
        per_page: integer,
        total_count: integer,
        total_pages: integer
      }
  """
  def paginate(query, opts \\ []) do
    page = (Keyword.get(opts, :page) || 1) |> max(1)
    max_per_page = Keyword.get(opts, :max_per_page, 500)
    per_page = (Keyword.get(opts, :per_page) || 50) |> max(1) |> min(max_per_page)
    preloads = Keyword.get(opts, :preload, [])

    total_count = Repo.aggregate(query, :count)
    total_pages = max(1, ceil(total_count / per_page))

    entries =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()
      |> then(fn results ->
        if preloads == [], do: results, else: Repo.preload(results, preloads)
      end)

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end
end
