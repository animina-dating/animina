defmodule Animina.Repo.Migrations.RemoveSexPositivityFlag do
  use Ecto.Migration

  def up do
    execute("""
    DELETE FROM user_flags
    WHERE flag_id IN (
      SELECT id FROM trait_flags WHERE name = 'Sex Positivity'
    )
    """)

    execute("DELETE FROM trait_flags WHERE name = 'Sex Positivity'")
  end

  def down do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    [{cat_id}] =
      repo().query!("SELECT id FROM trait_categories WHERE name = 'Self Care'").rows

    repo().insert_all("trait_flags", [
      %{
        id: Ecto.UUID.dump!(Ecto.UUID.generate()),
        name: "Sex Positivity",
        emoji: "❤️‍🔥",
        category_id: cat_id,
        parent_id: nil,
        position: 7,
        inserted_at: now,
        updated_at: now
      }
    ])
  end
end
