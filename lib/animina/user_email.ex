defmodule Animina.UserEmail do
  @moduledoc """
  This module provides the functionality to send emails.
  """

  import Swoosh.Email
  import AniminaWeb.Gettext
  import Gettext, only: [with_locale: 2]
  alias Animina.Mailer

  def send_pin(name, email, pin, language) do
    subject = with_locale(language, fn -> gettext("👫❤️ Confirm your ANIMINA account") end)

    body =
      construct_salutation(name) <>
        construct_email_body(pin, language) <>
        construct_signature(language)

    send_email(
      name,
      Ash.CiString.value(email),
      subject,
      body
    )
  end

  defp construct_salutation(name) do
    "Hi #{name}!\n"
  end

  defp construct_email_body(pin, language) do
    "

    #{with_locale(language, fn -> gettext("Please use this PIN to verify your new ANIMINA account.") end)}


    #{pin}


    #{with_locale(language, fn -> gettext("If you didn't create an account just do nothing. We will auto delete the entry within 24 hours.") end)}


    "
  end

  defp construct_signature(language) do
    "


   #{with_locale(language, fn -> gettext("Best regards") end)},
   #{with_locale(language, fn -> gettext(" ANIMINA Team") end)}

    --
    #{with_locale(language, fn -> gettext("This email was sent by the ANIMINA system. Please do not reply to it.") end)}
    #{with_locale(language, fn -> gettext("I am just dumb software and can't read your emails. Do contact my
    human boss Stefan Wintermeyer <stefan@wintermeyer.de> in case you
    have any questions or concerns.") end)}
    "
  end

  def send_email(
        receiver_name,
        receiver_email,
        subject,
        text_body
      )
      when not is_nil(receiver_name) and not is_nil(receiver_email) and not is_nil(subject) and
             not is_nil(text_body) do
    new()
    |> to({receiver_name, receiver_email})
    |> from({sender_name(), sender_email()})
    |> subject(subject)
    |> text_body(text_body)
    |> Mailer.deliver()
  end

  def send_email(
        receiver_name,
        receiver_email,
        subject,
        text_body,
        html_body
      )
      when not is_nil(receiver_name) and not is_nil(receiver_email) and not is_nil(subject) and
             not is_nil(text_body) and
             not is_nil(html_body) do
    new()
    |> to({receiver_name, receiver_email})
    |> from({sender_name(), sender_email()})
    |> subject(subject)
    |> html_body(html_body)
    |> text_body(text_body)
    |> Mailer.deliver()
  end

  defp sender_name do
    "ANIMINA System"
  end

  defp sender_email do
    "system@animina.de"
  end
end
