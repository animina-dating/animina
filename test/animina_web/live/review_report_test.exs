defmodule AniminaWeb.ReviewReportTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Photo
  alias Animina.Accounts.Report
  alias Animina.Accounts.Role
  alias Animina.Accounts.User
  alias Animina.Accounts.UserRole
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story

  describe "Tests the Review Report Live" do
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
      user_three = create_user_three()

      Credit.create!(%{
        user_id: user_one.id,
        points: 100,
        subject: "Registration bonus"
      })

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
      user_three = User.by_id!(user_three.id)

      report = create_report(user_two.id, user_three.id)

      report = Report.by_id!(report.id)

      [
        user_one: user_one,
        user_two: user_two,
        report: report
      ]
    end

    test "Only Admins can visit /admin/reports/pending",
         %{
           conn: conn,
           user_one: user_one
         } do
      # User one is an admin hence they can access the reports page
      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(~p"/admin/reports/pending")

      assert html =~ "Pending Reports"
    end

    test "If a report is yet to be reviewed , you see a link to review it",
         %{
           conn: conn,
           user_one: user_one,
           report: report
         } do
      {:ok, index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(~p"/admin/reports/pending")

      assert has_element?(
               index_live,
               "#review-#{report.id}"
             )

      assert html =~ "Review Report"
    end

    test "You can click on the link to Review the Report , you are taken to the review report page",
         %{
           conn: conn,
           user_one: user_one,
           report: report
         } do
      {:ok, index_live, _html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(~p"/admin/reports/pending")

      {:ok, _index_live, html} =
        index_live
        |> element("#review-#{report.id}")
        |> render_click()
        |> follow_redirect(
          conn
          |> login_user(%{
            "username_or_email" => user_one.username,
            "password" => "password"
          }),
          "/admin/reports/pending/#{report.id}/review"
        )

      assert html =~ "Review Report"
      assert html =~ "#{report.state}"
      assert html =~ "#{report.accused.username}"
      assert html =~ "#{report.accused.username}"
      assert html =~ "#{report.description}"
    end

    test "You can approve a report on the review report page, once it is accepted , the state of the accused user is banned",
         %{
           conn: conn,
           user_one: user_one,
           report: report
         } do
      {:ok, index_live, _html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(~p"/admin/reports/pending")

      {:ok, index_live, _html} =
        index_live
        |> element("#review-#{report.id}")
        |> render_click()
        |> follow_redirect(
          conn
          |> login_user(%{
            "username_or_email" => user_one.username,
            "password" => "password"
          }),
          "/admin/reports/pending/#{report.id}/review"
        )

      {:ok, _index_live, html} =
        index_live
        |> form("#update-report-form",
          report: %{"state" => :accepted, "internal_memo" => "This is a test internal memo"}
        )
        |> render_submit()
        |> follow_redirect(
          conn
          |> login_user(%{
            "username_or_email" => user_one.username,
            "password" => "password"
          }),
          "/admin/reports/pending"
        )

      assert html =~ "Report reviewed successfully."

      report = Report.by_id!(report.id)

      assert report.state == :accepted
      assert report.internal_memo == "This is a test internal memo"

      assert report.accused.state == :banned
    end

    test "You can deny a report on the review report page, once it is denied , the state of the accused user is returned to the initial state before the reporting",
         %{
           conn: conn,
           user_one: user_one,
           report: report
         } do
      {:ok, index_live, _html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(~p"/admin/reports/pending")

      {:ok, index_live, _html} =
        index_live
        |> element("#review-#{report.id}")
        |> render_click()
        |> follow_redirect(
          conn
          |> login_user(%{
            "username_or_email" => user_one.username,
            "password" => "password"
          }),
          "/admin/reports/pending/#{report.id}/review"
        )

      {:ok, _index_live, html} =
        index_live
        |> form("#update-report-form",
          report: %{"state" => :denied, "internal_memo" => "This is a test internal memo"}
        )
        |> render_submit()
        |> follow_redirect(
          conn
          |> login_user(%{
            "username_or_email" => user_one.username,
            "password" => "password"
          }),
          "/admin/reports/pending"
        )

      assert html =~ "Report reviewed successfully."

      report = Report.by_id!(report.id)

      assert report.state == :denied
      assert report.internal_memo == "This is a test internal memo"

      assert report.accused.state == report.accused_user_state
    end
  end

  defp create_user_one do
    {:ok, user} =
      User.create(%{
        email: "bob@example.com",
        username: "bob",
        name: "Bob",
        hashed_password: Bcrypt.hash_pwd_salt("password"),
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12345678",
        language: "de",
        legal_terms_accepted: true
      })

    create_about_me_story(user.id, get_about_me_headline().id)
    create_profile_picture(user.id)
    user
  end

  defp create_user_two do
    {:ok, user} =
      User.create(%{
        email: "mike@example.com",
        username: "mike",
        name: "Mike",
        hashed_password: Bcrypt.hash_pwd_salt("password"),
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12341678",
        language: "de",
        legal_terms_accepted: true
      })

    create_about_me_story(user.id, get_about_me_headline().id)
    create_profile_picture(user.id)

    user
  end

  defp create_user_three do
    {:ok, user} =
      User.create(%{
        email: "stefan@example.com",
        username: "stefan",
        name: "stefan",
        hashed_password: Bcrypt.hash_pwd_salt("password"),
        birthday: "1951-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12311678",
        language: "en",
        legal_terms_accepted: true
      })

    create_about_me_story(user.id, get_about_me_headline().id)
    create_profile_picture(user.id)

    user
  end

  defp create_report(accuser_id, accused_id) do
    {:ok, report} =
      Report.create(%{
        state: :pending,
        accused_user_state: :normal,
        accused_id: accused_id,
        accuser_id: accuser_id,
        description: "This is a test report"
      })

    report
  end

  defp create_about_me_story(user_id, headline_id) do
    Story.create(%{
      user_id: user_id,
      headline_id: headline_id,
      content: "This is a story about me",
      position: 1
    })
  end

  defp get_about_me_headline do
    case Headline.by_subject("About me") do
      {:ok, headline} ->
        headline

      _ ->
        {:ok, headline} =
          Headline.create(%{
            subject: "About me",
            position: 90
          })

        headline
    end
  end

  defp login_user(conn, attributes) do
    {:ok, lv, _html} = live(conn, ~p"/sign-in/")

    form =
      form(lv, "#basic_user_sign_in_form", user: attributes)

    submit_form(form, conn)
  end

  defp create_profile_picture(user_id) do
    file_path = Temp.path!(basedir: "priv/static/uploads", suffix: ".jpg")

    file_path_without_uploads = String.replace(file_path, "uploads/", "")

    Photo.create(%{
      user_id: user_id,
      filename: file_path_without_uploads,
      original_filename: file_path_without_uploads,
      size: 100,
      ext: "jpg",
      mime: "image/jpeg"
    })
  end
end
