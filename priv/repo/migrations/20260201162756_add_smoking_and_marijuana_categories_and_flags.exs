defmodule Animina.Repo.Migrations.AddSmokingAndMarijuanaCategoriesAndFlags do
  use Ecto.Migration

  def up do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    categories = [
      {"Smoking", 21},
      {"Marijuana", 22}
    ]

    cat_rows =
      Enum.map(categories, fn {name, position} ->
        {:ok, bin} = Ecto.UUID.dump(Ecto.UUID.generate())

        %{
          id: bin,
          name: name,
          selection_mode: "single",
          sensitive: true,
          position: position,
          inserted_at: now,
          updated_at: now
        }
      end)

    repo().insert_all("trait_categories", cat_rows)

    cat_map = Map.new(cat_rows, fn row -> {row.name, row.id} end)

    flags = [
      {"Smoking", "🚫", "None at All", 1},
      {"Smoking", "🚬", "Rarely", 2},
      {"Smoking", "🚬", "Sometimes", 3},
      {"Smoking", "🚬", "Often", 4},
      {"Marijuana", "🚫", "None at All", 1},
      {"Marijuana", "🌿", "Rarely", 2},
      {"Marijuana", "🌿", "Sometimes", 3},
      {"Marijuana", "🌿", "Often", 4}
    ]

    flag_rows =
      Enum.map(flags, fn {cat_name, emoji, name, position} ->
        {:ok, bin} = Ecto.UUID.dump(Ecto.UUID.generate())

        %{
          id: bin,
          name: name,
          emoji: emoji,
          category_id: Map.fetch!(cat_map, cat_name),
          parent_id: nil,
          position: position,
          inserted_at: now,
          updated_at: now
        }
      end)

    repo().insert_all("trait_flags", flag_rows)
  end

  def down do
    for name <- ["Smoking", "Marijuana"] do
      cat_query = "SELECT id FROM trait_categories WHERE name = $1"
      %{rows: rows} = repo().query!(cat_query, [name])

      for [cat_id] <- rows do
        repo().query!("DELETE FROM trait_flags WHERE category_id = $1", [cat_id])
        repo().query!("DELETE FROM trait_categories WHERE id = $1", [cat_id])
      end
    end
  end
end
