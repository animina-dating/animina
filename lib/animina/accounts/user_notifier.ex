defmodule Animina.Accounts.UserNotifier do
  import Swoosh.Email

  alias Animina.Mailer
  alias Animina.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Animina", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

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
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

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
end
