defmodule Animina.Repo do
  use AshPostgres.Repo, otp_app: :animina

  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end
