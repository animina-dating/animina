defmodule Animina.Ads.AdVisitTest do
  use Animina.DataCase, async: true

  alias Animina.Ads.AdVisit

  describe "changeset/2" do
    test "valid with required fields" do
      changeset =
        AdVisit.changeset(%AdVisit{}, %{
          ad_id: Ecto.UUID.generate(),
          visited_at: DateTime.utc_now(:second)
        })

      assert changeset.valid?
    end

    test "requires ad_id and visited_at" do
      changeset = AdVisit.changeset(%AdVisit{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).ad_id
      assert "can't be blank" in errors_on(changeset).visited_at
    end

    test "truncates long user_agent to 500 chars" do
      long_ua = String.duplicate("x", 600)

      changeset =
        AdVisit.changeset(%AdVisit{}, %{
          ad_id: Ecto.UUID.generate(),
          visited_at: DateTime.utc_now(:second),
          user_agent: long_ua
        })

      assert String.length(Ecto.Changeset.get_change(changeset, :user_agent)) == 500
    end

    test "truncates long referer to 500 chars" do
      long_referer = String.duplicate("y", 600)

      changeset =
        AdVisit.changeset(%AdVisit{}, %{
          ad_id: Ecto.UUID.generate(),
          visited_at: DateTime.utc_now(:second),
          referer: long_referer
        })

      assert String.length(Ecto.Changeset.get_change(changeset, :referer)) == 500
    end
  end
end
