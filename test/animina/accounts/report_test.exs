defmodule Animina.Accounts.ReportTest do
  use Animina.DataCase, async: true
  alias Animina.Accounts.Report
  alias Animina.Accounts.User

  describe "Tests for the Report Resource" do
    setup do
      [
        user_one: create_user_one(),
        user_two: create_user_two()
      ]
    end

    test "A report must be created with the right attributes", %{
      user_one: user_one,
      user_two: user_two
    } do
      valid_attrs = %{
        "state" => :pending,
        "accused_user_state" => user_two.state,
        "accused_id" => user_two.id,
        "accuser_id" => user_one.id,
        "description" => "This is a test report"
      }

      invalid_attrs = %{
        "accused_user_state" => user_two.state,
        "accused_id" => user_two.id,
        "accuser_id" => user_one.id
      }

      assert {:ok, _report} = Report.create(valid_attrs)

      assert {:error, _} = Report.create(invalid_attrs)
    end
  end

  defp create_user_one do
    {:ok, user} =
      User.create(%{
        email: "bob@example.com",
        username: "bob",
        name: "Bob",
        hashed_password: "zzzzzzzzzzz",
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12345678",
        language: "de",
        legal_terms_accepted: true
      })

    user
  end

  defp create_user_two do
    {:ok, user} =
      User.create(%{
        email: "mike@example.com",
        username: "mike",
        name: "Mike",
        hashed_password: "zzzzzzzzzzz",
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12341678",
        language: "de",
        legal_terms_accepted: true
      })

    user
  end
end
