defmodule Animina.AdsFixtures do
  @moduledoc """
  Test helpers for creating ad campaign entities.
  """

  alias Animina.Ads

  @doc """
  Creates an ad with optional overrides.
  """
  def ad_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        description: "Test ad campaign"
      })

    {:ok, ad} = Ads.create_ad(attrs)
    ad
  end

  @doc """
  Creates an ad visit for the given ad.
  """
  def ad_visit_fixture(%Ads.Ad{} = ad, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        ip_address: "192.168.1.#{:rand.uniform(255)}",
        user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
        referer: "https://example.com",
        os: "macOS",
        browser: "Safari",
        device_type: "desktop",
        language: "de",
        is_bot: false
      })

    {:ok, visit} = Ads.log_visit(ad, attrs)
    visit
  end
end
