defmodule Animina.Accounts.UserNotifier do
  import Swoosh.Email

  alias Animina.Accounts.EmailTemplates
  alias Animina.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    config = Application.fetch_env!(:animina, :email_sender)

    email =
      new()
      |> to(recipient)
      |> from({config[:name], config[:address]})
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
    {subject, body} =
      EmailTemplates.render(user_locale(user), :update_email,
        email: user.email,
        display_name: user.display_name,
        url: url
      )

    deliver(user.email, subject, body)
  end

  @doc """
  Deliver password reset instructions to the user's email.
  """
  def deliver_password_reset_instructions(user, url) do
    {subject, body} =
      EmailTemplates.render(user_locale(user), :password_reset,
        email: user.email,
        display_name: user.display_name,
        url: url
      )

    deliver(user.email, subject, body)
  end

  @doc """
  Deliver a 6-digit confirmation PIN to the user's email.
  """
  def deliver_confirmation_pin(user, pin) do
    {subject, body} =
      EmailTemplates.render(user_locale(user), :confirmation_pin,
        email: user.email,
        display_name: user.display_name,
        pin: pin
      )

    deliver(user.email, subject, body)
  end

  @doc """
  Deliver a daily report of newly registered and confirmed users.
  `count` is the number of new users, `recipient` is a `{name, email}` tuple.
  """
  def deliver_daily_new_users_report(count, {_name, email}) do
    # Admin report is always in German
    {subject, body} = EmailTemplates.render("de", :daily_report, count: count)
    deliver(email, subject, body)
  end

  @doc """
  Deliver a warning email when someone tries to register with an email
  that already belongs to an existing account.
  """
  def deliver_duplicate_registration_warning(email) when is_binary(email) do
    user = Animina.Accounts.get_user_by_email(email)

    {subject, body} =
      EmailTemplates.render(user_locale(user), :duplicate_registration,
        email: email,
        display_name: user_display_name(user)
      )

    deliver(email, subject, body)
  end

  defp user_display_name(%{display_name: name}) when is_binary(name), do: name
  defp user_display_name(_), do: nil
end
