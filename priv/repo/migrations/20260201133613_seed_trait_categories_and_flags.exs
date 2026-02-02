defmodule Animina.Repo.Migrations.SeedTraitCategoriesAndFlags do
  use Ecto.Migration

  def up do
    now = DateTime.utc_now(:second) |> DateTime.truncate(:second)

    # Categories: {name, selection_mode, sensitive, position}
    categories = [
      {"Character", "multi", false, 1},
      {"Have Children", "single", false, 2},
      {"Want Children", "single", false, 3},
      {"Children in Household", "single", false, 4},
      {"Diet", "single", false, 5},
      {"Substance Use", "multi", true, 6},
      {"Animals", "multi", false, 7},
      {"Food", "multi", false, 8},
      {"Sports", "multi", false, 9},
      {"Travels", "multi", false, 10},
      {"Favorite Destinations", "multi", false, 11},
      {"Music", "multi", false, 12},
      {"Literature", "multi", false, 13},
      {"At Home", "multi", false, 14},
      {"Creativity", "multi", false, 15},
      {"Going Out", "multi", false, 16},
      {"Self Care", "multi", false, 17},
      {"Politics", "single", true, 18},
      {"Religion", "single", true, 19}
    ]

    category_rows =
      Enum.map(categories, fn {name, selection_mode, sensitive, position} ->
        {:ok, bin} = Ecto.UUID.dump(Ecto.UUID.generate())

        %{
          id: bin,
          name: name,
          selection_mode: selection_mode,
          sensitive: sensitive,
          position: position,
          inserted_at: now,
          updated_at: now
        }
      end)

    repo().insert_all("trait_categories", category_rows)

    # Build a lookup map: name -> id (binary)
    cat_map = Map.new(category_rows, fn row -> {row.name, row.id} end)

    # Flags: {category_name, emoji, flag_name, position}
    flags = [
      # Character (20)
      {"Character", "🌼", "Modesty", 1},
      {"Character", "⚖️", "Sense of Justice", 2},
      {"Character", "🤝", "Honesty", 3},
      {"Character", "🦁", "Courage", 4},
      {"Character", "🪨", "Resilience", 5},
      {"Character", "🔑", "Sense of Responsibility", 6},
      {"Character", "😄", "Humor", 7},
      {"Character", "💖", "Caring", 8},
      {"Character", "🎁", "Generosity", 9},
      {"Character", "🤗", "Self-Acceptance", 10},
      {"Character", "👨‍👩‍👧‍👦", "Family-Oriented", 11},
      {"Character", "🧠", "Intelligence", 12},
      {"Character", "🌍", "Love of Adventure", 13},
      {"Character", "🏃", "Active", 14},
      {"Character", "💞", "Empathy", 15},
      {"Character", "🎨", "Creativity", 16},
      {"Character", "☀️", "Optimism", 17},
      {"Character", "💐", "Being Romantic", 18},
      {"Character", "💪", "Self-Confidence", 19},
      {"Character", "🌐", "Social Awareness", 20},
      # Have Children (2)
      {"Have Children", "👨‍👩‍👧‍👦", "I Have Children", 1},
      {"Have Children", "🚫👶", "I Don't Have Children", 2},
      # Want Children (2)
      {"Want Children", "👶✨", "I Want (More) Children", 1},
      {"Want Children", "🚫👶", "I Don't Want (More) Children", 2},
      # Children in Household (2)
      {"Children in Household", "🏠👨‍👩‍👧‍👦", "My Children Live With Me", 1},
      {"Children in Household", "🏠", "My Children Don't Live With Me", 2},
      # Diet (5)
      {"Diet", "🍖", "Omnivore", 1},
      {"Diet", "🥗", "Flexitarian", 2},
      {"Diet", "🐟", "Pescatarian", 3},
      {"Diet", "🥦", "Vegetarian", 4},
      {"Diet", "🌱", "Vegan", 5},
      # Substance Use (5)
      {"Substance Use", "🚬", "Smoking", 1},
      {"Substance Use", "🍻", "Alcohol", 2},
      {"Substance Use", "🌿", "Marijuana", 3},
      {"Substance Use", "💊", "Hard Drugs", 4},
      {"Substance Use", "💉", "Prescription Drug Misuse", 5},
      # Animals (10)
      {"Animals", "🐶", "Dog", 1},
      {"Animals", "🐱", "Cat", 2},
      {"Animals", "🐭", "Mouse", 3},
      {"Animals", "🐰", "Rabbit", 4},
      {"Animals", "🐹", "Guinea Pig", 5},
      {"Animals", "🐹", "Hamster", 6},
      {"Animals", "🐦", "Bird", 7},
      {"Animals", "🐠", "Fish", 8},
      {"Animals", "🦎", "Reptile", 9},
      {"Animals", "🐴", "Horse", 10},
      # Food (22)
      {"Food", "🍝", "Italian", 1},
      {"Food", "🥡", "Chinese", 2},
      {"Food", "🍛", "Indian", 3},
      {"Food", "🥖", "French", 4},
      {"Food", "🥘", "Spanish", 5},
      {"Food", "🌮", "Mexican", 6},
      {"Food", "🍣", "Japanese", 7},
      {"Food", "🍢", "Turkish", 8},
      {"Food", "🍲", "Thai", 9},
      {"Food", "🥙", "Greek", 10},
      {"Food", "🍔", "American", 11},
      {"Food", "🍜", "Vietnamese", 12},
      {"Food", "🍚", "Korean", 13},
      {"Food", "🌭", "German", 14},
      {"Food", "🍇", "Mediterranean", 15},
      {"Food", "🍟", "Fast Food", 16},
      {"Food", "🥡", "Street Food", 17},
      {"Food", "🥗", "Healthy Food", 18},
      {"Food", "🍰", "Desserts", 19},
      {"Food", "🥐", "Pastries", 20},
      {"Food", "🍖", "BBQ", 21},
      {"Food", "🍿", "Snacks", 22},
      # Sports (27)
      {"Sports", "⚽", "Soccer", 1},
      {"Sports", "🤸", "Gymnastics", 2},
      {"Sports", "🎾", "Tennis", 3},
      {"Sports", "🥾", "Hiking", 4},
      {"Sports", "🧗", "Climbing", 5},
      {"Sports", "⛷", "Skiing", 6},
      {"Sports", "🏃", "Athletics", 7},
      {"Sports", "🤾", "Handball", 8},
      {"Sports", "🏇", "Horse Riding", 9},
      {"Sports", "⛳", "Golf", 10},
      {"Sports", "🏊", "Swimming", 11},
      {"Sports", "🏐", "Volleyball", 12},
      {"Sports", "🏀", "Basketball", 13},
      {"Sports", "🏒", "Ice Hockey", 14},
      {"Sports", "🏓", "Table Tennis", 15},
      {"Sports", "🏸", "Badminton", 16},
      {"Sports", "🧘", "Yoga", 17},
      {"Sports", "🤿", "Diving", 18},
      {"Sports", "🏄", "Surfing", 19},
      {"Sports", "⛵", "Sailing", 20},
      {"Sports", "🚣", "Rowing", 21},
      {"Sports", "🥊", "Boxing", 22},
      {"Sports", "🚴", "Cycling", 23},
      {"Sports", "🏃‍♂️", "Jogging", 24},
      {"Sports", "🤸‍♀️", "Pilates", 25},
      {"Sports", "🏋️", "Gym", 26},
      {"Sports", "🥋", "Martial Arts", 27},
      # Travels (10)
      {"Travels", "🏖️", "Beach", 1},
      {"Travels", "🏙️", "City Trips", 2},
      {"Travels", "🥾", "Hiking Vacation", 3},
      {"Travels", "🚢", "Cruises", 4},
      {"Travels", "🚴", "Bike Tours", 5},
      {"Travels", "🧘‍♀️", "Wellness", 6},
      {"Travels", "🏋️‍♂️", "Active and Sports Vacation", 7},
      {"Travels", "🏕️", "Camping", 8},
      {"Travels", "🕌", "Cultural Trips", 9},
      {"Travels", "🏂", "Winter Sports", 10},
      # Favorite Destinations (27)
      {"Favorite Destinations", "🇪🇺", "Europe", 1},
      {"Favorite Destinations", "🌏", "Asia", 2},
      {"Favorite Destinations", "🌍", "Africa", 3},
      {"Favorite Destinations", "🌎", "North America", 4},
      {"Favorite Destinations", "🌎", "South America", 5},
      {"Favorite Destinations", "🇦🇺", "Australia", 6},
      {"Favorite Destinations", "❄️", "Antarctica", 7},
      {"Favorite Destinations", "🇪🇸", "Spain", 8},
      {"Favorite Destinations", "🇮🇹", "Italy", 9},
      {"Favorite Destinations", "🇹🇷", "Turkey", 10},
      {"Favorite Destinations", "🇦🇹", "Austria", 11},
      {"Favorite Destinations", "🇬🇷", "Greece", 12},
      {"Favorite Destinations", "🇫🇷", "France", 13},
      {"Favorite Destinations", "🇭🇷", "Croatia", 14},
      {"Favorite Destinations", "🇩🇪", "Germany", 15},
      {"Favorite Destinations", "🇹🇭", "Thailand", 16},
      {"Favorite Destinations", "🇺🇸", "USA", 17},
      {"Favorite Destinations", "🇵🇹", "Portugal", 18},
      {"Favorite Destinations", "🇨🇭", "Switzerland", 19},
      {"Favorite Destinations", "🇳🇱", "Netherlands", 20},
      {"Favorite Destinations", "🇪🇬", "Egypt", 21},
      {"Favorite Destinations", "🌴", "Canary Islands", 22},
      {"Favorite Destinations", "🏝️", "Mallorca", 23},
      {"Favorite Destinations", "🌺", "Bali", 24},
      {"Favorite Destinations", "🇳🇴", "Norway", 25},
      {"Favorite Destinations", "🇨🇦", "Canada", 26},
      {"Favorite Destinations", "🇬🇧", "United Kingdom", 27},
      # Music (23)
      {"Music", "🎤", "Pop", 1},
      {"Music", "🎸", "Rock", 2},
      {"Music", "🧢", "Hip-Hop", 3},
      {"Music", "🎙️", "Rap", 4},
      {"Music", "🎛️", "Techno", 5},
      {"Music", "🍻", "Schlager", 6},
      {"Music", "🎻", "Classical", 7},
      {"Music", "🎷", "Jazz", 8},
      {"Music", "🤘", "Heavy Metal", 9},
      {"Music", "👓", "Indie", 10},
      {"Music", "🪕", "Folk", 11},
      {"Music", "🏞️", "Folk Music", 12},
      {"Music", "🎵", "Blues", 13},
      {"Music", "🇯🇲", "Reggae", 14},
      {"Music", "💖", "Soul", 15},
      {"Music", "🤠", "Country", 16},
      {"Music", "💿", "R&B", 17},
      {"Music", "🔊", "Electronic", 18},
      {"Music", "🏠🎶", "House", 19},
      {"Music", "💃", "Dance", 20},
      {"Music", "🕺", "Latin", 21},
      {"Music", "🧷", "Punk", 22},
      {"Music", "🚀", "Alternative", 23},
      # Literature (20)
      {"Literature", "🔍", "Crime", 1},
      {"Literature", "📚", "Novels", 2},
      {"Literature", "❤️", "Romance Novels", 3},
      {"Literature", "🏰", "Historical Novels", 4},
      {"Literature", "🐉", "Fantasy", 5},
      {"Literature", "🚀", "Science Fiction", 6},
      {"Literature", "📘", "Non-Fiction", 7},
      {"Literature", "👤", "Biographies", 8},
      {"Literature", "💋", "Erotica", 9},
      {"Literature", "👧👦", "Children's and Young Adult", 10},
      {"Literature", "😄", "Humor", 11},
      {"Literature", "📖", "Classics", 12},
      {"Literature", "👻", "Horror", 13},
      {"Literature", "📙", "Guidebooks", 14},
      {"Literature", "🍂", "Poetry", 15},
      {"Literature", "🌍", "Adventure", 16},
      {"Literature", "💭", "Philosophy", 17},
      {"Literature", "💣", "Thriller", 18},
      {"Literature", "🧠", "Psychology", 19},
      {"Literature", "🔬", "Science", 20},
      # At Home (19)
      {"At Home", "🍳", "Cooking", 1},
      {"At Home", "🍰", "Baking", 2},
      {"At Home", "📖", "Reading", 3},
      {"At Home", "🎬", "Movies", 4},
      {"At Home", "📺", "Series", 5},
      {"At Home", "💻", "Online Courses", 6},
      {"At Home", "🏋️‍♂️", "Fitness Exercises", 7},
      {"At Home", "🌱", "Gardening", 8},
      {"At Home", "🧵", "Handicrafts", 9},
      {"At Home", "🎨", "Drawing", 10},
      {"At Home", "🎵", "Music", 11},
      {"At Home", "🧩", "Puzzles", 12},
      {"At Home", "🎲", "Board Games", 13},
      {"At Home", "🧘", "Meditation", 14},
      {"At Home", "🔨", "DIY Projects", 15},
      {"At Home", "📓", "Journaling", 16},
      {"At Home", "🎧", "Podcasts", 17},
      {"At Home", "🔊", "Audiobooks", 18},
      {"At Home", "🎮", "Video Games", 19},
      # Creativity (16)
      {"Creativity", "📷", "Photography", 1},
      {"Creativity", "🎨", "Design", 2},
      {"Creativity", "🧶", "Crafting", 3},
      {"Creativity", "🖌️", "Art", 4},
      {"Creativity", "💄", "Make-up", 5},
      {"Creativity", "✍️", "Writing", 6},
      {"Creativity", "🎤", "Singing", 7},
      {"Creativity", "💃", "Dancing", 8},
      {"Creativity", "🎥", "Video Production", 9},
      {"Creativity", "📱", "Social Media", 10},
      {"Creativity", "🎶", "Making Music", 11},
      {"Creativity", "🎭", "Acting", 12},
      {"Creativity", "🖼️", "Painting", 13},
      {"Creativity", "🧵", "Crocheting", 14},
      {"Creativity", "🧶", "Knitting", 15},
      {"Creativity", "🪡", "Sewing", 16},
      # Going Out (11)
      {"Going Out", "🍹", "Bars", 1},
      {"Going Out", "☕", "Cafes", 2},
      {"Going Out", "🎉", "Clubbing", 3},
      {"Going Out", "💃", "Drag Shows", 4},
      {"Going Out", "🎪", "Festivals", 5},
      {"Going Out", "🎤", "Karaoke", 6},
      {"Going Out", "🎵", "Concerts", 7},
      {"Going Out", "🌈", "LGBTQ+ Nightlife", 8},
      {"Going Out", "🖼️", "Museums & Galleries", 9},
      {"Going Out", "😆", "Stand-Up Comedy", 10},
      {"Going Out", "🎭", "Theater", 11},
      # Self Care (7)
      {"Self Care", "😴", "Good Sleep", 1},
      {"Self Care", "💬", "Deep Conversations", 2},
      {"Self Care", "🧘", "Mindfulness", 3},
      {"Self Care", "👥", "Counseling", 4},
      {"Self Care", "🍏", "Nutrition", 5},
      {"Self Care", "📵", "Going Offline", 6},
      {"Self Care", "❤️‍🔥", "Sex Positivity", 7},
      # Politics (7)
      {"Politics", "-", "CDU", 1},
      {"Politics", "-", "SPD", 2},
      {"Politics", "-", "Die Grünen", 3},
      {"Politics", "-", "FDP", 4},
      {"Politics", "-", "AfD", 5},
      {"Politics", "-", "The Left", 6},
      {"Politics", "-", "CSU", 7},
      # Religion (10)
      {"Religion", "✝️", "Roman Catholic", 1},
      {"Religion", "✝️", "Protestant", 2},
      {"Religion", "☦️", "Orthodox Christianity", 3},
      {"Religion", "☪️", "Islam", 4},
      {"Religion", "✡️", "Judaism", 5},
      {"Religion", "☸️", "Buddhism", 6},
      {"Religion", "🕉️", "Hinduism", 7},
      {"Religion", "⚛️", "Atheism", 8},
      {"Religion", "❓", "Agnosticism", 9},
      {"Religion", "🕊️", "Spirituality", 10}
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

    # Insert in chunks to avoid hitting parameter limits
    flag_rows
    |> Enum.chunk_every(50)
    |> Enum.each(fn chunk ->
      repo().insert_all("trait_flags", chunk)
    end)
  end

  def down do
    repo().delete_all("trait_flags")
    repo().delete_all("trait_categories")
  end
end
