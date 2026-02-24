defmodule Animina.AI.JobTest do
  use Animina.DataCase, async: true

  alias Animina.AI.Job

  describe "create_changeset/2" do
    test "valid job with all fields" do
      attrs = %{
        job_type: "photo_classification",
        priority: 30,
        max_attempts: 10,
        params: %{"photo_id" => Ecto.UUID.generate()}
      }

      changeset = Job.create_changeset(%Job{}, attrs)
      assert changeset.valid?
    end

    test "requires job_type and params" do
      changeset = Job.create_changeset(%Job{}, %{})
      refute changeset.valid?
      assert %{job_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates job_type inclusion" do
      changeset = Job.create_changeset(%Job{}, %{job_type: "invalid_type", params: %{}})
      refute changeset.valid?
      assert %{job_type: ["is invalid"]} = errors_on(changeset)
    end

    test "validates priority range 10-50" do
      low = Job.create_changeset(%Job{}, %{job_type: "spellcheck", priority: 5, params: %{}})
      refute low.valid?

      high = Job.create_changeset(%Job{}, %{job_type: "spellcheck", priority: 55, params: %{}})
      refute high.valid?

      ok = Job.create_changeset(%Job{}, %{job_type: "spellcheck", priority: 20, params: %{}})
      assert ok.valid?
    end

    test "accepts all valid job types" do
      valid_types =
        ~w(photo_classification gender_guess wingman_suggestion preheated_wingman spellcheck greeting_guard)

      for type <- valid_types do
        changeset = Job.create_changeset(%Job{}, %{job_type: type, priority: 20, params: %{}})
        assert changeset.valid?, "Expected #{type} to be valid"
      end
    end

    test "defaults to pending status" do
      changeset = Job.create_changeset(%Job{}, %{job_type: "spellcheck", params: %{}})
      assert Ecto.Changeset.get_field(changeset, :status) == "pending"
    end
  end

  describe "update_changeset/2" do
    test "validates status inclusion" do
      job = %Job{id: Ecto.UUID.generate(), status: "running"}
      changeset = Job.update_changeset(job, %{status: "invalid"})
      refute changeset.valid?
    end

    test "allows valid status transitions" do
      job = %Job{id: Ecto.UUID.generate(), status: "running"}

      for status <- ~w(pending running completed failed cancelled) do
        changeset = Job.update_changeset(job, %{status: status})
        assert changeset.valid?, "Expected status #{status} to be valid"
      end
    end
  end
end
