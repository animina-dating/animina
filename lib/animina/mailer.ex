defmodule Animina.Mailer do
  use Swoosh.Mailer, otp_app: :animina

  # @moduledoc """
  #   This module contains functions for sending emails notifications

  # """
  # # alias Swoosh.Email
  # import Swoosh.Email

  # @from "system@animina.de"

  # def send_confirmation_email(user) do
  #   new()
  #   |> to(user.email)
  #   |> from(@from)
  #   |> subject("Confirmation Email")
  #   |> text_body("Hello #{user.name}, please confirm your email by clicking the link.")
  #   |> deliver()
  # end

  # def test() do
  #   new()
  #   |> to({"Test", "test@example.com"})
  #   |> from({"Dr B Banner", "hulk.smash@example.com"})
  #   |> subject("Hello, Avengers!")
  #   |> html_body("<h1>Hello </h1>")
  #   |> text_body("Hello \n")
  # end
end
