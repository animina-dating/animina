defmodule Animina.Scheduler do
  @moduledoc """
  Quantum-based cron scheduler for periodic background jobs.
  """

  use Quantum, otp_app: :animina
end
