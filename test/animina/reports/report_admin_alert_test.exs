defmodule Animina.Reports.ReportAdminAlertTest do
  use Animina.DataCase, async: true

  alias Animina.AccountsFixtures
  alias Animina.Reports.ReportNotifier

  describe "deliver_new_report_admin_alert/3" do
    test "sends an email to the admin with report details" do
      admin = AccountsFixtures.user_fixture(%{display_name: "Admin", language: "en"})
      reporter = AccountsFixtures.user_fixture(%{display_name: "Alice"})
      reported_user = AccountsFixtures.user_fixture(%{display_name: "Bob"})

      report = %{
        category: "harassment",
        priority: "high",
        context_type: "chat",
        description: "Harassing messages"
      }

      assert {:ok, %Swoosh.Email{} = email} =
               ReportNotifier.deliver_new_report_admin_alert(admin, report, %{
                 reporter: reporter,
                 reported_user: reported_user
               })

      assert email.subject =~ "Bob"
      assert email.subject =~ "high"
      assert email.text_body =~ "Alice"
      assert email.text_body =~ "Bob"
      assert email.text_body =~ "Harassment"
      assert email.text_body =~ "high"
      assert email.text_body =~ "chat"
      assert email.text_body =~ "Harassing messages"
      assert email.text_body =~ "/admin/reports"
    end

    test "uses German locale when admin language is de" do
      admin = AccountsFixtures.user_fixture(%{display_name: "Admin", language: "de"})
      reporter = AccountsFixtures.user_fixture(%{display_name: "Alice"})
      reported_user = AccountsFixtures.user_fixture(%{display_name: "Bob"})

      report = %{
        category: "harassment",
        priority: "high",
        context_type: "profile",
        description: nil
      }

      assert {:ok, %Swoosh.Email{} = email} =
               ReportNotifier.deliver_new_report_admin_alert(admin, report, %{
                 reporter: reporter,
                 reported_user: reported_user
               })

      assert email.subject =~ "Neue Meldung"
      assert email.text_body =~ "Belästigung"
      assert email.text_body =~ "-"
    end
  end
end
