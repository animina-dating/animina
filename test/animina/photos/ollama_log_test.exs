defmodule Animina.Photos.OllamaLogTest do
  use Animina.DataCase, async: true

  alias Animina.Photos
  alias Animina.Photos.OllamaLog

  import Animina.AccountsFixtures
  import Animina.PhotosFixtures

  describe "OllamaLog.changeset/2" do
    test "valid with required fields" do
      changeset = OllamaLog.changeset(%OllamaLog{}, %{status: "success"})
      assert changeset.valid?
    end

    test "valid with all fields" do
      changeset =
        OllamaLog.changeset(%OllamaLog{}, %{
          status: "success",
          prompt: "Analyze this image",
          result: "APPROVED",
          duration_ms: 1500,
          model: "qwen3-vl:4b",
          server_url: "http://localhost:11434/api",
          photo_id: Ecto.UUID.generate(),
          owner_id: Ecto.UUID.generate(),
          requester_id: Ecto.UUID.generate()
        })

      assert changeset.valid?
    end

    test "invalid without status" do
      changeset = OllamaLog.changeset(%OllamaLog{}, %{})
      refute changeset.valid?
      assert %{status: ["can't be blank"]} = errors_on(changeset)
    end

    test "valid with in_progress status" do
      changeset = OllamaLog.changeset(%OllamaLog{}, %{status: "in_progress"})
      assert changeset.valid?
    end

    test "invalid with bad status value" do
      changeset = OllamaLog.changeset(%OllamaLog{}, %{status: "unknown"})
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "invalid with negative duration_ms" do
      changeset = OllamaLog.changeset(%OllamaLog{}, %{status: "success", duration_ms: -1})
      refute changeset.valid?
      assert %{duration_ms: _} = errors_on(changeset)
    end
  end

  describe "create_ollama_log/1" do
    test "creates a log entry with valid attrs" do
      assert {:ok, log} =
               Photos.create_ollama_log(%{
                 status: "success",
                 model: "qwen3-vl:4b",
                 duration_ms: 1200,
                 prompt: "Analyze this",
                 result: "APPROVED"
               })

      assert log.status == "success"
      assert log.model == "qwen3-vl:4b"
      assert log.duration_ms == 1200
    end

    test "creates a log entry with owner_id and requester_id" do
      owner = user_fixture()
      admin = user_fixture(%{display_name: "Admin"})

      assert {:ok, log} =
               Photos.create_ollama_log(%{
                 status: "success",
                 model: "qwen3-vl:4b",
                 duration_ms: 800,
                 owner_id: owner.id,
                 requester_id: admin.id
               })

      assert log.owner_id == owner.id
      assert log.requester_id == admin.id
    end

    test "creates a log entry with error status" do
      assert {:ok, log} =
               Photos.create_ollama_log(%{
                 status: "error",
                 model: "qwen3-vl:4b",
                 error: "connection refused"
               })

      assert log.status == "error"
      assert log.error == "connection refused"
    end

    test "creates a log entry with in_progress status" do
      assert {:ok, log} =
               Photos.create_ollama_log(%{
                 status: "in_progress",
                 model: "qwen3-vl:4b",
                 prompt: "Analyze this"
               })

      assert log.status == "in_progress"
      assert is_nil(log.result)
      assert is_nil(log.duration_ms)
    end
  end

  describe "update_ollama_log/2" do
    test "updates an in_progress entry to success" do
      {:ok, log} =
        Photos.create_ollama_log(%{
          status: "in_progress",
          model: "qwen3-vl:4b",
          prompt: "Analyze this"
        })

      assert {:ok, updated} =
               Photos.update_ollama_log(log, %{
                 status: "success",
                 result: "APPROVED",
                 duration_ms: 1500,
                 server_url: "http://localhost:11434/api"
               })

      assert updated.status == "success"
      assert updated.result == "APPROVED"
      assert updated.duration_ms == 1500
      assert updated.server_url == "http://localhost:11434/api"
    end

    test "updates an in_progress entry to error" do
      {:ok, log} =
        Photos.create_ollama_log(%{
          status: "in_progress",
          model: "qwen3-vl:4b",
          prompt: "Analyze this"
        })

      assert {:ok, updated} =
               Photos.update_ollama_log(log, %{
                 status: "error",
                 error: "connection refused",
                 duration_ms: 500
               })

      assert updated.status == "error"
      assert updated.error == "connection refused"
      assert updated.duration_ms == 500
    end
  end

  describe "cascade delete on photo deletion" do
    test "ollama log entries are deleted when the photo is deleted" do
      photo = photo_fixture()

      {:ok, log1} =
        Photos.create_ollama_log(%{
          status: "success",
          model: "qwen3-vl:4b",
          duration_ms: 1200,
          photo_id: photo.id
        })

      {:ok, log2} =
        Photos.create_ollama_log(%{
          status: "error",
          model: "qwen3-vl:8b",
          error: "timeout",
          photo_id: photo.id
        })

      # Verify logs exist
      assert Photos.get_ollama_log(log1.id)
      assert Photos.get_ollama_log(log2.id)

      # Delete the photo
      {:ok, _} = Photos.delete_photo(photo)

      # Logs should be gone
      assert is_nil(Photos.get_ollama_log(log1.id))
      assert is_nil(Photos.get_ollama_log(log2.id))
    end

    test "ollama logs without a photo_id are not affected by photo deletion" do
      photo = photo_fixture()

      {:ok, orphan_log} =
        Photos.create_ollama_log(%{
          status: "success",
          model: "qwen3-vl:4b",
          duration_ms: 500
        })

      {:ok, _} = Photos.delete_photo(photo)

      # Unrelated log should still exist
      assert Photos.get_ollama_log(orphan_log.id)
    end
  end

  describe "get_ollama_log/1" do
    test "returns log with preloaded associations" do
      owner = user_fixture()

      {:ok, log} =
        Photos.create_ollama_log(%{
          status: "success",
          model: "qwen3-vl:4b",
          owner_id: owner.id
        })

      fetched = Photos.get_ollama_log(log.id)
      assert fetched.id == log.id
      assert fetched.owner.id == owner.id
      assert fetched.photo == nil
      assert fetched.requester == nil
    end

    test "returns nil for non-existent ID" do
      assert is_nil(Photos.get_ollama_log(Ecto.UUID.generate()))
    end
  end

  describe "list_ollama_logs/1" do
    test "returns paginated results" do
      for i <- 1..5 do
        Photos.create_ollama_log(%{
          status: "success",
          model: "qwen3-vl:4b",
          duration_ms: i * 100
        })
      end

      result = Photos.list_ollama_logs(page: 1, per_page: 2)
      assert length(result.entries) == 2
      assert result.total_count == 5
      assert result.total_pages == 3
      assert result.page == 1
    end

    test "sorts by duration_ms ascending" do
      Photos.create_ollama_log(%{status: "success", model: "a", duration_ms: 300})
      Photos.create_ollama_log(%{status: "success", model: "b", duration_ms: 100})
      Photos.create_ollama_log(%{status: "success", model: "c", duration_ms: 200})

      result = Photos.list_ollama_logs(sort_by: :duration_ms, sort_dir: :asc)
      durations = Enum.map(result.entries, & &1.duration_ms)
      assert durations == [100, 200, 300]
    end

    test "defaults to descending order" do
      {:ok, _first} = Photos.create_ollama_log(%{status: "success", model: "first"})
      {:ok, _second} = Photos.create_ollama_log(%{status: "success", model: "second"})

      result = Photos.list_ollama_logs()
      assert length(result.entries) == 2
    end

    test "filters by model" do
      Photos.create_ollama_log(%{status: "success", model: "qwen3-vl:4b"})
      Photos.create_ollama_log(%{status: "success", model: "qwen3-vl:2b"})
      Photos.create_ollama_log(%{status: "success", model: "qwen3-vl:4b"})

      result = Photos.list_ollama_logs(filter_model: "qwen3-vl:4b")
      assert result.total_count == 2
      assert Enum.all?(result.entries, &(&1.model == "qwen3-vl:4b"))
    end

    test "filters by status" do
      Photos.create_ollama_log(%{status: "success", model: "a"})
      Photos.create_ollama_log(%{status: "error", model: "b", error: "timeout"})
      Photos.create_ollama_log(%{status: "success", model: "c"})

      result = Photos.list_ollama_logs(filter_status: "error")
      assert result.total_count == 1
      assert hd(result.entries).status == "error"
    end
  end

  describe "distinct_ollama_models/0" do
    test "returns unique model names" do
      Photos.create_ollama_log(%{status: "success", model: "qwen3-vl:4b"})
      Photos.create_ollama_log(%{status: "success", model: "qwen3-vl:2b"})
      Photos.create_ollama_log(%{status: "success", model: "qwen3-vl:4b"})
      Photos.create_ollama_log(%{status: "success", model: "qwen3-vl:8b"})

      models = Photos.distinct_ollama_models()
      assert length(models) == 3
      assert "qwen3-vl:2b" in models
      assert "qwen3-vl:4b" in models
      assert "qwen3-vl:8b" in models
    end

    test "excludes nil models" do
      Photos.create_ollama_log(%{status: "success", model: "qwen3-vl:4b"})
      Photos.create_ollama_log(%{status: "error", model: nil, error: "timeout"})

      models = Photos.distinct_ollama_models()
      assert models == ["qwen3-vl:4b"]
    end
  end
end
