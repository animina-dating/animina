defmodule Animina.Utils.Pagination do
  @moduledoc """
  Shared pagination utilities for list queries.
  """

  import Ecto.Query

  @doc """
  Applies pagination to a query and returns a result map.

  ## Options

    * `:page` - Page number (default: 1, minimum: 1)
    * `:per_page` - Items per page (default: 50, minimum: 1, maximum: 250)

  ## Returns

  A map with:
    * `:entries` - List of items for the current page
    * `:page` - Current page number
    * `:per_page` - Items per page
    * `:total_count` - Total number of items
    * `:total_pages` - Total number of pages

  ## Examples

      query = from(p in Photo, where: p.state == "pending")
      paginate(Repo, query, page: 2, per_page: 25)
      # => %{entries: [...], page: 2, per_page: 25, total_count: 100, total_pages: 4}
  """
  def paginate(repo, query, opts \\ []) do
    page = Keyword.get(opts, :page, 1) |> max(1)
    per_page = Keyword.get(opts, :per_page, 50) |> max(1) |> min(250)

    total_count = repo.aggregate(query, :count)
    total_pages = max(1, ceil(total_count / per_page))

    entries =
      query
      |> offset(^((page - 1) * per_page))
      |> limit(^per_page)
      |> repo.all()

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  @doc """
  Normalizes pagination options, ensuring valid values.

  ## Options

    * `:page` - Page number (default: 1, minimum: 1)
    * `:per_page` - Items per page (default: 50, minimum: 1, maximum: 250)

  ## Returns

  A tuple `{page, per_page}` with normalized values.
  """
  def normalize_opts(opts \\ []) do
    page = Keyword.get(opts, :page, 1) |> max(1)
    per_page = Keyword.get(opts, :per_page, 50) |> max(1) |> min(250)
    {page, per_page}
  end

  @doc """
  Calculates pagination metadata from total count and per-page values.

  Returns `{offset, total_pages}`.
  """
  def calculate_metadata(page, per_page, total_count) do
    offset = (page - 1) * per_page
    total_pages = max(1, ceil(total_count / per_page))
    {offset, total_pages}
  end
end
