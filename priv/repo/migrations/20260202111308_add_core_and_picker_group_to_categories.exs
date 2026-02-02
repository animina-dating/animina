defmodule Animina.Repo.Migrations.AddCoreAndPickerGroupToCategories do
  use Ecto.Migration

  def up do
    alter table(:trait_categories) do
      add :core, :boolean, default: false, null: false
      add :picker_group, :string
    end

    flush()

    # Set core = true for the 9 core categories
    execute("""
    UPDATE trait_categories SET core = true
    WHERE name IN (
      'Relationship Status',
      'What I''m Looking For',
      'Character',
      'Have Children',
      'Want Children',
      'Children in Household',
      'Diet',
      'Smoking',
      'Alcohol'
    )
    """)

    # Set picker_group for opt-in categories
    # Lifestyle
    execute("""
    UPDATE trait_categories SET picker_group = 'lifestyle'
    WHERE name IN ('Pets', 'Food', 'Sports', 'Self Care')
    """)

    # Interests
    execute("""
    UPDATE trait_categories SET picker_group = 'interests'
    WHERE name IN ('Music', 'Literature', 'At Home', 'Creativity')
    """)

    # Going Out & Travels
    execute("""
    UPDATE trait_categories SET picker_group = 'going_out'
    WHERE name IN ('Going Out', 'Travels', 'Favorite Destinations')
    """)

    # Sensitive
    execute("""
    UPDATE trait_categories SET picker_group = 'sensitive'
    WHERE name IN ('Marijuana', 'Political Parties', 'Religion', 'Sexual Preferences', 'Sexual Practices')
    """)

    # Update positions to the new order
    execute("""
    UPDATE trait_categories SET position = CASE name
      WHEN 'Relationship Status' THEN 1
      WHEN 'What I''m Looking For' THEN 2
      WHEN 'Character' THEN 3
      WHEN 'Have Children' THEN 4
      WHEN 'Want Children' THEN 5
      WHEN 'Children in Household' THEN 6
      WHEN 'Diet' THEN 7
      WHEN 'Smoking' THEN 8
      WHEN 'Alcohol' THEN 9
      WHEN 'Pets' THEN 10
      WHEN 'Food' THEN 11
      WHEN 'Sports' THEN 12
      WHEN 'Self Care' THEN 13
      WHEN 'Music' THEN 14
      WHEN 'Literature' THEN 15
      WHEN 'At Home' THEN 16
      WHEN 'Creativity' THEN 17
      WHEN 'Going Out' THEN 18
      WHEN 'Travels' THEN 19
      WHEN 'Favorite Destinations' THEN 20
      WHEN 'Marijuana' THEN 21
      WHEN 'Political Parties' THEN 22
      WHEN 'Religion' THEN 23
      WHEN 'Sexual Preferences' THEN 24
      WHEN 'Sexual Practices' THEN 25
      ELSE position
    END
    """)

    # Auto-create user_category_opt_ins for existing users who have flags
    # in non-core categories, so their wizard experience is preserved
    execute("""
    INSERT INTO user_category_opt_ins (id, user_id, category_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), uf.user_id, f.category_id, NOW(), NOW()
    FROM user_flags uf
    JOIN trait_flags f ON f.id = uf.flag_id
    JOIN trait_categories c ON c.id = f.category_id
    WHERE c.core = false
    GROUP BY uf.user_id, f.category_id
    ON CONFLICT (user_id, category_id) DO NOTHING
    """)
  end

  def down do
    alter table(:trait_categories) do
      remove :core
      remove :picker_group
    end
  end
end
