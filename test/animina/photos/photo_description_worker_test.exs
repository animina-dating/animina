defmodule Animina.Photos.PhotoDescriptionWorkerTest do
  use Animina.DataCase, async: true

  alias Animina.Photos
  alias Animina.Photos.Photo

  import Animina.PhotosFixtures

  describe "list_photos_needing_description/1" do
    test "returns approved photos without descriptions" do
      photo = approved_photo_fixture()
      results = Photos.list_photos_needing_description()
      assert Enum.any?(results, &(&1.id == photo.id))
    end

    test "excludes photos that already have descriptions" do
      photo = approved_photo_fixture()

      {:ok, _} =
        Photos.update_photo_description(photo, %{
          description: "A test description",
          description_generated_at: DateTime.utc_now(:second),
          description_model: "test-model"
        })

      results = Photos.list_photos_needing_description()
      refute Enum.any?(results, &(&1.id == photo.id))
    end

    test "excludes non-approved photos" do
      _pending = photo_fixture(%{state: "pending"})
      _error = error_photo_fixture()

      results = Photos.list_photos_needing_description()
      assert results == [] || Enum.all?(results, &(&1.state == "approved"))
    end

    test "respects the limit parameter" do
      for _ <- 1..5, do: approved_photo_fixture()
      results = Photos.list_photos_needing_description(2)
      assert length(results) <= 2
    end

    test "returns oldest photos first" do
      photo1 = approved_photo_fixture()
      photo2 = approved_photo_fixture()

      results = Photos.list_photos_needing_description()
      ids = Enum.map(results, & &1.id)

      idx1 = Enum.find_index(ids, &(&1 == photo1.id))
      idx2 = Enum.find_index(ids, &(&1 == photo2.id))
      assert idx1 < idx2
    end
  end

  describe "update_photo_description/2" do
    test "saves description fields correctly" do
      photo = approved_photo_fixture()
      now = DateTime.utc_now(:second)

      assert {:ok, updated} =
               Photos.update_photo_description(photo, %{
                 description: "Eine Person lächelt freundlich.",
                 description_generated_at: now,
                 description_model: "qwen3-vl:8b"
               })

      assert updated.description == "Eine Person lächelt freundlich."
      assert updated.description_generated_at == now
      assert updated.description_model == "qwen3-vl:8b"
    end

    test "requires all description fields" do
      photo = approved_photo_fixture()

      assert {:error, changeset} =
               Photos.update_photo_description(photo, %{description: "Only description"})

      assert errors_on(changeset)[:description_generated_at]
      assert errors_on(changeset)[:description_model]
    end
  end

  describe "description_changeset/2" do
    test "validates max length of 2028 characters" do
      photo = approved_photo_fixture()
      long_text = String.duplicate("a", 2029)

      changeset =
        Photo.description_changeset(photo, %{
          description: long_text,
          description_generated_at: DateTime.utc_now(:second),
          description_model: "test-model"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:description]
    end

    test "accepts exactly 2028 characters" do
      photo = approved_photo_fixture()
      exact_text = String.duplicate("a", 2028)

      changeset =
        Photo.description_changeset(photo, %{
          description: exact_text,
          description_generated_at: DateTime.utc_now(:second),
          description_model: "test-model"
        })

      assert changeset.valid?
    end
  end

  describe "count_photos_needing_description/0" do
    test "counts approved photos without descriptions" do
      initial_count = Photos.count_photos_needing_description()

      approved_photo_fixture()
      approved_photo_fixture()

      assert Photos.count_photos_needing_description() == initial_count + 2
    end

    test "does not count photos with descriptions" do
      photo = approved_photo_fixture()
      initial_count = Photos.count_photos_needing_description()

      {:ok, _} =
        Photos.update_photo_description(photo, %{
          description: "A description",
          description_generated_at: DateTime.utc_now(:second),
          description_model: "test-model"
        })

      assert Photos.count_photos_needing_description() == initial_count - 1
    end
  end
end
