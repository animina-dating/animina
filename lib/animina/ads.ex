defmodule Animina.Ads do
  @moduledoc """
  Context for ad campaign tracking.

  Manages ads with trackable URLs, visit logging, and conversion attribution.
  """

  import Ecto.Query
  import Animina.Repo.Paginator

  alias Animina.Ads.Ad
  alias Animina.Ads.AdConversion
  alias Animina.Ads.AdVisit
  alias Animina.Repo
  alias Animina.TimeMachine

  @base_url "https://animina.de"

  # --- Ad CRUD ---

  @doc """
  Creates a new ad with an auto-assigned number and base36-encoded URL.
  """
  def create_ad(attrs \\ %{}) do
    next_number = next_ad_number()
    code = Integer.to_string(next_number, 36) |> String.downcase()
    url = "#{@base_url}?ad=#{code}"

    attrs =
      attrs
      |> Map.put(:number, next_number)
      |> Map.put(:url, url)

    %Ad{}
    |> Ad.changeset(attrs)
    |> Repo.insert()
  end

  defp next_ad_number do
    query = from(a in Ad, select: coalesce(max(a.number), 0))
    Repo.one(query) + 1
  end

  @doc """
  Gets an ad by ID. Returns nil if not found.
  """
  def get_ad(id), do: Repo.get(Ad, id)

  @doc """
  Gets an ad by ID. Raises if not found.
  """
  def get_ad!(id), do: Repo.get!(Ad, id)

  @doc """
  Gets an ad by its number. Returns nil if not found.
  """
  def get_ad_by_number(number) when is_integer(number) do
    Repo.get_by(Ad, number: number)
  end

  @doc """
  Updates an ad's description and date range.
  """
  def update_ad(%Ad{} = ad, attrs) do
    ad
    |> Ad.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists ads with pagination. Ordered by number descending (newest first).
  """
  def list_ads(opts \\ []) do
    Ad
    |> order_by(desc: :number)
    |> paginate(opts)
  end

  @doc """
  Updates the QR code path for an ad.
  """
  def update_qr_code_path(%Ad{} = ad, path) do
    ad
    |> Ecto.Changeset.change(qr_code_path: path)
    |> Repo.update()
  end

  # --- Visit logging ---

  @doc """
  Logs a visit to an ad. Only logs if the ad is currently active.
  Returns `{:ok, visit}` or `{:error, :inactive}`.
  """
  def log_visit(%Ad{} = ad, attrs) do
    if Ad.active?(ad) do
      attrs =
        attrs
        |> Map.put(:ad_id, ad.id)
        |> Map.put_new(:visited_at, TimeMachine.utc_now(:second))

      %AdVisit{}
      |> AdVisit.changeset(attrs)
      |> Repo.insert()
    else
      {:error, :inactive}
    end
  end

  @doc """
  Counts total visits for an ad (excluding bots by default).
  """
  def count_visits(ad_id, opts \\ []) do
    exclude_bots = Keyword.get(opts, :exclude_bots, true)

    query = from(v in AdVisit, where: v.ad_id == ^ad_id)

    query =
      if exclude_bots do
        from(v in query, where: v.is_bot == false)
      else
        query
      end

    Repo.aggregate(query, :count)
  end

  @doc """
  Returns daily visit counts for an ad as a list of `{date, count}` tuples.
  Excludes bots.
  """
  def daily_visit_counts(ad_id) do
    from(v in AdVisit,
      where: v.ad_id == ^ad_id and v.is_bot == false,
      group_by: fragment("DATE(?)", v.visited_at),
      order_by: [desc: fragment("DATE(?)", v.visited_at)],
      select: {fragment("DATE(?)", v.visited_at), count(v.id)}
    )
    |> Repo.all()
  end

  @doc """
  Lists visits for an ad with pagination.
  """
  def list_visits(ad_id, opts \\ []) do
    AdVisit
    |> where([v], v.ad_id == ^ad_id)
    |> order_by(desc: :visited_at)
    |> paginate(opts)
  end

  @doc """
  Returns device/OS/browser breakdown counts for an ad (excluding bots).
  """
  def visit_breakdown(ad_id, field) when field in [:os, :browser, :device_type] do
    from(v in AdVisit,
      where: v.ad_id == ^ad_id and v.is_bot == false,
      group_by: field(v, ^field),
      order_by: [desc: count(v.id)],
      select: {field(v, ^field), count(v.id)}
    )
    |> Repo.all()
  end

  # --- Conversions ---

  @doc """
  Records a conversion (registration) attributed to an ad.
  Returns `{:ok, conversion}` or `{:error, changeset}`.
  """
  def record_conversion(ad_id, user_id) do
    %AdConversion{}
    |> AdConversion.changeset(%{
      ad_id: ad_id,
      user_id: user_id,
      converted_at: TimeMachine.utc_now(:second)
    })
    |> Repo.insert()
  end

  @doc """
  Counts conversions for an ad (from durable ad_conversions table).
  """
  def count_conversions(ad_id) do
    from(c in AdConversion, where: c.ad_id == ^ad_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns the conversion rate for an ad (conversions / non-bot visits).
  Returns 0.0 if no visits.
  """
  def conversion_rate(ad_id) do
    visits = count_visits(ad_id)
    conversions = count_conversions(ad_id)

    if visits > 0 do
      Float.round(conversions / visits * 100, 1)
    else
      0.0
    end
  end

  @doc """
  Returns the total number of visits across all ads (excluding bots).
  """
  def total_visit_count do
    from(v in AdVisit, where: v.is_bot == false)
    |> Repo.aggregate(:count)
  end
end
