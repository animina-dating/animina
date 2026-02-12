defmodule Animina.AI.JobTest do
  use Animina.DataCase, async: true

  alias Animina.AI.Job

  describe "create_changeset/2" do
    test "validates required fields" do
      changeset = Job.create_changeset(%Job{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).job_type
      assert "can't be blank" in errors_on(changeset).priority
      assert "can't be blank" in errors_on(changeset).params
    end

    test "validates job_type inclusion" do
      changeset =
        Job.create_changeset(%Job{}, %{
          job_type: "invalid",
          priority: 3,
          params: %{}
        })

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).job_type
    end

    test "validates priority range" do
      changeset =
        Job.create_changeset(%Job{}, %{
          job_type: "photo_classification",
          priority: 0,
          params: %{}
        })

      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).priority

      changeset =
        Job.create_changeset(%Job{}, %{
          job_type: "photo_classification",
          priority: 6,
          params: %{}
        })

      refute changeset.valid?
      assert "must be less than or equal to 5" in errors_on(changeset).priority
    end

    test "creates valid changeset with required fields" do
      changeset =
        Job.create_changeset(%Job{}, %{
          job_type: "photo_classification",
          priority: 3,
          params: %{"photo_id" => "some-uuid"}
        })

      assert changeset.valid?
    end

    test "defaults status to pending" do
      changeset =
        Job.create_changeset(%Job{}, %{
          job_type: "gender_guess",
          priority: 2,
          params: %{"name" => "alice"}
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :status) == "pending"
    end
  end

  describe "update_changeset/2" do
    test "allows updating execution fields" do
      job = %Job{
        id: Ecto.UUID.generate(),
        job_type: "photo_classification",
        priority: 3,
        status: "pending",
        params: %{}
      }

      changeset =
        Job.update_changeset(job, %{
          status: "running",
          attempt: 1,
          model: "qwen3-vl:8b",
          prompt: "test prompt"
        })

      assert changeset.valid?
    end

    test "validates status inclusion" do
      job = %Job{status: "running"}

      changeset = Job.update_changeset(job, %{status: "invalid_status"})
      refute changeset.valid?
    end
  end

  describe "admin_changeset/2" do
    test "allows changing priority and status" do
      job = %Job{status: "pending", priority: 3}

      changeset = Job.admin_changeset(job, %{priority: 1, status: "cancelled"})
      assert changeset.valid?
    end
  end
end
