defmodule Animina.Repo do
  use Ecto.Repo,
    otp_app: :animina,
    adapter: Ecto.Adapters.Postgres
end
