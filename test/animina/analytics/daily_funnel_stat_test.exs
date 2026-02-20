defmodule Animina.Analytics.DailyFunnelStatTest do
  use Animina.DataCase, async: true

  alias Animina.Analytics.DailyFunnelStat

  describe "changeset/2" do
    test "valid changeset" do
      changeset =
        DailyFunnelStat.changeset(%DailyFunnelStat{}, %{
          date: ~D[2026-02-20],
          visitors: 100,
          registered: 20,
          profile_completed: 10,
          first_message: 5,
          mutual_match: 2
        })

      assert changeset.valid?
    end

    test "invalid without date" do
      changeset = DailyFunnelStat.changeset(%DailyFunnelStat{}, %{visitors: 100})
      refute changeset.valid?
      assert %{date: _} = errors_on(changeset)
    end

    test "enforces unique date constraint" do
      attrs = %{date: ~D[2026-02-20], visitors: 100}

      assert {:ok, _} =
               %DailyFunnelStat{}
               |> DailyFunnelStat.changeset(attrs)
               |> Repo.insert()

      assert {:error, changeset} =
               %DailyFunnelStat{}
               |> DailyFunnelStat.changeset(attrs)
               |> Repo.insert()

      assert %{date: _} = errors_on(changeset)
    end
  end
end
