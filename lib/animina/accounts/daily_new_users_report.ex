defmodule Animina.Accounts.DailyNewUsersReport do
  @moduledoc """
  Quantum job that sends a daily email report of newly registered
  and confirmed users from the last 24 hours.
  """

  require Logger

  alias Animina.Accounts
  alias Animina.Accounts.UserNotifier

  @recipient {"Stefan Wintermeyer", "sw@wintermeyer-consulting.de"}

  def run do
    count = Accounts.count_confirmed_users_last_24h()

    if count > 0 do
      Logger.info(
        "DailyNewUsersReport: #{count} new confirmed user(s) in the last 24h, sending email"
      )

      UserNotifier.deliver_daily_new_users_report(count, @recipient)
    else
      Logger.info("DailyNewUsersReport: no new confirmed users in the last 24h, skipping email")
      :ok
    end
  end
end
