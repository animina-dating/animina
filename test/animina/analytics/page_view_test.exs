defmodule Animina.Analytics.PageViewTest do
  use Animina.DataCase, async: true

  alias Animina.Analytics.PageView

  describe "changeset/2" do
    test "valid changeset with required fields" do
      changeset =
        PageView.changeset(%PageView{}, %{
          session_id: Ecto.UUID.generate(),
          path: "/discover"
        })

      assert changeset.valid?
    end

    test "valid changeset with all fields" do
      changeset =
        PageView.changeset(%PageView{}, %{
          session_id: Ecto.UUID.generate(),
          path: "/discover",
          referrer_path: "/",
          user_id: Ecto.UUID.generate()
        })

      assert changeset.valid?
    end

    test "invalid without session_id" do
      changeset = PageView.changeset(%PageView{}, %{path: "/discover"})
      refute changeset.valid?
      assert %{session_id: _} = errors_on(changeset)
    end

    test "invalid without path" do
      changeset = PageView.changeset(%PageView{}, %{session_id: Ecto.UUID.generate()})
      refute changeset.valid?
      assert %{path: _} = errors_on(changeset)
    end

    test "sets inserted_at automatically" do
      changeset =
        PageView.changeset(%PageView{}, %{
          session_id: Ecto.UUID.generate(),
          path: "/discover"
        })

      assert Ecto.Changeset.get_field(changeset, :inserted_at) != nil
    end
  end
end
