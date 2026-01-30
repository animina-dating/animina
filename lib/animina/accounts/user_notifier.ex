defmodule Animina.Accounts.UserNotifier do
  import Swoosh.Email

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

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver password reset instructions to the user's email.
  """
  def deliver_password_reset_instructions(user, url) do
    deliver(user.email, "Passwort zurücksetzen – ANIMINA", """

    ==============================

    Hallo #{user.email},

    du kannst dein Passwort zurücksetzen, indem du den folgenden Link besuchst:

    #{url}

    Dieser Link ist 1 Stunde gültig.

    Falls du kein neues Passwort angefordert hast,
    ignoriere bitte diese E-Mail.

    ==============================
    """)
  end

  @doc """
  Deliver a 6-digit confirmation PIN to the user's email.
  """
  def deliver_confirmation_pin(user, pin) do
    deliver(user.email, "Dein Bestätigungscode für ANIMINA", """

    ==============================

    Hallo #{user.email},

    Dein Bestätigungscode lautet:

        #{pin}

    Bitte gib diesen Code innerhalb von 30 Minuten ein,
    um deine E-Mail-Adresse zu bestätigen.

    Du hast maximal 3 Versuche. Nach 3 falschen Eingaben
    oder nach Ablauf der 30 Minuten wird dein Konto
    gelöscht und du musst dich erneut registrieren.

    Falls du kein Konto bei ANIMINA erstellt hast,
    ignoriere bitte diese E-Mail.

    ==============================
    """)
  end

  @doc """
  Deliver a daily report of newly registered and confirmed users.
  `count` is the number of new users, `recipient` is a `{name, email}` tuple.
  """
  def deliver_daily_new_users_report(count, {_name, email}) do
    user_word = if count == 1, do: "Nutzer hat", else: "Nutzer haben"

    deliver(
      email,
      "ANIMINA: #{count} neue #{if count == 1, do: "Nutzer", else: "Nutzer"} in den letzten 24 Stunden",
      """

      ==============================

      Hallo,

      in den letzten 24 Stunden #{user_word} sich #{count} neue
      #{if count == 1, do: "Nutzer", else: "Nutzer"} bei ANIMINA registriert und per PIN bestätigt.

      ==============================
      """
    )
  end

  @doc """
  Deliver a warning email when someone tries to register with an email
  that already belongs to an existing account.
  """
  def deliver_duplicate_registration_warning(email) when is_binary(email) do
    deliver(email, "Sicherheitshinweis – ANIMINA", """

    ==============================

    Hallo,

    jemand hat versucht, ein neues ANIMINA-Konto mit deiner
    E-Mail-Adresse (#{email}) zu erstellen.

    Falls du das nicht warst, empfehlen wir dir, dein Passwort
    zu ändern, um dein Konto zu schützen.

    Falls du dich gerade selbst registrieren wolltest:
    Du hast bereits ein Konto. Bitte melde dich mit deinem
    bestehenden Passwort an oder nutze die Passwort-vergessen-
    Funktion.

    ==============================
    """)
  end
end
