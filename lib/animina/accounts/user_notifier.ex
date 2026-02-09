defmodule Animina.Accounts.UserNotifier do
  @moduledoc """
  Delivers email notifications for user account events.
  """

  import Swoosh.Email

  alias Animina.Accounts.EmailTemplates
  alias Animina.Emails

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body, opts) do
    config = Application.fetch_env!(:animina, :email_sender)

    email =
      new()
      |> to(recipient)
      |> from({config[:name], Animina.FeatureFlags.support_email()})
      |> subject(subject)
      |> text_body(body)
      |> header("Auto-Submitted", "auto-generated")
      |> header("Precedence", "bulk")

    Emails.deliver_and_log(email, opts)
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

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    {subject, body} =
      EmailTemplates.render(user_locale(user), :update_email,
        email: user.email,
        greeting_name: greeting_name(user),
        url: url
      )

    deliver(user_recipient(user), subject, body, email_type: :update_email, user_id: user.id)
  end

  @doc """
  Deliver password reset instructions to the user's email.
  """
  def deliver_password_reset_instructions(user, url) do
    {subject, body} =
      EmailTemplates.render(user_locale(user), :password_reset,
        email: user.email,
        greeting_name: greeting_name(user),
        url: url
      )

    deliver(user_recipient(user), subject, body,
      email_type: :password_reset,
      user_id: user.id
    )
  end

  @doc """
  Deliver a 6-digit confirmation PIN to the user's email.
  """
  def deliver_confirmation_pin(user, pin) do
    now_berlin = berlin_now()
    minutes = Animina.FeatureFlags.pin_validity_minutes()
    expires_berlin = DateTime.add(now_berlin, minutes, :minute)

    {subject, body} =
      EmailTemplates.render(user_locale(user), :confirmation_pin,
        email: user.email,
        greeting_name: greeting_name(user),
        pin: pin,
        pin_validity_minutes: minutes,
        sent_at: format_berlin_time(now_berlin),
        expires_at: format_berlin_time(expires_berlin)
      )

    deliver(user_recipient(user), subject, body,
      email_type: :confirmation_pin,
      user_id: user.id
    )
  end

  @doc """
  Deliver a daily report of newly registered and confirmed users.
  `count` is the number of new users, `recipient` is a `{name, email}` tuple.
  """
  def deliver_daily_new_users_report(count, {_name, email}) do
    # Admin report is always in German
    {subject, body} = EmailTemplates.render("de", :daily_report, count: count)
    deliver(email, subject, body, email_type: :daily_report)
  end

  @doc """
  Deliver a goodbye email when a user soft-deletes their account.
  Includes the permanent deletion date (deleted_at + 30 days).
  """
  def deliver_account_deletion_goodbye(%{deleted_at: deleted_at} = user) do
    permanent_deletion_date =
      deleted_at
      |> DateTime.add(30, :day)
      |> format_date_for_locale(user_locale(user))

    {subject, body} =
      EmailTemplates.render(user_locale(user), :account_deletion_goodbye,
        email: user.email,
        greeting_name: greeting_name(user),
        permanent_deletion_date: permanent_deletion_date
      )

    deliver(user_recipient(user), subject, body,
      email_type: :account_deletion_goodbye,
      user_id: user.id
    )
  end

  defp format_date_for_locale(datetime, _locale) do
    Calendar.strftime(datetime, "%d.%m.%Y")
  end

  @doc """
  Deliver a registration spike alert email.
  `stats` is a map with keys: today_count, daily_average, threshold, spike_factor,
  yesterday_count, hourly_breakdown. `recipient` is a `{name, email}` tuple.
  """
  def deliver_registration_spike_alert(stats, {_name, email}) do
    # Admin report is always in German
    {subject, body} =
      EmailTemplates.render("de", :registration_spike_alert,
        today_count: stats.today_count,
        daily_average: stats.daily_average,
        threshold: stats.threshold,
        spike_factor: stats.spike_factor,
        yesterday_count: stats.yesterday_count,
        hourly_breakdown: stats.hourly_breakdown
      )

    deliver(email, subject, body, email_type: :registration_spike_alert)
  end

  @doc """
  Deliver a warning email when someone tries to register with an email
  that already belongs to an existing account.
  """
  def deliver_duplicate_registration_warning(email) when is_binary(email) do
    user = Animina.Accounts.get_user_by_email(email)

    recipient = if user, do: user_recipient(user), else: {"", email}

    {subject, body} =
      EmailTemplates.render(user_locale(user), :duplicate_registration,
        email: email,
        greeting_name: if(user, do: greeting_name(user), else: ""),
        attempted_at: format_german_time()
      )

    deliver(recipient, subject, body,
      email_type: :duplicate_registration,
      user_id: if(user, do: user.id)
    )
  end

  @doc """
  Deliver an Ollama queue alert email to the admin.
  Sent when the queue exceeds the threshold (default: 20 photos).
  """
  def deliver_ollama_queue_alert(stats) do
    # Admin alert is always sent to Stefan in German
    email = "sw@wintermeyer-consulting.de"

    {subject, body} =
      EmailTemplates.render("de", :ollama_queue_alert,
        queue_count: stats.queue_count,
        oldest_photo_age_hours: stats.oldest_photo_age_hours,
        ollama_status: stats.ollama_status
      )

    deliver(email, subject, body, email_type: :ollama_queue_alert)
  end

  @doc """
  Deliver a notification about unread messages.
  Sent after 24 hours of unread messages to remind users.
  """
  def deliver_unread_messages_notification(user, unread_count) do
    {subject, body} =
      EmailTemplates.render(user_locale(user), :unread_messages,
        email: user.email,
        greeting_name: greeting_name(user),
        unread_count: unread_count
      )

    deliver(user_recipient(user), subject, body,
      email_type: :unread_messages,
      user_id: user.id
    )
  end

  @doc """
  Deliver a notification to the OLD email when email was changed.
  Includes undo and confirm links.
  """
  def deliver_email_changed_notification(user, old_email, new_email, undo_url, confirm_url) do
    locale = user_locale(user)
    greeting = greeting_name(user)

    {subject, body} =
      EmailTemplates.render(locale, :email_changed_notification,
        greeting_name: greeting,
        old_email: old_email,
        new_email: new_email,
        undo_url: undo_url,
        confirm_url: confirm_url,
        support_email: Animina.FeatureFlags.support_email()
      )

    # Send to old email (the victim's email)
    deliver(old_email, subject, body,
      email_type: :email_changed_notification,
      user_id: user.id
    )
  end

  @doc """
  Deliver a notification to the current email when password was changed.
  Includes undo and confirm links.
  """
  def deliver_password_changed_notification(user, undo_url, confirm_url) do
    {subject, body} =
      EmailTemplates.render(user_locale(user), :password_changed_notification,
        greeting_name: greeting_name(user),
        email: user.email,
        undo_url: undo_url,
        confirm_url: confirm_url,
        support_email: Animina.FeatureFlags.support_email()
      )

    deliver(user_recipient(user), subject, body,
      email_type: :password_changed_notification,
      user_id: user.id
    )
  end

  @german_months %{
    1 => "Januar",
    2 => "Februar",
    3 => "März",
    4 => "April",
    5 => "Mai",
    6 => "Juni",
    7 => "Juli",
    8 => "August",
    9 => "September",
    10 => "Oktober",
    11 => "November",
    12 => "Dezember"
  }

  defp format_german_time do
    now = berlin_now()

    Calendar.strftime(now, "%d. %B %Y um %H:%M Uhr",
      month_names: fn month -> @german_months[month] end
    )
  end

  defp berlin_now do
    DateTime.utc_now()
    |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)
  end

  defp format_berlin_time(%DateTime{} = dt) do
    zone_abbr = if dt.std_offset > 0, do: "CEST", else: "CET"
    Calendar.strftime(dt, "%H:%M #{zone_abbr}")
  end
end
