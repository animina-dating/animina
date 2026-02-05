defmodule Animina.Photos.PhotoProcessorTest do
  use Animina.DataCase

  alias Animina.Photos
  alias Animina.Photos.PhotoProcessor
  alias Animina.Repo

  import Animina.PhotosFixtures

  describe "recover_stuck_photos/0" do
    test "recovers photos in processing state" do
      photo = photo_fixture()

      photo
      |> Ecto.Changeset.change(%{state: "processing"})
      |> Repo.update!()

      assert {:ok, 1} = PhotoProcessor.recover_stuck_photos()

      updated = Photos.get_photo!(photo.id)
      assert updated.state == "pending"
    end

    test "recovers photos in ollama_checking state" do
      photo = photo_fixture()

      photo
      |> Ecto.Changeset.change(%{state: "ollama_checking", width: 800, height: 600})
      |> Repo.update!()

      assert {:ok, 1} = PhotoProcessor.recover_stuck_photos()

      updated = Photos.get_photo!(photo.id)
      assert updated.state == "pending"
    end

    test "recovers multiple stuck photos" do
      photo1 = photo_fixture()
      photo2 = photo_fixture()

      photo1 |> Ecto.Changeset.change(%{state: "processing"}) |> Repo.update!()

      photo2
      |> Ecto.Changeset.change(%{state: "ollama_checking", width: 800, height: 600})
      |> Repo.update!()

      assert {:ok, 2} = PhotoProcessor.recover_stuck_photos()

      assert Photos.get_photo!(photo1.id).state == "pending"
      assert Photos.get_photo!(photo2.id).state == "pending"
    end

    test "does not affect photos in terminal states" do
      approved = approved_photo_fixture()
      error = error_photo_fixture()
      pending = photo_fixture()

      assert {:ok, 0} = PhotoProcessor.recover_stuck_photos()

      assert Photos.get_photo!(approved.id).state == "approved"
      assert Photos.get_photo!(error.id).state == "error"
      assert Photos.get_photo!(pending.id).state == "pending"
    end

    test "logs recovery event in audit log" do
      photo = photo_fixture()

      photo
      |> Ecto.Changeset.change(%{state: "processing"})
      |> Repo.update!()

      PhotoProcessor.recover_stuck_photos()

      history = Photos.get_photo_history(photo.id)
      recovery_event = Enum.find(history, &(&1.event_type == "recovery_after_restart"))

      assert recovery_event
      assert recovery_event.actor_type == "system"
      assert recovery_event.details["previous_state"] == "processing"
    end
  end

  describe "process_photo via GenServer" do
    setup do
      # Start the processor for this test (disabled by default in test config)
      {:ok, pid} = PhotoProcessor.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid)
      end)

      :ok
    end

    test "enqueue/1 accepts a photo" do
      photo = photo_fixture()
      # Should not raise — the cast is fire-and-forget
      assert :ok = PhotoProcessor.enqueue(photo)
    end
  end

  describe "parse_ollama_response/1" do
    test "parses new nested JSON format with single person and family friendly content" do
      response = ~s|{
        "photo_analysis": {
          "person_detection": {
            "contains_person": true,
            "person_count": 1,
            "persons_facing_camera": 1,
            "children_present": false,
            "adult_present": true
          },
          "content_safety": {
            "family_friendly": true,
            "nudity_detected": false,
            "explicit_content": false,
            "illegal_activity": false,
            "drug_use": false,
            "violence": false,
            "firearms_visible": false,
            "hunting_scene": false
          },
          "attire_assessment": {
            "appropriate_attire": true,
            "swimwear_detected": false,
            "underwear_detected": false,
            "shirtless": false,
            "outdoor_context": false,
            "beach_context": false
          },
          "sex_scene": false
        }
      }|

      result = PhotoProcessor.parse_ollama_response(response)

      assert result.content_safety.family_friendly == true
      assert result.person_detection.contains_person == true
      assert result.person_detection.persons_facing_camera == 1
      assert result.content_safety.nudity_detected == false
      assert result.content_safety.firearms_visible == false
    end

    test "parses legacy JSON format for backwards compatibility" do
      response =
        ~s|{"contains_person": true, "person_facing_camera_count": 1, "family_friendly": true}|

      result = PhotoProcessor.parse_ollama_response(response)

      assert result.content_safety.family_friendly == true
      assert result.person_detection.contains_person == true
      assert result.person_detection.persons_facing_camera == 1
    end

    test "parses JSON with no person" do
      response =
        ~s|{"contains_person": false, "person_facing_camera_count": 0, "family_friendly": true}|

      result = PhotoProcessor.parse_ollama_response(response)

      assert result.content_safety.family_friendly == true
      assert result.person_detection.contains_person == false
      assert result.person_detection.persons_facing_camera == 0
    end

    test "parses JSON with multiple people" do
      response =
        ~s|{"contains_person": true, "person_facing_camera_count": 3, "family_friendly": true}|

      result = PhotoProcessor.parse_ollama_response(response)

      assert result.content_safety.family_friendly == true
      assert result.person_detection.contains_person == true
      assert result.person_detection.persons_facing_camera == 3
    end

    test "parses JSON with NSFW content (not family friendly)" do
      response =
        ~s|{"contains_person": true, "person_facing_camera_count": 1, "family_friendly": false}|

      result = PhotoProcessor.parse_ollama_response(response)

      assert result.content_safety.family_friendly == false
      assert result.person_detection.contains_person == true
      assert result.person_detection.persons_facing_camera == 1
    end

    test "handles JSON with extra text around it" do
      response = """
      Here's my analysis:
      {"contains_person": true, "person_facing_camera_count": 1, "family_friendly": true}
      This is a valid profile photo.
      """

      result = PhotoProcessor.parse_ollama_response(response)

      assert result.content_safety.family_friendly == true
      assert result.person_detection.contains_person == true
    end

    test "falls back to text parsing when no JSON found" do
      # Legacy format fallback
      response = """
      This is not JSON
      """

      result = PhotoProcessor.parse_ollama_response(response)

      # Defaults when no JSON found
      assert result.content_safety.family_friendly == true
      assert result.person_detection.contains_person == false
    end

    test "parses new format with content violations" do
      response = ~s|{
        "photo_analysis": {
          "person_detection": {
            "contains_person": true,
            "person_count": 1,
            "persons_facing_camera": 1,
            "children_present": false,
            "adult_present": true
          },
          "content_safety": {
            "family_friendly": false,
            "nudity_detected": true,
            "explicit_content": false,
            "illegal_activity": false,
            "drug_use": false,
            "violence": false,
            "firearms_visible": false,
            "hunting_scene": false
          },
          "attire_assessment": {
            "appropriate_attire": false,
            "swimwear_detected": false,
            "underwear_detected": false,
            "shirtless": false,
            "outdoor_context": false,
            "beach_context": false
          },
          "sex_scene": false
        }
      }|

      result = PhotoProcessor.parse_ollama_response(response)

      assert result.content_safety.family_friendly == false
      assert result.content_safety.nudity_detected == true
      assert result.attire_assessment.appropriate_attire == false
    end
  end

  describe "Ollama state transitions" do
    test "ollama_checking can transition to approved" do
      photo = photo_fixture(%{type: "avatar"})

      photo =
        photo
        |> Ecto.Changeset.change(%{
          state: "ollama_checking",
          width: 800,
          height: 600
        })
        |> Repo.update!()

      {:ok, updated} =
        Photos.transition_photo(photo, "approved", %{
          nsfw: false,
          has_face: true
        })

      assert updated.state == "approved"
    end

    test "ollama_checking can transition to no_face_error" do
      photo = photo_fixture(%{type: "avatar"})

      photo =
        photo
        |> Ecto.Changeset.change(%{
          state: "ollama_checking",
          width: 800,
          height: 600
        })
        |> Repo.update!()

      {:ok, updated} =
        Photos.transition_photo(photo, "no_face_error", %{
          nsfw: false,
          has_face: false,
          error_message: "No face detected"
        })

      assert updated.state == "no_face_error"
    end

    test "ollama_checking can transition to pending_ollama on failure" do
      photo = photo_fixture(%{type: "avatar"})

      photo =
        photo
        |> Ecto.Changeset.change(%{
          state: "ollama_checking",
          width: 800,
          height: 600
        })
        |> Repo.update!()

      {:ok, updated} =
        Photos.transition_photo(photo, "pending_ollama", %{
          ollama_retry_count: 1
        })

      assert updated.state == "pending_ollama"
    end

    test "pending_ollama can transition back to ollama_checking" do
      photo = photo_fixture(%{type: "avatar"})

      photo =
        photo
        |> Ecto.Changeset.change(%{
          state: "pending_ollama",
          width: 800,
          height: 600,
          ollama_retry_count: 1
        })
        |> Repo.update!()

      {:ok, updated} = Photos.transition_photo(photo, "ollama_checking")

      assert updated.state == "ollama_checking"
    end
  end
end
