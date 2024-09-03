defmodule AniminaWeb.AllReportsTest do
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

  describe "Tests the All Reports Live" do
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
      user_four = create_user_four()

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

      # make user three a user

      UserRole.create(%{
        user_id: user_three.id,
        role_id: role.id
      })

      # make user four a user

      UserRole.create(%{
        user_id: user_four.id,
        role_id: role.id
      })

      user_one = User.by_id!(user_one.id)
      user_two = User.by_id!(user_two.id)
      user_three = User.by_id!(user_three.id)
      user_four = User.by_id!(user_four.id)

      report = create_report(user_two.id, user_three.id)
      reviewed_report = create_reviewed_report(user_two.id, user_four.id, user_one.id)

      report = Report.by_id!(report.id)
      reviewed_report = Report.by_id!(reviewed_report.id)

      [
        user_one: user_one,
        user_two: user_two,
        user_three: user_three,
        user_four: user_four,
        report: report,
        reviewed_report: reviewed_report
      ]
    end

    test "Only Admins can visit /admin/reports/all",
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
        |> live(~p"/admin/reports/all")

      assert html =~ "All Reports"
    end

    test "Normal Users cannot visit /admin/reports/all",
         %{
           conn: conn,
           user_two: user_two
         } do
      # User two is a normal user hence they cannot access the reports page

      {:error, {:redirect, %{to: url, flash: %{}}}} =
        conn
        |> login_user(%{
          "username_or_email" => user_two.username,
          "password" => "password"
        })
        |> live(~p"/admin/reports/all")

      assert url =~ "/sign-in"
    end

    test "If you click on the 'All Reports' tab , you are taken to the all reports page",
         %{
           conn: conn,
           user_one: user_one
         } do
      # User one is an admin hence they can access the reports page
      {:ok, index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(~p"/admin/reports/pending")

      assert html =~ "Pending Reports"

      {:error, {:live_redirect, %{kind: :push, to: url}}} =
        index_live
        |> element("#all-reports-tab")
        |> render_click()

      assert url == "/admin/reports/all"

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(url)

      assert html =~ "All Reports"
    end

    test "In the all reports page you see all the reports",
         %{
           conn: conn,
           user_one: user_one,
           report: report,
           reviewed_report: reviewed_report
         } do
      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(~p"/admin/reports/all")

      assert html =~ "All Reports"
      assert html =~ report.description
      assert html =~ reviewed_report.description
      assert html =~ Atom.to_string(report.state)
      assert html =~ Atom.to_string(reviewed_report.state)
      assert html =~ Ash.CiString.value(report.accused.username)
      assert html =~ Ash.CiString.value(reviewed_report.accused.username)
      assert html =~ Ash.CiString.value(report.accuser.username)
      assert html =~ Ash.CiString.value(reviewed_report.accuser.username)
    end

    test "If a report has been reviewed , you see who reviewed it",
         %{
           conn: conn,
           user_one: user_one,
           reviewed_report: reviewed_report
         } do
      {:ok, index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(~p"/admin/reports/all")

      assert has_element?(
               index_live,
               "##{reviewed_report.id}-reviewed-by-#{reviewed_report.admin.id}"
             )

      assert html =~ "Reviewed By #{reviewed_report.admin.name}"
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
        |> live(~p"/admin/reports/all")

      assert has_element?(
               index_live,
               "#review-#{report.id}"
             )

      assert html =~ "Review Report"
    end

    test "You can click on the link of the accuser to access their profile",
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
        |> live(~p"/admin/reports/all")

      {:ok, _index_live, html} =
        index_live
        |> element("#accuser-#{report.accuser_id}-report-#{report.id}")
        |> render_click()
        |> follow_redirect(conn, "/#{report.accuser.username}")

      assert html =~ report.accuser.name
      assert html =~ "#{report.accuser.height}"
    end

    test "You can click on the link of the accused to access their profile",
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
        |> live(~p"/admin/reports/all")

      {_, {:live_redirect, %{kind: :push, to: url}}} =
        index_live
        |> element("#accused-#{report.accused_id}-report-#{report.id}")
        |> render_click()

      assert url =~ "/#{report.accused.username}"

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(url)

      assert html =~ report.accused.name

      assert html =~ "#{report.accused.height}"
    end

    test "If a report is yet to be reviewed , you see a link to review it , if you click it you are redirected to the review
    report page
    ",
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
        |> live(~p"/admin/reports/all")

      {_, {:live_redirect, %{kind: :push, to: url}}} =
        index_live
        |> element("#review-#{report.id}")
        |> render_click()

      assert url == "/admin/reports/pending/#{report.id}/review"

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(url)

      assert html =~ "Review Report"
      assert html =~ "Description"
      assert html =~ report.description
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

  defp create_user_four do
    {:ok, user} =
      User.create(%{
        email: "fourth_user@example.com",
        username: "fourth_user",
        name: "fourth_user",
        hashed_password: Bcrypt.hash_pwd_salt("password"),
        birthday: "1951-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12321678",
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

  defp create_reviewed_report(accuser_id, accused_id, admin_id) do
    {:ok, report} =
      Report.create(%{
        state: :accepted,
        accused_user_state: :normal,
        accused_id: accused_id,
        accuser_id: accuser_id,
        description: "This is a reviewed test report",
        admin_id: admin_id,
        internal_memo: "This is an internal memo"
      })

    report
  end

  defp login_user(conn, attributes) do
    {:ok, lv, _html} = live(conn, ~p"/sign-in/")

    form =
      form(lv, "#basic_user_sign_in_form", user: attributes)

    submit_form(form, conn)
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
