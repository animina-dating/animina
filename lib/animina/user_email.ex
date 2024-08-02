defmodule Animina.UserEmail do
  @moduledoc """
  This module provides the functionality to send emails.
  """

  import Swoosh.Email
  alias Animina.Mailer
  use AshAuthentication.Sender


  # def send(user, confirm, _opts) do
  #   IO.inspect user
  #   IO.inspect confirm
  # end

  def test do
    send_email(
      "Stefan Wintermeyer",
      "stefan@wintermeyer.de",
      "This is a test",
      "Hi,\n\njust a test.\n\n-- \nAnimina System\nhttps://animina.de"
    )
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
