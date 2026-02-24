# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Animina.Repo.insert!(%Animina.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# In development, seed 114 test accounts with full profiles
if Mix.env() == :dev do
  for file <- ~w(personas.ex stories.ex profiles.ex seeder.ex) do
    Code.require_file("dev_seeds/#{file}", __DIR__)
  end

  Animina.Seeds.DevUsers.seed_all()
end
