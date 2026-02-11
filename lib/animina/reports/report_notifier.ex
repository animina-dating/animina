defmodule Animina.Reports.ReportNotifier do
  @moduledoc """
  Sends report-related notification emails.
  """

  import Swoosh.Email

  alias Animina.Accounts.EmailTemplates
  alias Animina.Emails

  @doc """
  Sends a generic notification when a report is filed.
  """
  def deliver_report_notice(user) do
    deliver_report_email(user, :report_notice)
  end

  @doc """
  Sends a warning decision email with appeal instructions.
  """
  def deliver_report_warning(user) do
    deliver_report_email(user, :report_warning)
  end

  @doc """
  Sends a suspension decision email.
  """
  def deliver_report_suspension(user) do
    suspended_until =
      if user.suspended_until do
        format_date_for_locale(user.suspended_until, user_locale(user))
      else
        "N/A"
      end

    {subject, body} =
      EmailTemplates.render(user_locale(user), :report_suspension,
        greeting_name: greeting_name(user),
        suspended_until: suspended_until
      )

    deliver(user, subject, body, email_type: :report_suspension)
  end

  @doc """
  Sends a permanent ban decision email.
  """
  def deliver_report_permanent_ban(user) do
    deliver_report_email(user, :report_permanent_ban)
  end

  @doc """
  Sends an appeal approved email.
  """
  def deliver_report_appeal_approved(user) do
    deliver_report_email(user, :report_appeal_approved)
  end

  @doc """
  Sends an appeal rejected email.
  """
  def deliver_report_appeal_rejected(user) do
    deliver_report_email(user, :report_appeal_rejected)
  end

  # --- Private ---

  defp deliver_report_email(user, template) do
    {subject, body} =
      EmailTemplates.render(user_locale(user), template, greeting_name: greeting_name(user))

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
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(" ")

    name = if name == "", do: user.display_name || "", else: name
    {name, user.email}
  end

  defp greeting_name(user) do
    [Map.get(user, :first_name), Map.get(user, :last_name), Map.get(user, :display_name)]
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.find("", &(&1 != ""))
  end

  defp format_date_for_locale(datetime, "de") do
    Calendar.strftime(datetime, "%d.%m.%Y %H:%M")
  end

  defp format_date_for_locale(datetime, _locale) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end
end
