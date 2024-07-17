defmodule Animina.Accounts.ReportTest do
  use Animina.DataCase, async: true
  alias Animina.Accounts.Report
  alias Animina.Accounts.Role
  alias Animina.Accounts.User
  alias Animina.Accounts.UserRole

  describe "Tests for the Report Resource" do
    setup do
      role =
        if Role.by_name!(:user) == nil do
          Role.create(%{name: :user})
        else
          Role.by_name!(:user)
        end

      admin_role =
        if Role.by_name!(:admin) == nil do
          Role.create!(%{name: :admin})
        else
          Role.by_name!(:admin)
        end

      user_one = create_user_one()
      user_two = create_user_two()

      # make user one an admin
      UserRole.create(%{
        user_id: user_one.id,
        role_id: admin_role.id
      })

      # make user two a user

      UserRole.create(%{
        user_id: user_two.id,
        role_id: role.id
      })

      user_one = User.by_id!(user_one.id)
      user_two = User.by_id!(user_two.id)

      [
        user_one: user_one,
        user_two: user_two
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

    test "Reports can only be read by admins", %{
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

      assert {:ok, report} = Report.create(valid_attrs)

      # user one who is an admin can read the report
      assert {:ok, [report_in_database]} = Report.read(actor: user_one)

      # user two who is not an admin cannot read the report
      assert {:error, _} = Report.read(actor: user_two)

      assert report_in_database.id == report.id
    end

    test "Reports can only be updated by admins", %{
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

      assert {:ok, report} = Report.create(valid_attrs)

      # user two who is not an admin cannot read the report
      assert {:error, _} = Report.update(report, %{"admin_id" => user_two.id}, actor: user_two)

      # user one who is an admin can update the report
      assert {:ok, report} = Report.update(report, %{"admin_id" => user_one.id}, actor: user_one)

      assert report.admin_id == user_one.id
    end

    test "by_id/1 returns the report of a specific id", %{
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

      assert {:ok, report} = Report.create(valid_attrs)

      assert {:ok, report_in_database} = Report.by_id(report.id, actor: user_one)

      assert report_in_database.id == report.id
    end

    test "all_reports/1 returns all reports", %{
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

      assert {:ok, _report} = Report.create(valid_attrs)

      assert {:ok, reports_in_database} = Report.all_reports(actor: user_one)

      assert Enum.count(reports_in_database) == 1
    end

    test "pending_reports/1 returns pending reports", %{
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

      assert {:ok, _report} = Report.create(valid_attrs)

      assert {:ok, reports_in_database} = Report.pending_reports(actor: user_one)

      assert Enum.count(reports_in_database) == 1
    end

    test "update/2 updates a report , if the state is accepted , the user acccused is banned", %{
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

      assert {:ok, report} = Report.create(valid_attrs)

      accused_user = User.by_id!(user_two.id)

      assert {:ok, report} =
               Report.update(report, %{
                 "state" => :accepted,
                 "admin_id" => user_one.id,
                 "internal_memo" => "This is a test internal memo"
               })

      accused_user_after_report_is_accepted = User.by_id!(user_two.id)

      assert accused_user.state == :under_investigation
      assert accused_user_after_report_is_accepted.state == :banned
      assert report.state == :accepted
    end

    test "update/2 updates a report , if the state is accepted , the user acccused is returned to the state they had before",
         %{
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

      assert {:ok, report} = Report.create(valid_attrs)

      accused_user = User.by_id!(user_two.id)

      assert {:ok, report} =
               Report.update(report, %{
                 "state" => :denied,
                 "admin_id" => user_one.id,
                 "internal_memo" => "This is a test internal memo"
               })

      accused_user_after_report_is_accepted = User.by_id!(user_two.id)

      assert accused_user.state == :under_investigation
      assert accused_user_after_report_is_accepted.state == user_two.state
      assert report.state == :denied
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
