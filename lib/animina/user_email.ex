defmodule Animina.UserEmail do
  @moduledoc """
  This module provides the functionality to send emails.
  """

  import Swoosh.Email
  import AniminaWeb.Gettext
  alias Animina.Mailer
  use AshAuthentication.Sender

  def send(user, confirm, _opts) do
    subject = gettext("👫❤️ Confirm your email address")

    body =
      construct_salutation(user) <>
        construct_email_body() <>
        construct_link(confirm) <>
        construct_signature()

    send_email(
      user.name,
      Ash.CiString.value(user.email),
      subject,
      body
    )
  end

  defp construct_salutation(user) do
    "Hi #{user.name}!"
  end

  defp construct_email_body do
    ~S"""

    A new ANIMINA https://animina.de account has been created with this
    email address.

    Please confirm the account by clicking the link below or do nothing
    in case you didn't create the account.

    """
  end

  defp construct_link(confirm) do
    "\n #{" #{get_link(Application.get_env(:animina, :env))}/auth/user/confirm_new_user?#{URI.encode_query(confirm: confirm)}"}" <>
      ~S"""


      """
  end

  defp construct_signature do
    ~S"""
    Best regards,
    ANIMINA Team
    """
  end

  defp get_link(:prod) do
    "https://animina.de"
  end

  defp get_link(_) do
    "http://localhost:4000"
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
