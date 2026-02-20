defmodule Animina.Analytics.DailyPageStatTest do
  use Animina.DataCase, async: true

  alias Animina.Analytics.DailyPageStat

  describe "changeset/2" do
    test "valid changeset" do
      changeset =
        DailyPageStat.changeset(%DailyPageStat{}, %{
          date: ~D[2026-02-20],
          path: "/discover",
          view_count: 42,
          unique_sessions: 30,
          unique_users: 20
        })

      assert changeset.valid?
    end

    test "invalid without date" do
      changeset = DailyPageStat.changeset(%DailyPageStat{}, %{path: "/discover"})
      refute changeset.valid?
      assert %{date: _} = errors_on(changeset)
    end

    test "invalid without path" do
      changeset = DailyPageStat.changeset(%DailyPageStat{}, %{date: ~D[2026-02-20]})
      refute changeset.valid?
      assert %{path: _} = errors_on(changeset)
    end

    test "enforces unique date+path constraint" do
      attrs = %{date: ~D[2026-02-20], path: "/test", view_count: 1, unique_sessions: 1, unique_users: 1}

      assert {:ok, _} =
               %DailyPageStat{}
               |> DailyPageStat.changeset(attrs)
               |> Repo.insert()

      assert {:error, changeset} =
               %DailyPageStat{}
               |> DailyPageStat.changeset(attrs)
               |> Repo.insert()

      assert %{date: _} = errors_on(changeset)
    end
  end
end
