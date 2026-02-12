defmodule Animina.Reports.ReportNotifier do
  @moduledoc """
  Sends report-related notification emails.

  All emails use the user's preferred locale and include the support
  email address for follow-up questions or appeals.
  """

  import Swoosh.Email

  alias Animina.Accounts.EmailTemplates
  alias Animina.Emails
  alias Animina.Reports.Category

  def deliver_report_notice(user) do
    render_and_deliver(user, :report_notice)
  end

  def deliver_report_warning(user, category) do
    render_and_deliver(user, :report_warning,
      category: Category.label(category, user_locale(user))
    )
  end

  def deliver_report_suspension(user, days, suspended_until, category) do
    render_and_deliver(user, :report_suspension,
      days: days,
      suspended_until: format_date(suspended_until, user_locale(user)),
      category: Category.label(category, user_locale(user))
    )
  end

  def deliver_report_permanent_ban(user, category) do
    render_and_deliver(user, :report_permanent_ban,
      category: Category.label(category, user_locale(user))
    )
  end

  def deliver_report_appeal_approved(user) do
    render_and_deliver(user, :report_appeal_approved)
  end

  def deliver_report_appeal_rejected(user) do
    render_and_deliver(user, :report_appeal_rejected)
  end

  # --- Private ---

  defp render_and_deliver(user, template, extra_assigns \\ []) do
    assigns =
      [
        greeting_name: greeting_name(user),
        support_email: Animina.FeatureFlags.support_email()
      ] ++ extra_assigns

    {subject, body} = EmailTemplates.render(user_locale(user), template, assigns)
    deliver(user, subject, body, email_type: template)
  end

  defp deliver(user, subject, body, opts) do
    config = Application.fetch_env!(:animina, :email_sender)

    email =
      new()
      |> to(user_recipient(user))
      |> from({config[:name], Animina.FeatureFlags.support_email()})
      |> subject(subject)
      |> text_body(body)
      |> header("Auto-Submitted", "auto-generated")
      |> header("Precedence", "bulk")

    Emails.deliver_and_log(email, Keyword.put(opts, :user_id, user.id))
  end

  defp user_locale(%{language: lang}) when is_binary(lang), do: lang
  defp user_locale(_), do: "de"

  defp user_recipient(user) do
    name =
      [user.first_name, user.last_name]
      |> Enum.map(&(to_string(&1) |> String.trim()))
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(" ")

    name = if name == "", do: user.display_name || "", else: name
    {name, user.email}
  end

  defp greeting_name(user) do
    [user.first_name, user.last_name, user.display_name]
    |> Enum.map(&(to_string(&1) |> String.trim()))
    |> Enum.find("", &(&1 != ""))
  end

  defp format_date(datetime, "de"), do: Calendar.strftime(datetime, "%d.%m.%Y %H:%M")
  defp format_date(datetime, _), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
end
