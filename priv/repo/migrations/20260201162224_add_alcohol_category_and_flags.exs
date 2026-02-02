defmodule Animina.Repo.Migrations.AddAlcoholCategoryAndFlags do
  use Ecto.Migration

  def up do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    {:ok, cat_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

    repo().insert_all("trait_categories", [
      %{
        id: cat_bin,
        name: "Alcohol",
        selection_mode: "single",
        sensitive: true,
        position: 20,
        inserted_at: now,
        updated_at: now
      }
    ])

    flags = [
      {"🚫", "None at All", 1},
      {"🥂", "Rarely", 2},
      {"🍷", "Sometimes", 3},
      {"🍻", "Often", 4}
    ]

    flag_rows =
      Enum.map(flags, fn {emoji, name, position} ->
        {:ok, bin} = Ecto.UUID.dump(Ecto.UUID.generate())

        %{
          id: bin,
          name: name,
          emoji: emoji,
          category_id: cat_bin,
          parent_id: nil,
          position: position,
          inserted_at: now,
          updated_at: now
        }
      end)

    repo().insert_all("trait_flags", flag_rows)
  end

  def down do
    # Find the category by name and delete its flags, then the category
    cat_query = "SELECT id FROM trait_categories WHERE name = 'Alcohol'"
    %{rows: rows} = repo().query!(cat_query)

    for [cat_id] <- rows do
      repo().query!("DELETE FROM trait_flags WHERE category_id = $1", [cat_id])
      repo().query!("DELETE FROM trait_categories WHERE id = $1", [cat_id])
    end
  end
end
