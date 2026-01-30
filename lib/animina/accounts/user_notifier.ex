defmodule Animina.Accounts.UserNotifier do
  import Swoosh.Email
  use Gettext, backend: AniminaWeb.Gettext

  alias Animina.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    %{name: sender_name, address: sender_address} =
      Application.fetch_env!(:animina, :email_sender) |> Map.new()

    email =
      new()
      |> to(recipient)
      |> from({sender_name, sender_address})
      |> subject(subject)
      |> text_body(body)
      |> header("Auto-Submitted", "auto-generated")
      |> header("Precedence", "bulk")

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  defp user_locale(%{language: lang}) when is_binary(lang), do: lang
  defp user_locale(_), do: "de"

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    Gettext.with_locale(AniminaWeb.Gettext, user_locale(user), fn ->
      deliver(user.email, dgettext("emails", "Update email instructions – ANIMINA"), """

      ==============================

      #{dgettext("emails", "Hi %{email},", email: user.email)}

      #{dgettext("emails", "You can change your email by visiting the URL below:")}

      #{url}

      #{dgettext("emails", "If you didn't request this change, please ignore this.")}

      ==============================
      """)
    end)
  end

  @doc """
  Deliver password reset instructions to the user's email.
  """
  def deliver_password_reset_instructions(user, url) do
    Gettext.with_locale(AniminaWeb.Gettext, user_locale(user), fn ->
      deliver(user.email, dgettext("emails", "Reset password – ANIMINA"), """

      ==============================

      #{dgettext("emails", "Hi %{email},", email: user.email)}

      #{dgettext("emails", "You can reset your password by visiting the following link:")}

      #{url}

      #{dgettext("emails", "This link is valid for 1 hour.")}

      #{dgettext("emails", "If you did not request a new password, please ignore this email.")}

      ==============================
      """)
    end)
  end

  @doc """
  Deliver a 6-digit confirmation PIN to the user's email.
  """
  def deliver_confirmation_pin(user, pin) do
    Gettext.with_locale(AniminaWeb.Gettext, user_locale(user), fn ->
      deliver(user.email, dgettext("emails", "Your confirmation code for ANIMINA"), """

      ==============================

      #{dgettext("emails", "Hi %{email},", email: user.email)}

      #{dgettext("emails", "Your confirmation code is:")}

          #{pin}

      #{dgettext("emails", "Please enter this code within 30 minutes to confirm your email address.")}

      #{dgettext("emails", "You have a maximum of 3 attempts. After 3 wrong entries or after 30 minutes, your account will be deleted and you will need to register again.")}

      #{dgettext("emails", "If you did not create an account at ANIMINA, please ignore this email.")}

      ==============================
      """)
    end)
  end

  @doc """
  Deliver a daily report of newly registered and confirmed users.
  `count` is the number of new users, `recipient` is a `{name, email}` tuple.
  """
  def deliver_daily_new_users_report(count, {_name, email}) do
    # Admin report is always in German
    Gettext.with_locale(AniminaWeb.Gettext, "de", fn ->
      subject =
        dngettext(
          "emails",
          "ANIMINA: %{count} new user in the last 24 hours",
          "ANIMINA: %{count} new users in the last 24 hours",
          count
        )

      body =
        dngettext(
          "emails",
          "%{count} new user registered and confirmed via PIN at ANIMINA in the last 24 hours.",
          "%{count} new users registered and confirmed via PIN at ANIMINA in the last 24 hours.",
          count
        )

      deliver(
        email,
        subject,
        """

        ==============================

        #{dgettext("emails", "Hello,")}

        #{body}

        ==============================
        """
      )
    end)
  end

  @doc """
  Deliver a warning email when someone tries to register with an email
  that already belongs to an existing account.
  """
  def deliver_duplicate_registration_warning(email) when is_binary(email) do
    # We don't know the user's language, so use default
    deliver(email, dgettext("emails", "Security notice – ANIMINA"), """

    ==============================

    #{dgettext("emails", "Hello,")}

    #{dgettext("emails", "Someone tried to create a new ANIMINA account with your email address (%{email}).", email: email)}

    #{dgettext("emails", "If this was not you, we recommend changing your password to protect your account.")}

    #{dgettext("emails", "If you were trying to register yourself: You already have an account. Please log in with your existing password or use the forgot password feature.")}

    ==============================
    """)
  end
end
