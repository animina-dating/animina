defmodule Animina.Photos.PhotoFeedbackTest do
  use ExUnit.Case, async: true

  alias Animina.Photos.PhotoFeedback

  # Helper to create a valid parsed response structure
  defp valid_parsed do
    %{
      person_detection: %{
        contains_person: true,
        person_count: 1,
        persons_facing_camera: 1,
        children_present: false,
        adult_present: true
      },
      content_safety: %{
        family_friendly: true,
        nudity_detected: false,
        explicit_content: false,
        illegal_activity: false,
        drug_use: false,
        violence: false,
        firearms_visible: false,
        hunting_scene: false
      },
      attire_assessment: %{
        appropriate_attire: true,
        swimwear_detected: false,
        underwear_detected: false,
        shirtless: false,
        outdoor_context: false,
        beach_context: false
      },
      animal_detection: %{
        is_an_animal: false,
        is_a_dog: false,
        is_a_cat: false
      },
      sex_scene: false
    }
  end

  describe "analyze_avatar/1" do
    test "approves valid avatar photo" do
      assert {:ok, :approved} = PhotoFeedback.analyze_avatar(valid_parsed())
    end

    test "rejects photo with nudity" do
      parsed = put_in(valid_parsed(), [:content_safety, :nudity_detected], true)
      assert {:error, :nudity, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "nudity"
    end

    test "rejects photo that is not family friendly" do
      parsed = put_in(valid_parsed(), [:content_safety, :family_friendly], false)
      assert {:error, :not_family_friendly, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "appropriate"
    end

    test "rejects photo with firearms" do
      parsed = put_in(valid_parsed(), [:content_safety, :firearms_visible], true)
      assert {:error, :firearms, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "firearm"
    end

    test "rejects hunting photo" do
      parsed = put_in(valid_parsed(), [:content_safety, :hunting_scene], true)
      assert {:error, :hunting, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "unting"
    end

    test "rejects sex scene" do
      parsed = put_in(valid_parsed(), [:sex_scene], true)
      assert {:error, :sex_scene, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "sexual"
    end

    test "rejects photo with no face detected" do
      parsed = put_in(valid_parsed(), [:person_detection, :contains_person], false)
      assert {:error, :no_face, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "face"
    end

    test "rejects photo with multiple people facing camera" do
      parsed = put_in(valid_parsed(), [:person_detection, :persons_facing_camera], 3)
      assert {:error, :multiple_faces, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "multiple"
    end

    test "rejects photo with only children (no adult)" do
      parsed =
        valid_parsed()
        |> put_in([:person_detection, :children_present], true)
        |> put_in([:person_detection, :adult_present], false)

      assert {:error, :child_only, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "children"
    end

    test "approves photo with children when adult is present" do
      parsed =
        valid_parsed()
        |> put_in([:person_detection, :children_present], true)
        |> put_in([:person_detection, :adult_present], true)

      assert {:ok, :approved} = PhotoFeedback.analyze_avatar(parsed)
    end

    test "rejects inappropriate attire" do
      parsed = put_in(valid_parsed(), [:attire_assessment, :appropriate_attire], false)
      assert {:error, :inappropriate_attire, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "attire"
    end

    test "rejects underwear detection" do
      parsed = put_in(valid_parsed(), [:attire_assessment, :underwear_detected], true)
      assert {:error, :inappropriate_attire, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "attire"
    end

    test "rejects swimwear in indoor setting" do
      parsed =
        valid_parsed()
        |> put_in([:attire_assessment, :swimwear_detected], true)
        |> put_in([:attire_assessment, :outdoor_context], false)
        |> put_in([:attire_assessment, :beach_context], false)

      assert {:error, :inappropriate_attire, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "wimwear"
    end

    test "approves swimwear at beach" do
      parsed =
        valid_parsed()
        |> put_in([:attire_assessment, :swimwear_detected], true)
        |> put_in([:attire_assessment, :beach_context], true)

      assert {:ok, :approved} = PhotoFeedback.analyze_avatar(parsed)
    end

    test "approves swimwear outdoors" do
      parsed =
        valid_parsed()
        |> put_in([:attire_assessment, :swimwear_detected], true)
        |> put_in([:attire_assessment, :outdoor_context], true)

      assert {:ok, :approved} = PhotoFeedback.analyze_avatar(parsed)
    end

    test "rejects photo with animal detected" do
      parsed = put_in(valid_parsed(), [:animal_detection, :is_an_animal], true)
      assert {:error, :animal, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "an animal"
    end

    test "rejects photo with dog detected" do
      parsed = put_in(valid_parsed(), [:animal_detection, :is_a_dog], true)
      assert {:error, :animal, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "a dog"
    end

    test "rejects photo with cat detected" do
      parsed = put_in(valid_parsed(), [:animal_detection, :is_a_cat], true)
      assert {:error, :animal, message} = PhotoFeedback.analyze_avatar(parsed)
      assert message =~ "a cat"
    end
  end

  describe "analyze_moodboard/1" do
    test "approves valid moodboard photo" do
      assert {:ok, :approved} = PhotoFeedback.analyze_moodboard(valid_parsed())
    end

    test "approves moodboard with multiple people" do
      # Moodboard doesn't require single person
      parsed = put_in(valid_parsed(), [:person_detection, :persons_facing_camera], 5)
      assert {:ok, :approved} = PhotoFeedback.analyze_moodboard(parsed)
    end

    test "approves moodboard with no face" do
      # Moodboard doesn't require a face
      parsed =
        valid_parsed()
        |> put_in([:person_detection, :contains_person], false)
        |> put_in([:person_detection, :persons_facing_camera], 0)

      assert {:ok, :approved} = PhotoFeedback.analyze_moodboard(parsed)
    end

    test "rejects moodboard with nudity" do
      parsed = put_in(valid_parsed(), [:content_safety, :nudity_detected], true)
      assert {:error, :nudity, _message} = PhotoFeedback.analyze_moodboard(parsed)
    end

    test "rejects moodboard with firearms" do
      parsed = put_in(valid_parsed(), [:content_safety, :firearms_visible], true)
      assert {:error, :firearms, _message} = PhotoFeedback.analyze_moodboard(parsed)
    end

    test "rejects moodboard with hunting scene" do
      parsed = put_in(valid_parsed(), [:content_safety, :hunting_scene], true)
      assert {:error, :hunting, _message} = PhotoFeedback.analyze_moodboard(parsed)
    end

    test "approves moodboard with animal photo" do
      parsed = put_in(valid_parsed(), [:animal_detection, :is_an_animal], true)
      assert {:ok, :approved} = PhotoFeedback.analyze_moodboard(parsed)
    end
  end

  describe "violation_to_state/1" do
    test "returns no_face_error for face-related violations" do
      assert PhotoFeedback.violation_to_state(:no_face) == "no_face_error"
      assert PhotoFeedback.violation_to_state(:multiple_faces) == "no_face_error"
      assert PhotoFeedback.violation_to_state(:child_only) == "no_face_error"
      assert PhotoFeedback.violation_to_state(:animal) == "no_face_error"
    end

    test "returns error for content violations" do
      assert PhotoFeedback.violation_to_state(:nudity) == "error"
      assert PhotoFeedback.violation_to_state(:firearms) == "error"
      assert PhotoFeedback.violation_to_state(:hunting) == "error"
      assert PhotoFeedback.violation_to_state(:not_family_friendly) == "error"
    end
  end

  describe "should_blacklist?/1" do
    test "returns true for serious content violations" do
      assert PhotoFeedback.should_blacklist?(:nudity) == true
      assert PhotoFeedback.should_blacklist?(:not_family_friendly) == true
      assert PhotoFeedback.should_blacklist?(:sex_scene) == true
      assert PhotoFeedback.should_blacklist?(:illegal_content) == true
    end

    test "returns false for face-related violations" do
      assert PhotoFeedback.should_blacklist?(:no_face) == false
      assert PhotoFeedback.should_blacklist?(:multiple_faces) == false
      assert PhotoFeedback.should_blacklist?(:child_only) == false
      assert PhotoFeedback.should_blacklist?(:animal) == false
    end

    test "returns false for attire violations" do
      assert PhotoFeedback.should_blacklist?(:inappropriate_attire) == false
    end
  end
end
