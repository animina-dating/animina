defmodule Animina.AdsTest do
  use Animina.DataCase, async: true

  alias Animina.Ads
  alias Animina.AdsFixtures

  describe "create_ad/1" do
    test "creates ad with auto-assigned number and hex URL" do
      {:ok, ad} = Ads.create_ad(%{description: "Magazine ad"})

      assert ad.number == 1
      assert ad.url == "https://animina.de?ad=1"
      assert ad.description == "Magazine ad"
    end

    test "auto-increments number" do
      {:ok, ad1} = Ads.create_ad(%{description: "First"})
      {:ok, ad2} = Ads.create_ad(%{description: "Second"})
      {:ok, ad3} = Ads.create_ad(%{description: "Third"})

      assert ad1.number == 1
      assert ad2.number == 2
      assert ad3.number == 3
    end

    test "generates hex URL" do
      # Create 10 ads to get to number 10 (hex "a")
      for _ <- 1..9, do: Ads.create_ad()
      {:ok, ad10} = Ads.create_ad(%{description: "Tenth"})

      assert ad10.number == 10
      assert ad10.url == "https://animina.de?ad=a"
    end

    test "accepts date range" do
      {:ok, ad} =
        Ads.create_ad(%{
          description: "Seasonal ad",
          starts_on: ~D[2026-06-01],
          ends_on: ~D[2026-08-31]
        })

      assert ad.starts_on == ~D[2026-06-01]
      assert ad.ends_on == ~D[2026-08-31]
    end
  end

  describe "get_ad_by_number/1" do
    test "returns ad for existing number" do
      ad = AdsFixtures.ad_fixture()
      found = Ads.get_ad_by_number(ad.number)
      assert found.id == ad.id
    end

    test "returns nil for non-existent number" do
      assert Ads.get_ad_by_number(999) == nil
    end
  end

  describe "update_ad/2" do
    test "updates description and dates" do
      ad = AdsFixtures.ad_fixture()

      {:ok, updated} =
        Ads.update_ad(ad, %{
          description: "Updated description",
          starts_on: ~D[2026-03-01],
          ends_on: ~D[2026-03-31]
        })

      assert updated.description == "Updated description"
      assert updated.starts_on == ~D[2026-03-01]
      assert updated.ends_on == ~D[2026-03-31]
    end

    test "rejects invalid date range" do
      ad = AdsFixtures.ad_fixture()

      {:error, changeset} =
        Ads.update_ad(ad, %{starts_on: ~D[2026-12-31], ends_on: ~D[2026-01-01]})

      assert "must be on or before end date" in errors_on(changeset).starts_on
    end
  end

  describe "list_ads/1" do
    test "returns paginated ads ordered by number descending" do
      ad1 = AdsFixtures.ad_fixture()
      ad2 = AdsFixtures.ad_fixture()

      result = Ads.list_ads(page: 1, per_page: 10)
      assert length(result.entries) == 2
      assert hd(result.entries).id == ad2.id
      assert List.last(result.entries).id == ad1.id
    end
  end

  describe "log_visit/2" do
    test "creates visit for active ad" do
      ad = AdsFixtures.ad_fixture()

      {:ok, visit} =
        Ads.log_visit(ad, %{
          ip_address: "1.2.3.4",
          user_agent: "Mozilla/5.0",
          os: "macOS",
          browser: "Chrome",
          device_type: "desktop",
          language: "de"
        })

      assert visit.ad_id == ad.id
      assert visit.ip_address == "1.2.3.4"
      assert visit.visited_at != nil
    end

    test "rejects visit for inactive ad" do
      ad =
        AdsFixtures.ad_fixture(%{
          starts_on: ~D[2020-01-01],
          ends_on: ~D[2020-01-31]
        })

      assert {:error, :inactive} = Ads.log_visit(ad, %{ip_address: "1.2.3.4"})
    end
  end

  describe "count_visits/1" do
    test "counts non-bot visits by default" do
      ad = AdsFixtures.ad_fixture()
      AdsFixtures.ad_visit_fixture(ad, %{is_bot: false})
      AdsFixtures.ad_visit_fixture(ad, %{is_bot: false})
      AdsFixtures.ad_visit_fixture(ad, %{is_bot: true})

      assert Ads.count_visits(ad.id) == 2
    end

    test "counts all visits when exclude_bots is false" do
      ad = AdsFixtures.ad_fixture()
      AdsFixtures.ad_visit_fixture(ad, %{is_bot: false})
      AdsFixtures.ad_visit_fixture(ad, %{is_bot: true})

      assert Ads.count_visits(ad.id, exclude_bots: false) == 2
    end
  end

  describe "daily_visit_counts/1" do
    test "groups visits by date" do
      ad = AdsFixtures.ad_fixture()
      AdsFixtures.ad_visit_fixture(ad)
      AdsFixtures.ad_visit_fixture(ad)

      counts = Ads.daily_visit_counts(ad.id)
      assert counts != []
      {_date, count} = hd(counts)
      assert count == 2
    end
  end

  describe "record_conversion/2 and count_conversions/1" do
    test "records and counts conversions" do
      ad = AdsFixtures.ad_fixture()
      user = Animina.AccountsFixtures.user_fixture()

      {:ok, conversion} = Ads.record_conversion(ad.id, user.id)
      assert conversion.ad_id == ad.id
      assert conversion.user_id == user.id

      assert Ads.count_conversions(ad.id) == 1
    end

    test "prevents duplicate conversions for same ad+user" do
      ad = AdsFixtures.ad_fixture()
      user = Animina.AccountsFixtures.user_fixture()

      {:ok, _} = Ads.record_conversion(ad.id, user.id)
      {:error, _} = Ads.record_conversion(ad.id, user.id)

      assert Ads.count_conversions(ad.id) == 1
    end
  end

  describe "conversion_rate/1" do
    test "calculates percentage" do
      ad = AdsFixtures.ad_fixture()
      AdsFixtures.ad_visit_fixture(ad)
      AdsFixtures.ad_visit_fixture(ad)

      user = Animina.AccountsFixtures.user_fixture()
      Ads.record_conversion(ad.id, user.id)

      rate = Ads.conversion_rate(ad.id)
      assert rate == 50.0
    end

    test "returns 0.0 when no visits" do
      ad = AdsFixtures.ad_fixture()
      assert Ads.conversion_rate(ad.id) == 0.0
    end
  end
end
