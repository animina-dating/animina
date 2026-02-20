defmodule Animina.Ads.AdTest do
  use Animina.DataCase, async: true

  alias Animina.Ads.Ad

  describe "changeset/2" do
    test "valid with required fields" do
      changeset = Ad.changeset(%Ad{}, %{number: 1, url: "https://animina.de?ad=1"})
      assert changeset.valid?
    end

    test "requires number and url" do
      changeset = Ad.changeset(%Ad{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).number
      assert "can't be blank" in errors_on(changeset).url
    end

    test "valid with description and dates" do
      changeset =
        Ad.changeset(%Ad{}, %{
          number: 1,
          url: "https://animina.de?ad=1",
          description: "Test ad",
          starts_on: ~D[2026-01-01],
          ends_on: ~D[2026-12-31]
        })

      assert changeset.valid?
    end

    test "rejects starts_on after ends_on" do
      changeset =
        Ad.changeset(%Ad{}, %{
          number: 1,
          url: "https://animina.de?ad=1",
          starts_on: ~D[2026-12-31],
          ends_on: ~D[2026-01-01]
        })

      refute changeset.valid?
      assert "must be on or before end date" in errors_on(changeset).starts_on
    end
  end

  describe "active?/1" do
    test "always active when no dates set" do
      ad = %Ad{starts_on: nil, ends_on: nil}
      assert Ad.active?(ad)
    end

    test "active when today is within range" do
      today = Date.utc_today()

      ad = %Ad{
        starts_on: Date.add(today, -1),
        ends_on: Date.add(today, 1)
      }

      assert Ad.active?(ad)
    end

    test "active on start date" do
      today = Date.utc_today()
      ad = %Ad{starts_on: today, ends_on: Date.add(today, 5)}
      assert Ad.active?(ad)
    end

    test "active on end date" do
      today = Date.utc_today()
      ad = %Ad{starts_on: Date.add(today, -5), ends_on: today}
      assert Ad.active?(ad)
    end

    test "inactive when today is before start date" do
      today = Date.utc_today()
      ad = %Ad{starts_on: Date.add(today, 1), ends_on: Date.add(today, 10)}
      refute Ad.active?(ad)
    end

    test "inactive when today is after end date" do
      today = Date.utc_today()
      ad = %Ad{starts_on: Date.add(today, -10), ends_on: Date.add(today, -1)}
      refute Ad.active?(ad)
    end

    test "active when only starts_on set and today >= starts_on" do
      today = Date.utc_today()
      ad = %Ad{starts_on: Date.add(today, -1), ends_on: nil}
      assert Ad.active?(ad)
    end

    test "inactive when only starts_on set and today < starts_on" do
      today = Date.utc_today()
      ad = %Ad{starts_on: Date.add(today, 1), ends_on: nil}
      refute Ad.active?(ad)
    end

    test "active when only ends_on set and today <= ends_on" do
      today = Date.utc_today()
      ad = %Ad{starts_on: nil, ends_on: Date.add(today, 1)}
      assert Ad.active?(ad)
    end

    test "inactive when only ends_on set and today > ends_on" do
      today = Date.utc_today()
      ad = %Ad{starts_on: nil, ends_on: Date.add(today, -1)}
      refute Ad.active?(ad)
    end
  end

  describe "short_code/1" do
    test "returns base36 string for number" do
      assert Ad.short_code(%Ad{number: 1}) == "1"
      assert Ad.short_code(%Ad{number: 10}) == "a"
      assert Ad.short_code(%Ad{number: 35}) == "z"
      assert Ad.short_code(%Ad{number: 36}) == "10"
      assert Ad.short_code(%Ad{number: 255}) == "73"
    end
  end
end
