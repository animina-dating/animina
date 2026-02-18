# Development seed data for testing
# This file is only loaded in dev environment via seeds.exs

defmodule Animina.Seeds.DevUsers do
  @moduledoc """
  Seeds development test accounts with full profiles, traits, and moodboards.
  95 unique personas with coherent traits and topic-matched moodboard content.
  All accounts use the password "password12345" and are located in Koblenz (56068).
  Avatars use real Unsplash photos stored in priv/static/images/seeds/avatars/.
  """

  import Ecto.Query

  alias Animina.Accounts
  alias Animina.Accounts.ContactBlacklist
  alias Animina.GeoData
  alias Animina.Moodboard
  alias Animina.Photos
  alias Animina.Repo
  alias Animina.Traits

  @password "password12345"
  @zip_code "56068"

  # ==========================================================================
  # PERSONA DEFINITIONS (95 unique users)
  # Thomas MUST be at index 0 for V2 discovery test compatibility
  # (V2 tests reference his phone +4915010000000 and email dev-thomas@animina.test).
  #
  # Fields:
  #   name, last_name, gender, age, avatar (filename stem → avatar-dev-{stem}.jpg)
  #   profile (index into @personality_profiles), topics (for moodboard matching)
  #   roles (optional, default []), waitlisted (optional, default false)
  #   height (optional, random if not set)
  # ==========================================================================
  @personas [
    # Thomas first — V2 discovery test anchor (profile 0 = Adventurer with Hiking/Surfing/Camping/Rock + hard-red Vegan)
    %{name: "Thomas", last_name: "Friedrich", gender: "male", age: 32, avatar: "thomas", profile: 0, topics: [:hiking, :books, :mountains], roles: [:admin], height: 186},
    # --- Males (47 more) ---
    %{name: "Karim", last_name: "Hassan", gender: "male", age: 26, avatar: "karim", profile: 6, topics: [:music, :travel, :coffee]},
    %{name: "Raj", last_name: "Sharma", gender: "male", age: 25, avatar: "raj", profile: 16, topics: [:coffee, :books, :music]},
    %{name: "Wei", last_name: "Chen", gender: "male", age: 24, avatar: "wei", profile: 3, topics: [:books, :coffee, :art]},
    %{name: "Marko", last_name: "Petrovic", gender: "male", age: 25, avatar: "marko", profile: 10, topics: [:cycling, :hiking, :nature]},
    %{name: "Fynn", last_name: "Scholz", gender: "male", age: 27, avatar: "fynn", profile: 0, topics: [:hiking, :beach, :travel]},
    %{name: "Nico", last_name: "Bauer", gender: "male", age: 24, avatar: "nico", profile: 7, topics: [:music, :travel, :beach]},
    %{name: "Björn", last_name: "Lindqvist", gender: "male", age: 33, avatar: "bjoern", profile: 0, topics: [:hiking, :mountains, :nature]},
    %{name: "Samuel", last_name: "Adeyemi", gender: "male", age: 32, avatar: "samuel", profile: 11, topics: [:music, :art, :coffee]},
    %{name: "Torsten", last_name: "Krüger", gender: "male", age: 34, avatar: "torsten", profile: 12, topics: [:cooking, :food, :coffee]},
    %{name: "Florian", last_name: "Winkler", gender: "male", age: 33, avatar: "florian", profile: 14, topics: [:travel, :beach, :music], roles: [:moderator]},
    %{name: "Jörg", last_name: "Hauser", gender: "male", age: 43, avatar: "joerg", profile: 19, topics: [:cooking, :garden, :nature]},
    %{name: "Viktor", last_name: "Volkov", gender: "male", age: 35, avatar: "viktor", profile: 10, topics: [:cycling, :hiking, :nature]},
    %{name: "David", last_name: "Williams", gender: "male", age: 32, avatar: "david", profile: 18, topics: [:coffee, :books, :travel]},
    %{name: "Lukas", last_name: "Maier", gender: "male", age: 23, avatar: "lukas", profile: 8, topics: [:books, :coffee, :nature], waitlisted: true},
    %{name: "Anton", last_name: "Nowak", gender: "male", age: 24, avatar: "anton", profile: 16, topics: [:coffee, :books, :music]},
    %{name: "Stefan", last_name: "Müller", gender: "male", age: 33, avatar: "stefan", profile: 6, topics: [:music, :travel, :coffee], roles: [:admin]},
    %{name: "Klaus", last_name: "Dietrich", gender: "male", age: 45, avatar: "klaus", profile: 19, topics: [:cooking, :garden, :hiking]},
    %{name: "Emmanuel", last_name: "Asante", gender: "male", age: 24, avatar: "emmanuel", profile: 11, topics: [:music, :art, :coffee]},
    %{name: "Finn", last_name: "Reuter", gender: "male", age: 23, avatar: "finn", profile: 2, topics: [:art, :music, :nature]},
    %{name: "Henning", last_name: "Stark", gender: "male", age: 34, avatar: "henning", profile: 17, topics: [:cooking, :books, :music]},
    %{name: "Robin", last_name: "Kraft", gender: "male", age: 24, avatar: "robin", profile: 11, topics: [:music, :art, :coffee]},
    %{name: "Rafael", last_name: "Santos", gender: "male", age: 25, avatar: "rafael", profile: 14, topics: [:travel, :beach, :music]},
    %{name: "Tim", last_name: "Schneider", gender: "male", age: 24, avatar: "tim", profile: 0, topics: [:beach, :hiking, :nature]},
    %{name: "Philipp", last_name: "Walter", gender: "male", age: 33, avatar: "philipp", profile: 4, topics: [:cooking, :garden, :pets]},
    %{name: "Tarek", last_name: "El-Amin", gender: "male", age: 25, avatar: "tarek", profile: 6, topics: [:music, :travel, :coffee]},
    %{name: "Moritz", last_name: "Frank", gender: "male", age: 35, avatar: "moritz", profile: 1, topics: [:nature, :hiking, :mountains]},
    %{name: "Wolfgang", last_name: "Behrens", gender: "male", age: 55, avatar: "wolfgang", profile: 19, topics: [:hiking, :garden, :cooking]},
    %{name: "Jan", last_name: "Hofmann", gender: "male", age: 24, avatar: "jan", profile: 2, topics: [:art, :music, :books]},
    %{name: "Diego", last_name: "Alvarez", gender: "male", age: 23, avatar: "diego", profile: 7, topics: [:music, :travel, :beach], waitlisted: true},
    %{name: "Ludwig", last_name: "Stein", gender: "male", age: 24, avatar: "ludwig", profile: 3, topics: [:books, :coffee, :art]},
    %{name: "Matthias", last_name: "Jung", gender: "male", age: 34, avatar: "matthias", profile: 4, topics: [:cooking, :garden, :books]},
    %{name: "Erik", last_name: "Voss", gender: "male", age: 22, avatar: "erik", profile: 15, topics: [:yoga, :nature, :coffee]},
    %{name: "Carlos", last_name: "Rivera", gender: "male", age: 25, avatar: "carlos", profile: 14, topics: [:travel, :beach, :coffee]},
    %{name: "Osman", last_name: "Çelik", gender: "male", age: 33, avatar: "osman", profile: 12, topics: [:cooking, :food, :coffee]},
    %{name: "Sven", last_name: "Andersen", gender: "male", age: 24, avatar: "sven", profile: 0, topics: [:beach, :hiking, :travel]},
    %{name: "Felix", last_name: "Lorenz", gender: "male", age: 25, avatar: "felix", profile: 6, topics: [:music, :travel, :coffee]},
    %{name: "Ben", last_name: "Hartmann", gender: "male", age: 32, avatar: "ben", profile: 17, topics: [:cooking, :books, :nature]},
    %{name: "Patrick", last_name: "Klein", gender: "male", age: 34, avatar: "patrick", profile: 9, topics: [:sunset, :cooking, :coffee]},
    %{name: "Kwame", last_name: "Owusu", gender: "male", age: 33, avatar: "kwame", profile: 2, topics: [:art, :books, :music]},
    %{name: "Hamid", last_name: "Tehrani", gender: "male", age: 44, avatar: "hamid", profile: 5, topics: [:garden, :cooking, :books]},
    %{name: "Marco", last_name: "Conti", gender: "male", age: 33, avatar: "marco", profile: 10, topics: [:cycling, :hiking, :nature]},
    %{name: "Arjun", last_name: "Patel", gender: "male", age: 27, avatar: "arjun", profile: 16, topics: [:coffee, :books, :music]},
    %{name: "Samir", last_name: "Mansour", gender: "male", age: 25, avatar: "samir", profile: 18, topics: [:coffee, :books, :travel]},
    %{name: "Gabriel", last_name: "Costa", gender: "male", age: 26, avatar: "gabriel", profile: 11, topics: [:music, :art, :coffee]},
    %{name: "Leon", last_name: "Weber", gender: "male", age: 24, avatar: "leon", profile: 6, topics: [:music, :travel, :coffee]},
    %{name: "Alessandro", last_name: "Martini", gender: "male", age: 26, avatar: "alessandro", profile: 9, topics: [:sunset, :cooking, :coffee]},
    %{name: "Daniel", last_name: "Park", gender: "male", age: 21, avatar: "daniel", profile: 0, topics: [:hiking, :beach, :nature]},
    # --- Females (47) ---
    %{name: "Sabine", last_name: "Hartmann", gender: "female", age: 32, avatar: "sabine", profile: 18, topics: [:coffee, :books, :travel], roles: [:moderator]},
    %{name: "Nina", last_name: "Schulz", gender: "female", age: 24, avatar: "nina", profile: 0, topics: [:hiking, :beach, :nature]},
    %{name: "Mei", last_name: "Tanaka", gender: "female", age: 26, avatar: "mei", profile: 2, topics: [:art, :coffee, :music]},
    %{name: "Claudia", last_name: "Richter", gender: "female", age: 34, avatar: "claudia", profile: 18, topics: [:books, :coffee, :yoga]},
    %{name: "Amara", last_name: "Okafor", gender: "female", age: 25, avatar: "amara", profile: 6, topics: [:music, :travel, :coffee]},
    %{name: "Ronja", last_name: "Lindgren", gender: "female", age: 23, avatar: "ronja", profile: 13, topics: [:pets, :nature, :garden]},
    %{name: "Hannah", last_name: "Weber", gender: "female", age: 22, avatar: "hannah", profile: 15, topics: [:yoga, :nature, :coffee]},
    %{name: "Svenja", last_name: "Brandt", gender: "female", age: 24, avatar: "svenja", profile: 1, topics: [:hiking, :nature, :yoga]},
    %{name: "Mia", last_name: "Schröder", gender: "female", age: 21, avatar: "mia", profile: 2, topics: [:art, :music, :books], waitlisted: true},
    %{name: "Johanna", last_name: "Fischer", gender: "female", age: 25, avatar: "johanna", profile: 4, topics: [:cooking, :garden, :pets]},
    %{name: "Nora", last_name: "Becker", gender: "female", age: 23, avatar: "nora", profile: 3, topics: [:books, :coffee, :art]},
    %{name: "Vanessa", last_name: "König", gender: "female", age: 24, avatar: "vanessa", profile: 6, topics: [:music, :travel, :beach], waitlisted: true},
    %{name: "Leonie", last_name: "Neumann", gender: "female", age: 22, avatar: "leonie", profile: 7, topics: [:travel, :beach, :music]},
    %{name: "Sophie", last_name: "Baumann", gender: "female", age: 25, avatar: "sophie", profile: 9, topics: [:sunset, :beach, :coffee]},
    %{name: "Greta", last_name: "Vogel", gender: "female", age: 23, avatar: "greta", profile: 1, topics: [:nature, :garden, :hiking]},
    %{name: "Jasmin", last_name: "Yilmaz", gender: "female", age: 26, avatar: "jasmin", profile: 16, topics: [:coffee, :books, :yoga]},
    %{name: "Clara", last_name: "Hoffmann", gender: "female", age: 24, avatar: "clara", profile: 9, topics: [:sunset, :cooking, :books]},
    %{name: "Katharina", last_name: "Engel", gender: "female", age: 33, avatar: "katharina", profile: 18, topics: [:coffee, :travel, :yoga], roles: [:admin]},
    %{name: "Anja", last_name: "Wolff", gender: "female", age: 25, avatar: "anja", profile: 2, topics: [:art, :music, :coffee]},
    %{name: "Eva", last_name: "Seidel", gender: "female", age: 24, avatar: "eva", profile: 3, topics: [:books, :art, :coffee]},
    %{name: "Birgit", last_name: "Krause", gender: "female", age: 35, avatar: "birgit", profile: 12, topics: [:cooking, :food, :coffee]},
    %{name: "Lina", last_name: "Berger", gender: "female", age: 22, avatar: "lina", profile: 13, topics: [:pets, :nature, :hiking]},
    %{name: "Selina", last_name: "Roth", gender: "female", age: 24, avatar: "selina", profile: 7, topics: [:music, :travel, :art], waitlisted: true},
    %{name: "Frieda", last_name: "Lange", gender: "female", age: 23, avatar: "frieda", profile: 1, topics: [:nature, :hiking, :yoga]},
    %{name: "Amelie", last_name: "Huber", gender: "female", age: 24, avatar: "amelie", profile: 15, topics: [:yoga, :nature, :coffee]},
    %{name: "Tanja", last_name: "Schuster", gender: "female", age: 31, avatar: "tanja", profile: 11, topics: [:music, :art, :coffee]},
    %{name: "Fatou", last_name: "Diallo", gender: "female", age: 25, avatar: "fatou", profile: 2, topics: [:art, :music, :books]},
    %{name: "Marie", last_name: "Werner", gender: "female", age: 23, avatar: "marie", profile: 9, topics: [:sunset, :beach, :coffee]},
    %{name: "Layla", last_name: "Khoury", gender: "female", age: 24, avatar: "layla", profile: 0, topics: [:hiking, :beach, :travel]},
    %{name: "Emma", last_name: "Lorenz", gender: "female", age: 23, avatar: "emma", profile: 4, topics: [:cooking, :garden, :pets]},
    %{name: "Julia", last_name: "Meier", gender: "female", age: 26, avatar: "julia", profile: 10, topics: [:cycling, :yoga, :hiking]},
    %{name: "Natasha", last_name: "Petrov", gender: "female", age: 24, avatar: "natasha", profile: 14, topics: [:travel, :beach, :nature]},
    %{name: "Daniela", last_name: "Braun", gender: "female", age: 32, avatar: "daniela", profile: 11, topics: [:music, :coffee, :art]},
    %{name: "Kira", last_name: "Sommer", gender: "female", age: 24, avatar: "kira", profile: 0, topics: [:beach, :hiking, :nature]},
    %{name: "Aisha", last_name: "Mensah", gender: "female", age: 25, avatar: "aisha", profile: 10, topics: [:cycling, :yoga, :nature]},
    %{name: "Petra", last_name: "Zimmermann", gender: "female", age: 42, avatar: "petra", profile: 19, topics: [:cooking, :garden, :nature]},
    %{name: "Lena", last_name: "Bergmann", gender: "female", age: 23, avatar: "lena", profile: 1, topics: [:nature, :hiking, :yoga]},
    %{name: "Carla", last_name: "Rossi", gender: "female", age: 22, avatar: "carla", profile: 6, topics: [:music, :travel, :coffee]},
    %{name: "Anna", last_name: "Lehmann", gender: "female", age: 24, avatar: "anna", profile: 3, topics: [:books, :art, :coffee]},
    %{name: "Yuki", last_name: "Nakamura", gender: "female", age: 25, avatar: "yuki", profile: 12, topics: [:cooking, :food, :travel]},
    %{name: "Teresa", last_name: "Keller", gender: "female", age: 24, avatar: "teresa", profile: 5, topics: [:garden, :cooking, :books]},
    %{name: "Milena", last_name: "Jovanovic", gender: "female", age: 23, avatar: "milena", profile: 15, topics: [:yoga, :nature, :coffee]},
    %{name: "Franzi", last_name: "Horn", gender: "female", age: 24, avatar: "franzi", profile: 2, topics: [:art, :music, :coffee]},
    %{name: "Pia", last_name: "Schwarz", gender: "female", age: 22, avatar: "pia", profile: 7, topics: [:music, :art, :travel]},
    %{name: "Elif", last_name: "Demir", gender: "female", age: 22, avatar: "elif", profile: 9, topics: [:sunset, :coffee, :books]},
    %{name: "Stella", last_name: "Köhler", gender: "female", age: 25, avatar: "stella", profile: 12, topics: [:cooking, :food, :coffee]},
    %{name: "Luisa", last_name: "Wagner", gender: "female", age: 24, avatar: "luisa", profile: 1, topics: [:nature, :hiking, :garden]}
  ]

  # ==========================================================================
  # PERSONALITY PROFILES (20 profiles)
  # Profiles 0-9: Original complementary pairs for discovery scoring.
  # Profiles 10-19: Additional variety profiles.
  # Each profile defines white/green/red flag assignments by category.
  # Flag counts respect limits: white ≤16, green ≤10, red ≤10.
  # White counts below are BEFORE the automatic +1 Deutsch flag.
  # ==========================================================================
  @personality_profiles [
    # Profile 0: Adventurer (7 white, 3 green, 1 red) — V2 anchor profile
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "Character" => ["Love of Adventure", "Courage"],
        "Sports" => ["Hiking", "Surfing"],
        "Travels" => ["Camping"],
        "Music" => ["Rock"]
      },
      green: %{
        "Character" => ["Empathy"],
        "What I'm Looking For" => ["Long-term Relationship"],
        "Sports" => ["Yoga"]
      },
      red: %{
        "Diet" => ["Vegan"]
      }
    },
    # Profile 1: Nature Soul (8 white, 4 green, 2 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship"],
        "Character" => ["Empathy", "Caring"],
        "Sports" => ["Hiking", "Yoga"],
        "Music" => ["Folk", "Classical"]
      },
      green: %{
        "Character" => ["Love of Adventure", "Courage"],
        "Sports" => ["Surfing"],
        "Self Care" => ["Mindfulness"]
      },
      red: %{
        "Music" => ["Hip-Hop"],
        "Sports" => ["Soccer"]
      }
    },
    # Profile 2: Creative (11 white, 5 green, 2 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship"],
        "Character" => ["Creativity", "Intelligence", "Empathy"],
        "Sports" => ["Yoga", "Swimming"],
        "Music" => ["Jazz", "Soul"],
        "Creativity" => ["Painting", "Photography"]
      },
      green: %{
        "Character" => ["Honesty"],
        "Music" => ["Classical"],
        "At Home" => ["Reading", "Podcasts"],
        "Literature" => ["Philosophy"]
      },
      red: %{
        "Music" => ["Schlager"],
        "Travels" => ["Camping"]
      }
    },
    # Profile 3: Intellectual (14 white, 5 green, 2 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship"],
        "Character" => ["Intelligence", "Honesty", "Empathy"],
        "Sports" => ["Swimming", "Jogging"],
        "Music" => ["Classical", "Jazz"],
        "At Home" => ["Reading", "Online Courses", "Podcasts"],
        "Literature" => ["Science", "Philosophy"]
      },
      green: %{
        "Character" => ["Creativity"],
        "Sports" => ["Yoga"],
        "Music" => ["Soul"],
        "Creativity" => ["Painting", "Photography"]
      },
      red: %{
        "Music" => ["Schlager", "Hip-Hop"]
      }
    },
    # Profile 4: Family Person (15 white, 9 green, 1 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship", "Marriage"],
        "Character" => ["Family-Oriented", "Honesty", "Caring"],
        "Want Children" => ["I Want (More) Children"],
        "Sports" => ["Swimming", "Cycling"],
        "Travels" => ["Beach", "Camping"],
        "Music" => ["Pop", "Schlager"],
        "At Home" => ["Cooking", "Baking"]
      },
      green: %{
        "Character" => ["Empathy", "Sense of Responsibility"],
        "Sports" => ["Yoga"],
        "Music" => ["Soul"],
        "At Home" => ["Reading", "Gardening"],
        "Travels" => ["Wellness"],
        "Pets" => ["Dog"],
        "Self Care" => ["Good Sleep"]
      },
      red: %{
        "Want Children" => ["I Don't Want (More) Children"]
      }
    },
    # Profile 5: Caring Partner (15 white, 10 green, 1 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship", "Marriage"],
        "Character" => ["Caring", "Empathy", "Family-Oriented"],
        "Want Children" => ["I Want (More) Children"],
        "Sports" => ["Yoga", "Swimming"],
        "Travels" => ["Beach", "Wellness"],
        "Music" => ["Pop", "Soul"],
        "At Home" => ["Cooking", "Reading"]
      },
      green: %{
        "Character" => ["Honesty", "Generosity", "Sense of Responsibility"],
        "Sports" => ["Cycling"],
        "Travels" => ["Camping"],
        "Music" => ["Schlager"],
        "At Home" => ["Baking", "Gardening"],
        "Self Care" => ["Deep Conversations", "Good Sleep"]
      },
      red: %{
        "Want Children" => ["I Don't Want (More) Children"]
      }
    },
    # Profile 6: Social Star (8 white, 10 green, 2 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship"],
        "Character" => ["Humor", "Self-Confidence", "Active"],
        "Sports" => ["Soccer", "Basketball"],
        "Music" => ["Hip-Hop"]
      },
      green: %{
        "Character" => ["Love of Adventure", "Courage"],
        "Sports" => ["Surfing", "Yoga", "Cycling"],
        "Music" => ["Reggae", "Electronic"],
        "What I'm Looking For" => ["Shared Activities", "Dates"],
        "Going Out" => ["Bars"]
      },
      red: %{
        "Music" => ["Classical", "Folk"]
      }
    },
    # Profile 7: Free Spirit (10 white, 5 green, 9 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship"],
        "Character" => ["Self-Confidence", "Humor", "Love of Adventure"],
        "Sports" => ["Surfing", "Yoga", "Cycling"],
        "Music" => ["Reggae", "Electronic"]
      },
      green: %{
        "Character" => ["Active"],
        "Sports" => ["Soccer", "Basketball"],
        "Music" => ["Hip-Hop"],
        "What I'm Looking For" => ["Something Casual"]
      },
      red: %{
        "Music" => ["Schlager", "Pop", "Classical"],
        "At Home" => ["Cooking", "Puzzles", "Handicrafts"],
        "Going Out" => ["Karaoke"],
        "Literature" => ["Guidebooks", "Romance Novels"]
      }
    },
    # Profile 8: Quiet Thinker (3 white, 4 green, 2 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "Character" => ["Honesty", "Intelligence"]
      },
      green: %{
        "Character" => ["Empathy", "Being Romantic"],
        "Music" => ["Classical"],
        "Sports" => ["Yoga"]
      },
      red: %{
        "Music" => ["Hip-Hop"],
        "Sports" => ["Soccer"]
      }
    },
    # Profile 9: Romantic (15 white, 10 green, 10 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship", "Marriage"],
        "Character" => ["Being Romantic", "Empathy", "Honesty"],
        "Sports" => ["Yoga", "Swimming"],
        "Travels" => ["Beach", "Wellness"],
        "Music" => ["Pop", "Soul", "Classical"],
        "At Home" => ["Cooking", "Movies"]
      },
      green: %{
        "Character" => ["Intelligence", "Caring", "Family-Oriented"],
        "What I'm Looking For" => ["Friendship", "Shared Activities"],
        "At Home" => ["Reading", "Baking"],
        "Self Care" => ["Deep Conversations", "Good Sleep"],
        "Literature" => ["Poetry"]
      },
      red: %{
        "Music" => ["Hip-Hop", "Electronic", "Heavy Metal", "Rap"],
        "Character" => ["Self-Confidence"],
        "Sports" => ["Soccer", "Basketball", "Boxing"],
        "Travels" => ["Camping"],
        "Going Out" => ["Karaoke"]
      }
    },
    # Profile 10: Fitness Fan (6 white, 4 green, 1 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "Character" => ["Active", "Self-Confidence", "Courage"],
        "Sports" => ["Cycling", "Swimming"]
      },
      green: %{
        "Character" => ["Love of Adventure"],
        "Sports" => ["Hiking", "Jogging"],
        "Self Care" => ["Fitness"]
      },
      red: %{
        "Music" => ["Schlager"]
      }
    },
    # Profile 11: Music Lover (7 white, 4 green, 2 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "Character" => ["Creativity", "Humor"],
        "Music" => ["Jazz", "Soul", "Blues"],
        "Creativity" => ["Making Music"]
      },
      green: %{
        "Character" => ["Active"],
        "Music" => ["Rock", "Indie"],
        "Going Out" => ["Concerts"]
      },
      red: %{
        "Music" => ["Schlager", "Heavy Metal"]
      }
    },
    # Profile 12: Foodie (7 white, 4 green, 1 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "Character" => ["Empathy", "Humor"],
        "At Home" => ["Cooking", "Baking"],
        "Food" => ["Italian", "Japanese"]
      },
      green: %{
        "Character" => ["Honesty", "Caring"],
        "Going Out" => ["Restaurants"],
        "At Home" => ["Reading"]
      },
      red: %{
        "Diet" => ["Vegan"]
      }
    },
    # Profile 13: Animal Lover (7 white, 5 green, 1 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "Character" => ["Empathy", "Caring"],
        "Pets" => ["Dog"],
        "Sports" => ["Hiking"],
        "At Home" => ["Gardening"]
      },
      green: %{
        "Character" => ["Family-Oriented", "Honesty"],
        "What I'm Looking For" => ["Long-term Relationship"],
        "Sports" => ["Yoga"],
        "At Home" => ["Reading"]
      },
      red: %{
        "Sports" => ["Boxing"]
      }
    },
    # Profile 14: Traveler (7 white, 4 green, 1 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "Character" => ["Love of Adventure", "Courage", "Active"],
        "Travels" => ["Beach", "City Trips", "Backpacking"]
      },
      green: %{
        "Character" => ["Humor"],
        "Sports" => ["Surfing"],
        "Creativity" => ["Photography"],
        "Music" => ["Pop"]
      },
      red: %{
        "Music" => ["Schlager"]
      }
    },
    # Profile 15: Yoga & Wellness (7 white, 5 green, 1 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "Character" => ["Empathy", "Caring"],
        "Sports" => ["Yoga", "Swimming"],
        "Travels" => ["Wellness"],
        "Self Care" => ["Mindfulness"]
      },
      green: %{
        "Character" => ["Honesty", "Generosity"],
        "Sports" => ["Hiking"],
        "Music" => ["Classical"],
        "Self Care" => ["Good Sleep"]
      },
      red: %{
        "Music" => ["Hip-Hop"]
      }
    },
    # Profile 16: Tech Curious (6 white, 4 green, 1 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "Character" => ["Intelligence", "Active"],
        "At Home" => ["Online Courses", "Podcasts", "Video Games"]
      },
      green: %{
        "Character" => ["Humor", "Honesty"],
        "Sports" => ["Swimming"],
        "Creativity" => ["Photography"]
      },
      red: %{
        "Music" => ["Schlager"]
      }
    },
    # Profile 17: Homebody (7 white, 4 green, 2 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "Character" => ["Honesty", "Empathy"],
        "At Home" => ["Cooking", "Movies", "Video Games"],
        "Literature" => ["Novels", "Thriller"]
      },
      green: %{
        "Character" => ["Humor", "Being Romantic"],
        "At Home" => ["Baking", "Podcasts"]
      },
      red: %{
        "Travels" => ["Camping"],
        "Going Out" => ["Clubs"]
      }
    },
    # Profile 18: Career Driven (7 white, 4 green, 1 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "Character" => ["Intelligence", "Honesty", "Self-Confidence"],
        "Sports" => ["Swimming", "Jogging"],
        "At Home" => ["Online Courses"]
      },
      green: %{
        "Character" => ["Creativity", "Courage"],
        "Travels" => ["City Trips"],
        "Music" => ["Jazz"]
      },
      red: %{
        "Music" => ["Schlager"]
      }
    },
    # Profile 19: Traditional (8 white, 5 green, 2 red)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship", "Marriage"],
        "Character" => ["Family-Oriented", "Honesty", "Caring"],
        "Sports" => ["Cycling"],
        "Music" => ["Folk"]
      },
      green: %{
        "Character" => ["Empathy", "Sense of Responsibility"],
        "At Home" => ["Cooking", "Gardening"],
        "Self Care" => ["Good Sleep"]
      },
      red: %{
        "Music" => ["Electronic", "Hip-Hop"]
      }
    }
  ]

  # ==========================================================================
  # PROFILE-SPECIFIC INTROS (2 per profile, picked by seed index)
  # ==========================================================================
  @profile_intros %{
    0 => [
      "Abenteuerlust pur! Wenn ich nicht gerade wandere, plane ich die nächste Tour. Am liebsten in den Bergen, mit Zelt und Sternenhimmel. Couch-Potato? Das Gegenteil davon!",
      "Draußen sein ist mein Lebenselixier. Ob Surfen, Wandern oder einfach den Gipfel erklimmen — Hauptsache Bewegung und frische Luft."
    ],
    1 => [
      "Die Natur ist mein Rückzugsort und meine Tankstelle. Wandern mit Vogelgesang als Playlist, Yoga im Garten, und abends ein Kräutertee — das bin ich.",
      "Ruhe finden in einer lauten Welt — das kann ich am besten draußen. Die Mosel, der Wald, ein Sonnenaufgang. Mein Happy Place."
    ],
    2 => [
      "Kreativität fließt durch alles, was ich tue. Ob Musik, Malerei oder Fotografie — ich brauche diesen kreativen Ausdruck wie die Luft zum Atmen.",
      "Kunst ist meine Sprache. Wenn ich male oder fotografiere, vergesse ich die Welt um mich herum. Ich suche jemanden, der die Schönheit in den Details sieht."
    ],
    3 => [
      "Ein gutes Buch, eine spannende Diskussion und ein starker Kaffee — das ist mein Rezept für einen perfekten Tag. Ich bin neugierig auf alles und jeden.",
      "Denken ist mein Hobby. Philosophie, Wissenschaft, die großen Fragen — ich liebe es, Dinge zu hinterfragen und Neues zu lernen."
    ],
    4 => [
      "Familie ist mir das Wichtigste. Ich träume von Sonntagsbrunch mit den Liebsten, Kindergelächter im Garten und einem Zuhause voller Wärme und Liebe.",
      "Ich bin ein Familienmensch durch und durch. Kochen für alle, gemeinsam im Garten werkeln und abends zusammen auf der Couch — so stelle ich mir Glück vor."
    ],
    5 => [
      "Fürsorge ist meine Stärke. Ich koche dir Suppe wenn du krank bist, höre zu wenn du reden musst, und bin da — in guten wie in schlechten Zeiten.",
      "In einer Beziehung gebe ich gerne 100%. Sich umeinander kümmern, füreinander da sein — das ist für mich keine Pflicht, sondern Liebe."
    ],
    6 => [
      "Das Leben ist eine Party und ich bringe die gute Stimmung mit! Ob Fußball mit Freunden, Konzert am Wochenende oder spontaner Grillabend — Hauptsache zusammen.",
      "Ich bin ein Energiebündel und liebe es, Menschen zusammenzubringen. Mein Kalender ist voll, aber für die richtige Person mache ich immer Platz."
    ],
    7 => [
      "Freiheit ist mir wichtig. Ich lebe spontan, plane ungern und freue mich über jeden Tag, der mich überrascht. Konventionen? Nicht so meins.",
      "Ich surfe lieber als im Büro zu sitzen, tanze barfuß am Strand und nehme das Leben wie es kommt. Suchst du auch jemanden mit Freigeist?"
    ],
    8 => [
      "Still und tief — so bin ich. Ich brauche keine laute Party, sondern ein gutes Gespräch bei einer Tasse Tee und echte Verbindung.",
      "Introvertiert heißt nicht langweilig. Es heißt, ich höre zu, denke nach und sage nur, was ich auch wirklich meine."
    ],
    9 => [
      "Ich glaube an die große Liebe und bin nicht zu cool dafür. Kerzen, Liebesbriefe, Sonnenuntergänge — ich stehe dazu und suche jemanden, der das teilt!",
      "Romantik ist keine Schwäche, sondern Stärke. Ich zeige meine Gefühle und suche jemanden, der das zu schätzen weiß."
    ],
    10 => [
      "Morgens um sechs auf dem Rad, mittags im Pool, abends Stretching. Bewegung ist mein Lebenselixier — und danach schmeckt alles doppelt so gut!",
      "Sport ist für mich mehr als Fitness — es ist Ausgleich, Freiheit und die beste Art, den Tag zu starten. Am liebsten zu zweit."
    ],
    11 => [
      "Musik ist der Soundtrack meines Lebens. Von Jazz im Wohnzimmer bis Soul im Club — ohne Musik geht bei mir nichts. Mein Gitarrenkoffer ist mein treuester Begleiter.",
      "Ich lebe für Musik. Live-Konzerte sind meine Kirche, und abends ein paar Akkorde klimpern meine Meditation. Wer macht mit?"
    ],
    12 => [
      "Der Weg zu meinem Herzen geht durch den Magen — aber nur, wenn es gut gewürzt ist! Ich koche mit Leidenschaft und probiere alles, was die Welt zu bieten hat.",
      "Essen ist Kultur, Liebe und Kunst in einem. Ich zelebriere jede Mahlzeit und suche jemanden, der mitgenießen möchte."
    ],
    13 => [
      "Mein Hund bestimmt meinen Tagesablauf und ich bin absolut okay damit. Tierliebe sagt viel über einen Menschen aus, finde ich.",
      "Vier Pfoten, eine nasse Nase und bedingungslose Liebe — so sieht mein Alltag aus. Tierfreunde bevorzugt!"
    ],
    14 => [
      "Mein Reisepass ist voller Stempel und mein Herz voller Erinnerungen. Jede Reise ist ein kleines Abenteuer, das mich als Mensch wachsen lässt.",
      "Die Welt ist zu schön, um zu Hause zu bleiben. Ich reise, um zu leben — nicht für Instagram, sondern für die Seele."
    ],
    15 => [
      "Balance in allen Dingen — das ist mein Mantra. Yoga, gesunde Ernährung und achtsames Leben machen mich glücklich und ausgeglichen.",
      "Achtsamkeit ist kein Trend, sondern mein Lebensweg. Ich meditiere, praktiziere Yoga und genieße bewusst die kleinen Momente."
    ],
    16 => [
      "Neugierig auf Technologie und die Zukunft — ich lerne ständig Neues. Gerade einen Online-Kurs belegt. Nerd mit Herz, sozusagen.",
      "Ich liebe Technologie und gute Gespräche gleichermaßen. Gaming am Abend, Podcast am Morgen, und dazwischen die großen Fragen des Lebens."
    ],
    17 => [
      "Mein Sofa ist mein Thron und meine Küche mein Königreich. Aber ich teile beides gerne mit den richtigen Menschen.",
      "Gemütlichkeit ist eine Lebenskunst. Gutes Essen, Filme, nette Gesellschaft — mehr brauche ich nicht zum Glücklichsein."
    ],
    18 => [
      "Ambitioniert und zielstrebig — so bin ich im Job und im Leben. Aber nach Feierabend kann ich auch loslassen und den Moment genießen.",
      "Ich liebe, was ich tue, und gebe immer mein Bestes. Karriere und Beziehung schließen sich nicht aus — beides braucht Hingabe."
    ],
    19 => [
      "Werte sind mir wichtig: Ehrlichkeit, Treue, Familie. Ich bin bodenständig und weiß, was ich will — etwas Echtes und Dauerhaftes.",
      "Bodenständig, verlässlich, mit beiden Beinen auf dem Boden. Ich suche jemanden, der die gleichen Werte teilt und gemeinsam etwas aufbauen möchte."
    ]
  }

  # ==========================================================================
  # TOPIC-MATCHED STORIES (for coherent moodboard content)
  # Each persona's moodboard draws from stories matching their topics.
  # ==========================================================================
  @topic_stories %{
    hiking: [
      "Mein Wochenende beginnt am liebsten mit Wanderschuhen und Rucksack. Die Wege entlang der Mosel und durch den Hunsrück sind meine absoluten Lieblinge.",
      "Es gibt nichts Besseres als nach einer langen Wanderung den Gipfel zu erreichen. Danach schmeckt das Bier doppelt so gut!",
      "Wandern ist für mich Meditation in Bewegung. Schritt für Schritt den Kopf frei bekommen und die Natur genießen."
    ],
    nature: [
      "Die Natur ist mein Rückzugsort. Ein Spaziergang im Wald reicht, um meinen Akku komplett aufzuladen.",
      "Sonntags bin ich am liebsten draußen — ob am Rhein, im Wald oder in einem Park mit einem guten Buch.",
      "Die kleinen Wunder der Natur faszinieren mich: der erste Frost, raschelnde Blätter, ein Sternenhimmel ohne Lichtverschmutzung."
    ],
    yoga: [
      "Yoga hat mein Leben verändert. Nicht nur körperlich, sondern auch mental. 15 Minuten am Morgen und der Tag kann kommen.",
      "Anfangs fand ich Yoga langweilig — heute ist es das Highlight meines Tages. Manchmal muss man sich eben auf Neues einlassen.",
      "Namaste am Rheinufer — meine Yogamatte und der Sonnenaufgang, das ist mein Morgenritual."
    ],
    cooking: [
      "Kochen ist meine Art, Liebe zu zeigen. Am liebsten für Freunde, mit guter Musik und einem Glas Wein in der Hand.",
      "Mein Risotto ist legendär — zumindest sagen das meine Freunde. Übung macht den Meister, und ich habe viel geübt!",
      "Sonntags ist Kochabend. Dann wird experimentiert, ausprobiert und manchmal auch bestellt, wenn es schiefgeht."
    ],
    food: [
      "Neue Restaurants entdecken ist mein liebstes Hobby. Mein aktueller Favorit: ein kleines libanesisches Lokal in der Altstadt.",
      "Street Food Märkte sind mein Happy Place. Einmal um die Welt essen, ohne den Rhein zu verlassen!",
      "Gutes Essen muss nicht teuer sein. Die besten Gerichte sind die, die mit Leidenschaft und Liebe zubereitet werden."
    ],
    beach: [
      "Meeresrauschen, Sand zwischen den Zehen und ein gutes Buch — das ist mein Paradies.",
      "Ich träume schon wieder vom nächsten Strandurlaub. Kroatien? Griechenland? Hauptsache Sonne und Meer!",
      "Am Strand vergesse ich alles um mich herum. Da bin ich ganz bei mir — und das ist unbezahlbar."
    ],
    travel: [
      "Reisen ist die beste Bildung. Jede Reise hat mich als Mensch verändert und meinen Horizont erweitert.",
      "Mein Koffer ist halb gepackt und mein Reisepass liegt immer griffbereit. Spontane Trips sind die allerbesten!",
      "Von Lissabon bis Tokyo — jede Stadt hat ihre eigene Seele. Am liebsten erkunde ich Städte zu Fuß."
    ],
    coffee: [
      "Ohne meinen Morgenkaffee geht gar nichts. Aber bitte richtig — frisch gemahlen, nicht aus der Kapselmaschine.",
      "Mein Lieblingsplatz: ein kleines Café um die Ecke, wo die Barista meinen Namen kennt.",
      "Kaffee trinken ist ein Ritual, eine Pause, ein Moment nur für mich. Am liebsten mit einem guten Gespräch."
    ],
    books: [
      "Mein Nachttisch biegt sich unter dem Gewicht meiner Bücherstapel. Ich lese meistens drei Bücher gleichzeitig.",
      "Ein gutes Buch ist wie ein guter Freund — es versteht dich, auch wenn du kein Wort sagst.",
      "Buchladen statt Amazon — ich liebe es, in Regalen zu stöbern und Schätze zu entdecken."
    ],
    music: [
      "Musik begleitet mich überall. Ob auf dem Rad, beim Kochen oder unter der Dusche — ohne Playlist läuft nichts.",
      "Live-Konzerte sind das Beste. Diese Energie, wenn tausend Menschen den gleichen Song singen!",
      "Ich spiele seit meiner Kindheit Gitarre. Nichts ist entspannender als abends ein paar Akkorde zu klimpern."
    ],
    art: [
      "Kunst ist mein Ventil. Ob mit Pinsel, Kamera oder Stift — kreativ sein hält mich lebendig.",
      "Museen und Galerien sind meine Lieblingsorte. Ich kann stundenlang vor einem Bild stehen und mich darin verlieren.",
      "Kreativität braucht keine Perfektion. Die schönsten Dinge entstehen spontan und aus dem Herzen."
    ],
    garden: [
      "Mein Garten ist mein kleines Paradies. Selbst angebaute Tomaten schmecken hundertmal besser als aus dem Supermarkt.",
      "Gartenarbeit erdet mich — im wahrsten Sinne des Wortes. Hände in der Erde, Sonne im Gesicht, das reicht mir.",
      "Dieses Jahr habe ich zum ersten Mal Chilis angebaut. 47 Pflanzen! Es ist etwas eskaliert."
    ],
    cycling: [
      "Auf dem Fahrrad bin ich frei. Die Moselradwege sind mein Wohnzimmer — nur mit besserer Aussicht.",
      "100 km am Wochenende sind mein Ziel. Nicht immer schaffe ich es, aber der Weg ist das Ziel!",
      "Fahrrad statt Auto — nicht nur für die Umwelt, sondern auch für mich. Die beste Art, den Tag zu starten."
    ],
    pets: [
      "Mein Hund ist mein bester Freund. Gemeinsam erkunden wir jeden Tag neue Wege — er bestimmt die Route.",
      "Katzenmensch durch und durch. Abends kuscheln, während sie mich souverän ignoriert — das ist wahre Liebe.",
      "Tiere verstehen dich ohne Worte. Deswegen ist mein Zuhause nie ohne vierbeinige Mitbewohner."
    ],
    sunset: [
      "Sonnenuntergänge am Deutschen Eck in Koblenz — jedes Mal wie ein Gemälde, jedes Mal anders schön.",
      "Ich sammle Sonnenuntergänge. Nicht auf Fotos, sondern in Erinnerungen. Die schönsten waren auf Santorini.",
      "Abends am Rhein sitzen und zusehen, wie die Sonne hinter der Festung verschwindet — mein liebstes Ritual."
    ],
    mountains: [
      "Die Berge rufen — und ich muss gehen! Ob Alpen, Eifel oder Hunsrück, Gipfelerlebnisse sind meine Belohnung.",
      "Es gibt kein besseres Gefühl als die Aussicht vom Gipfel. Die ganze Anstrengung lohnt sich in dem Moment.",
      "Bergluft ist die beste Medizin. Jedes Wochenende zieht es mich in die Höhe — je höher, desto besser."
    ]
  }

  # Maps each topic to matching lifestyle photos
  @topic_photos %{
    hiking: ["hiking-01.jpg", "hiking-02.jpg", "mountains-01.jpg"],
    nature: ["nature-01.jpg", "nature-02.jpg"],
    yoga: ["yoga-01.jpg", "yoga-02.jpg"],
    cooking: ["cooking-01.jpg", "cooking-02.jpg"],
    food: ["food-01.jpg", "cooking-02.jpg"],
    beach: ["beach-01.jpg", "beach-02.jpg"],
    travel: ["travel-01.jpg", "travel-02.jpg"],
    coffee: ["coffee-01.jpg", "coffee-02.jpg"],
    books: ["books-01.jpg", "books-02.jpg"],
    music: ["music-01.jpg", "music-02.jpg"],
    art: ["art-01.jpg", "art-02.jpg"],
    garden: ["garden-01.jpg", "garden-02.jpg"],
    cycling: ["cycling-01.jpg", "cycling-02.jpg"],
    pets: ["pets-01.jpg", "pets-02.jpg"],
    sunset: ["sunset-01.jpg", "nature-01.jpg"],
    mountains: ["mountains-01.jpg", "hiking-02.jpg"]
  }

  @german_long_stories [
    """
    **Was ich suche**

    Jemanden, der mit mir durch dick und dünn geht. Der meine Macken akzeptiert und seine eigenen mitbringt. Der mit mir lacht, bis uns die Tränen kommen, und der mich tröstet, wenn ich einen schlechten Tag habe.

    Ich glaube nicht an den perfekten Partner — aber an den Partner, der perfekt zu mir passt.
    """,
    """
    **Mein perfektes erstes Date**

    Kein fancy Restaurant, sondern ein Spaziergang am Fluss. Vielleicht ein Kaffee to go in der Hand. Zeit zum Reden, zum Lachen, zum Kennenlernen.

    Wenn die Chemie stimmt, merkt man das nicht beim Candlelight-Dinner, sondern wenn man einfach zusammen ist.
    """,
    """
    **Warum ich hier bin**

    Ehrlich gesagt? Weil ich es leid bin, im Alltag niemanden kennenzulernen. Mein Freundeskreis ist vergeben, meine Kollegen sind... naja, Kollegen.

    Ich glaube daran, dass man sein Glück selbst in die Hand nehmen muss. Also hier bin ich!
    """,
    """
    **Drei Dinge über mich**

    1. Ich kann nicht kochen, aber ich kann bestellen wie ein Weltmeister
    2. Ich lache über meine eigenen Witze (jemand muss es ja tun)
    3. Ich suche ernsthaft nach einer Beziehung, nicht nach etwas Lockerem

    Wenn das okay für dich ist, lass uns reden.
    """,
    """
    **Meine Vorstellung von Beziehung**

    Gemeinsam frühstücken, auch wenn wir beide verschlafen haben. Zusammen schweigen können, ohne dass es komisch ist. Sich gegenseitig Freiräume geben und trotzdem füreinander da sein.

    Klingt simpel? Ist es auch. Aber eben auch selten.
    """,
    """
    **Ein kleines Geständnis**

    Ich bin nervös, wenn ich neue Leute kennenlerne. Ich rede dann entweder zu viel oder zu wenig. Falls wir uns treffen und ich seltsam bin — gib mir eine zweite Chance.

    Unter der Oberfläche bin ich eigentlich ganz nett. Versprochen!
    """,
    """
    **Was mich glücklich macht**

    Sonntagmorgen ohne Wecker. Der Geruch von frischem Kaffee. Ein gutes Buch, das ich nicht weglegen kann. Lange Gespräche mit Menschen, die mir wichtig sind.

    Und vielleicht bald: Jemand, mit dem ich das alles teilen kann.
    """,
    """
    **Meine Deal-Breaker**

    - Unehrlichkeit (kleine Notlügen ausgenommen)
    - Kein Humor (das Leben ist zu kurz)
    - Kein Interesse an Wachstum und Veränderung

    Alles andere können wir besprechen. Ich bin flexibler als ich manchmal wirke.
    """
  ]

  # ==========================================================================
  # V2 DISCOVERY TEST USERS (40 female users calibrated against Thomas)
  # Thomas: age 32, height 186, male, Koblenz 56068, search_radius 60,
  #         hard-red Vegan, white Hiking/Surfing/Camping/Rock
  # ==========================================================================
  @v2_test_users [
    # --- Group A: Good Matches — survive all filters (10 users) ---
    %{group: :good, name: "Amelie", last: "Berger", zip: "56068", age: 30, height: 168},
    %{group: :good, name: "Greta", last: "Franke", zip: "56068", age: 29, height: 170},
    %{group: :good, name: "Hanna", last: "Dietrich", zip: "56068", age: 32, height: 165, search_radius: 80},
    %{group: :good, name: "Ida", last: "Engel", zip: "56566", age: 28, height: 172},
    %{group: :good, name: "Jana", last: "Fuchs", zip: "56566", age: 34, height: 163, search_radius: 150},
    %{group: :good, name: "Johanna", last: "Gerber", zip: "56566", age: 31, height: 175},
    %{group: :good, name: "Karla", last: "Haas", zip: "65556", age: 30, height: 162, search_radius: 80},
    %{group: :good, name: "Leonie", last: "Jaeger", zip: "65556", age: 33, height: 170},
    %{group: :good, name: "Mia", last: "Kaiser", zip: "53179", age: 29, height: 167, search_radius: 90},
    %{group: :good, name: "Nora", last: "Lorenz", zip: "53179", age: 31, height: 174},
    # --- Group B: Distance Drops (8 users) ---
    %{group: :distance, name: "Pia", last: "Moeller", zip: "55116", age: 30, height: 168, search_radius: 45},
    %{group: :distance, name: "Romy", last: "Naumann", zip: "55116", age: 29, height: 170, search_radius: 40},
    %{group: :distance, name: "Sofia", last: "Otto", zip: "57072", age: 31, height: 166, search_radius: 50},
    %{group: :distance, name: "Theresa", last: "Peters", zip: "57072", age: 33, height: 172, search_radius: 45},
    %{group: :distance, name: "Anja", last: "Reuter", zip: "50667", age: 30, height: 168, search_radius: 50},
    %{group: :distance, name: "Bettina", last: "Seidel", zip: "50667", age: 28, height: 165, search_radius: 50},
    %{group: :distance, name: "Carla", last: "Thiel", zip: "60311", age: 32, height: 170, search_radius: 50},
    %{group: :distance, name: "Dina", last: "Ulrich", zip: "54290", age: 29, height: 167, search_radius: 50},
    # --- Group C: Height Drops (6 users) ---
    %{group: :height, name: "Edith", last: "Vogt", zip: "56068", age: 30, height: 165, search_radius: 100, partner_height_min: 195},
    %{group: :height, name: "Frieda", last: "Walther", zip: "56068", age: 29, height: 162, search_radius: 100, partner_height_min: 195},
    %{group: :height, name: "Gisela", last: "Xander", zip: "56068", age: 31, height: 170, search_radius: 100, partner_height_min: 195},
    %{group: :height, name: "Hedwig", last: "Yildiz", zip: "56068", age: 28, height: 168, search_radius: 100, partner_height_max: 175},
    %{group: :height, name: "Irene", last: "Ziegler", zip: "56068", age: 33, height: 163, search_radius: 100, partner_height_max: 175},
    %{group: :height, name: "Jutta", last: "Adler", zip: "56068", age: 30, height: 167, search_radius: 100, partner_height_max: 175},
    # --- Group D: Blacklisted (5 users) ---
    %{group: :blacklist, name: "Klara", last: "Bach", zip: "56068", age: 30, height: 168, search_radius: 100, blacklist: "dev-thomas@animina.test"},
    %{group: :blacklist, name: "Lotte", last: "Conrad", zip: "56068", age: 29, height: 170, search_radius: 100, blacklist: "dev-thomas@animina.test"},
    %{group: :blacklist, name: "Magda", last: "Dreyer", zip: "56068", age: 31, height: 165, search_radius: 100, blacklist: "dev-thomas@animina.test"},
    %{group: :blacklist, name: "Nele", last: "Ebert", zip: "56068", age: 28, height: 172, search_radius: 100, blacklist: "+4915010000000"},
    %{group: :blacklist, name: "Olivia", last: "Fink", zip: "56068", age: 33, height: 167, search_radius: 100, blacklist: "+4915010000000"},
    # --- Group E: Hard-Red Conflicts (5 users) ---
    %{group: :red, name: "Paula", last: "Graf", zip: "56068", age: 30, height: 168, search_radius: 100, trait: {:white, "Diet", "Vegan"}},
    %{group: :red, name: "Renate", last: "Horn", zip: "56068", age: 29, height: 170, search_radius: 100, trait: {:white, "Diet", "Vegan"}},
    %{group: :red, name: "Svenja", last: "Iske", zip: "56068", age: 31, height: 165, search_radius: 100, trait: {:white, "Diet", "Vegan"}},
    %{group: :red, name: "Thea", last: "Janssen", zip: "56068", age: 28, height: 172, search_radius: 100, trait: {:red, "Sports", "Hiking"}},
    %{group: :red, name: "Ursula", last: "Keller", zip: "56068", age: 33, height: 167, search_radius: 100, trait: {:red, "Sports", "Hiking"}},
    # --- Group F: Age Drops (6 users) ---
    %{group: :age, name: "Veronika", last: "Lang", zip: "56068", age: 21, height: 168, search_radius: 100, partner_maximum_age_offset: 2},
    %{group: :age, name: "Wiebke", last: "Marx", zip: "56068", age: 21, height: 170, search_radius: 100, partner_maximum_age_offset: 2},
    %{group: :age, name: "Xenia", last: "Nowak", zip: "56068", age: 21, height: 165, search_radius: 100, partner_maximum_age_offset: 2},
    %{group: :age, name: "Yvonne", last: "Oswald", zip: "56068", age: 44, height: 167, search_radius: 100, partner_minimum_age_offset: 2},
    %{group: :age, name: "Zara", last: "Pohl", zip: "56068", age: 44, height: 163, search_radius: 100, partner_minimum_age_offset: 2},
    %{group: :age, name: "Astrid", last: "Ritter", zip: "56068", age: 44, height: 172, search_radius: 100, partner_minimum_age_offset: 2}
  ]

  # ==========================================================================
  # SEEDING ENTRY POINT
  # ==========================================================================
  def seed_all do
    IO.puts("\n=== Seeding Development Users ===\n")

    country = GeoData.get_country_by_code("DE")

    unless country do
      raise "Germany (DE) not found in countries table. Run geo data seeds first."
    end

    lookup = build_flag_lookup()

    # Seed personas
    IO.puts("Creating #{length(@personas)} personas...")

    for {persona, index} <- Enum.with_index(@personas) do
      create_persona(persona, country.id, index, lookup)
    end

    # Seed V2 discovery test users
    IO.puts("\nCreating V2 discovery test users...")

    for {user_data, idx} <- Enum.with_index(@v2_test_users) do
      create_v2_user(user_data, country.id, idx, lookup)
    end

    total = length(@personas) + length(@v2_test_users)

    IO.puts("\n=== Development Users Seeded Successfully ===")
    IO.puts("Total users created: #{total}")
    IO.puts("Password for all: #{@password}\n")
  end

  # ==========================================================================
  # PERSONA CREATION
  # ==========================================================================
  defp create_persona(persona, country_id, index, lookup) do
    birthday = birthday_from_age(persona.age)
    phone = generate_phone(index)
    email = "dev-#{String.downcase(persona.name)}@animina.test"
    gender = persona.gender
    preferred_gender = if gender == "male", do: ["female"], else: ["male"]

    height =
      Map.get_lazy(persona, :height, fn ->
        if gender == "male", do: Enum.random(170..195), else: Enum.random(155..180)
      end)

    attrs = %{
      email: email,
      password: @password,
      first_name: persona.name,
      last_name: persona.last_name,
      display_name: persona.name,
      birthday: birthday,
      gender: gender,
      height: height,
      mobile_phone: phone,
      preferred_partner_gender: preferred_gender,
      language: "de",
      terms_accepted: true,
      locations: [%{country_id: country_id, zip_code: @zip_code}]
    }

    case Accounts.register_user(attrs) do
      {:ok, user} ->
        user =
          if Map.get(persona, :waitlisted, false) do
            confirm_only_user(user)
          else
            confirm_and_activate_user(user)
          end

        # Assign roles
        assign_roles(user, Map.get(persona, :roles, []))

        # Assign personality traits from profile
        profile = Enum.at(@personality_profiles, persona.profile)
        assign_persona_traits(user, profile, lookup)

        # Create avatar from local photo
        create_persona_avatar(user, gender, persona.avatar)

        # Update pinned intro with profile-specific text
        update_persona_intro(user, persona.profile, index)

        # Create topic-matched moodboard
        create_persona_moodboard(user, persona, index)

        state = if Map.get(persona, :waitlisted, false), do: " [waitlisted]", else: ""
        IO.puts("  Created: #{persona.name} #{persona.last_name} (#{email})#{state}")
        {:ok, user}

      {:error, reason} ->
        IO.puts("  ERROR: #{persona.name} #{persona.last_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ==========================================================================
  # V2 TEST USER CREATION (preserved for discovery funnel testing)
  # ==========================================================================
  defp create_v2_user(data, country_id, idx, lookup) do
    birthday = birthday_from_age(data.age)
    phone = generate_phone(100 + idx)
    email = "dev-v2-#{String.downcase(data.name)}@animina.test"

    attrs =
      %{
        email: email,
        password: @password,
        first_name: data.name,
        last_name: data.last,
        display_name: data.name,
        birthday: birthday,
        gender: "female",
        height: data.height,
        mobile_phone: phone,
        preferred_partner_gender: ["male"],
        language: "de",
        terms_accepted: true,
        locations: [%{country_id: country_id, zip_code: data.zip}]
      }
      |> maybe_put(:search_radius, data[:search_radius])
      |> maybe_put(:partner_height_min, data[:partner_height_min])
      |> maybe_put(:partner_height_max, data[:partner_height_max])
      |> maybe_put(:partner_minimum_age_offset, data[:partner_minimum_age_offset])
      |> maybe_put(:partner_maximum_age_offset, data[:partner_maximum_age_offset])

    case Accounts.register_user(attrs) do
      {:ok, user} ->
        user = confirm_and_activate_user(user)

        if data[:blacklist], do: add_blacklist_entry(user, data.blacklist)
        if data[:trait], do: add_conflict_trait(user, data.trait, lookup)

        # Use random avatar from the female directory
        create_random_avatar(user, "female")

        IO.puts("  Created: #{data.name} #{data.last} (#{email}) [#{data.group}]")
        {:ok, user}

      {:error, reason} ->
        IO.puts("  ERROR: #{data.name} #{data.last}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ==========================================================================
  # AVATAR HELPERS
  # ==========================================================================
  defp create_persona_avatar(user, gender, avatar_stem) do
    avatar_dir = avatar_directory(gender)
    avatar_path = Path.join(avatar_dir, "avatar-dev-#{avatar_stem}.jpg")

    case Photos.upload_photo("User", user.id, avatar_path, type: "avatar") do
      {:ok, photo} ->
        Moodboard.link_avatar_to_pinned_item(user.id, photo.id)
        {:ok, photo}

      {:error, reason} ->
        IO.puts("    Warning: avatar failed for #{user.display_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_random_avatar(user, gender) do
    avatar_dir = avatar_directory(gender)

    case File.ls(avatar_dir) do
      {:ok, files} ->
        jpgs = Enum.filter(files, &String.ends_with?(&1, ".jpg"))

        if jpgs != [] do
          avatar_path = Path.join(avatar_dir, Enum.random(jpgs))

          case Photos.upload_photo("User", user.id, avatar_path, type: "avatar") do
            {:ok, photo} ->
              Moodboard.link_avatar_to_pinned_item(user.id, photo.id)
              {:ok, photo}

            {:error, reason} ->
              IO.puts("    Warning: random avatar failed: #{inspect(reason)}")
              {:error, reason}
          end
        end

      _ ->
        :ok
    end
  end

  defp avatar_directory(gender) do
    Path.join([:code.priv_dir(:animina), "static", "images", "seeds", "avatars", gender])
  end

  # ==========================================================================
  # INTRO STORY
  # ==========================================================================
  defp update_persona_intro(user, profile_index, seed_index) do
    intros = Map.get(@profile_intros, profile_index, [])

    case intros do
      [] ->
        :ok

      _ ->
        :rand.seed(:exsss, {seed_index * 17, seed_index * 19, seed_index * 23})
        intro = Enum.random(intros)

        case Moodboard.get_pinned_item(user.id) do
          nil -> :ok
          item -> if item.moodboard_story, do: Moodboard.update_story(item.moodboard_story, intro)
        end
    end
  end

  # ==========================================================================
  # MOODBOARD CREATION (topic-matched content)
  # ==========================================================================
  defp create_persona_moodboard(user, persona, seed_index) do
    :rand.seed(:exsss, {seed_index * 7, seed_index * 11, seed_index * 13})

    # Gather photos and stories from persona's topics
    photos =
      persona.topics
      |> Enum.flat_map(&Map.get(@topic_photos, &1, []))
      |> Enum.uniq()
      |> Enum.shuffle()

    stories =
      persona.topics
      |> Enum.flat_map(&Map.get(@topic_stories, &1, []))
      |> Enum.shuffle()

    # 4-8 items per persona
    item_count = 4 + rem(seed_index, 5)
    photo_count = max(length(photos), 1)
    story_count = max(length(stories), 1)

    for i <- 0..(item_count - 1) do
      photo = Enum.at(photos, rem(i, photo_count))
      source_path = photo_source_path(photo)

      cond do
        # First half: combined photo + story
        i < div(item_count, 2) ->
          story = Enum.at(stories, rem(i, story_count))
          create_combined_moodboard_item(user, source_path, story)

        # Every 3rd remaining: text-only (occasionally a long story)
        rem(i, 3) == 0 ->
          story =
            if rem(seed_index + i, 6) == 0 do
              Enum.random(@german_long_stories)
            else
              Enum.at(stories, rem(i, story_count))
            end

          create_story_moodboard_item(user, story)

        # Rest: photo-only
        true ->
          create_photo_moodboard_item(user, source_path)
      end

      Process.sleep(10)
    end
  end

  defp photo_source_path(filename) do
    Path.join([
      :code.priv_dir(:animina),
      "static",
      "images",
      "seeds",
      "lifestyle",
      filename
    ])
  end

  defp create_photo_moodboard_item(user, source_path) do
    case Moodboard.create_photo_item(user, source_path) do
      {:ok, item} -> {:ok, item}
      error -> error
    end
  end

  defp create_combined_moodboard_item(user, source_path, story) do
    case Moodboard.create_combined_item(user, source_path, story) do
      {:ok, item} -> {:ok, item}
      error -> error
    end
  end

  defp create_story_moodboard_item(user, story) do
    Moodboard.create_story_item(user, story)
  end

  # ==========================================================================
  # TRAIT ASSIGNMENT
  # ==========================================================================
  defp assign_persona_traits(user, profile, lookup) do
    # Ensure default published categories
    Traits.ensure_default_published_categories(user)

    # Assign profile traits
    assign_profile_traits(user, profile, lookup)

    # Always assign Deutsch as spoken language
    case get_in(lookup, ["Languages", "Deutsch"]) do
      nil -> :ok
      flag -> Traits.add_user_flag(%{user_id: user.id, flag_id: flag.id, color: "white", intensity: "hard", position: 1})
    end
  end

  defp build_flag_lookup do
    for category <- Traits.list_categories(), into: %{} do
      flags = Traits.list_flags_by_category(category)
      flag_map = for f <- flags, into: %{}, do: {f.name, f}
      {category.name, flag_map}
    end
  end

  defp assign_profile_traits(user, profile, lookup) do
    # Collect all category names used across white/green/red
    all_category_names =
      [Map.keys(profile.white), Map.keys(profile.green), Map.keys(profile.red)]
      |> List.flatten()
      |> Enum.uniq()

    # Ensure opt-in records exist for non-core categories
    optin_by_name =
      for c <- Traits.list_optin_categories(), into: %{}, do: {c.name, c.id}

    for category_name <- all_category_names,
        category_id = Map.get(optin_by_name, category_name),
        category_id != nil do
      Animina.Traits.UserCategoryOptIn.changeset(
        %Animina.Traits.UserCategoryOptIn{},
        %{user_id: user.id, category_id: category_id}
      )
      |> Repo.insert(on_conflict: :nothing)
    end

    # Assign white flags
    for {category_name, flag_names} <- profile.white do
      for {flag_name, pos} <- Enum.with_index(flag_names, 1) do
        case get_in(lookup, [category_name, flag_name]) do
          nil -> IO.puts("    Warning: flag '#{flag_name}' not found in '#{category_name}'")
          flag -> Traits.add_user_flag(%{user_id: user.id, flag_id: flag.id, color: "white", intensity: "hard", position: pos})
        end
      end
    end

    # Assign green flags
    for {category_name, flag_names} <- profile.green do
      for {flag_name, pos} <- Enum.with_index(flag_names, 1) do
        case get_in(lookup, [category_name, flag_name]) do
          nil -> :ok
          flag -> Traits.add_user_flag(%{user_id: user.id, flag_id: flag.id, color: "green", intensity: "hard", position: pos})
        end
      end
    end

    # Assign red flags
    for {category_name, flag_names} <- profile.red do
      for {flag_name, pos} <- Enum.with_index(flag_names, 1) do
        case get_in(lookup, [category_name, flag_name]) do
          nil -> :ok
          flag -> Traits.add_user_flag(%{user_id: user.id, flag_id: flag.id, color: "red", intensity: "hard", position: pos})
        end
      end
    end
  end

  # ==========================================================================
  # SHARED HELPERS
  # ==========================================================================
  defp birthday_from_age(age) do
    today = Date.utc_today()
    Date.add(today, -(age * 365 + Enum.random(0..364)))
  end

  defp generate_phone(index) do
    prefixes = ["150", "151", "152", "153", "155", "156", "157", "159", "160", "162", "163", "172", "176", "177", "178", "179"]
    prefix = Enum.at(prefixes, rem(index, length(prefixes)))
    suffix = String.pad_leading("#{10000000 + index}", 8, "0")
    "+49#{prefix}#{suffix}"
  end

  defp confirm_and_activate_user(user) do
    now = DateTime.utc_now(:second)

    {1, _} =
      Repo.update_all(
        from(u in Animina.Accounts.User, where: u.id == ^user.id),
        set: [confirmed_at: now, state: "normal"]
      )

    Repo.get!(Animina.Accounts.User, user.id)
  end

  defp confirm_only_user(user) do
    now = DateTime.utc_now(:second)
    end_waitlist_at = DateTime.add(now, 14 * 86_400, :second)

    {1, _} =
      Repo.update_all(
        from(u in Animina.Accounts.User, where: u.id == ^user.id),
        set: [confirmed_at: now, end_waitlist_at: end_waitlist_at]
      )

    Repo.get!(Animina.Accounts.User, user.id)
  end

  defp assign_roles(user, roles) do
    for role <- roles do
      Accounts.assign_role(user, to_string(role))
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp add_blacklist_entry(user, value) do
    case ContactBlacklist.add_entry(user, %{value: value}) do
      {:ok, _} -> :ok
      {:error, reason} -> IO.puts("    Warning: blacklist entry failed: #{inspect(reason)}")
    end
  end

  defp add_conflict_trait(user, {color, category_name, flag_name}, lookup) do
    case get_in(lookup, [category_name, flag_name]) do
      nil ->
        IO.puts("    Warning: flag '#{flag_name}' not found in '#{category_name}'")

      flag ->
        ensure_category_optin(user, category_name)

        Traits.add_user_flag(%{
          user_id: user.id,
          flag_id: flag.id,
          color: to_string(color),
          intensity: "hard",
          position: 1
        })
    end
  end

  defp ensure_category_optin(user, category_name) do
    optin_names =
      for c <- Traits.list_optin_categories(), into: %{}, do: {c.name, c.id}

    case Map.get(optin_names, category_name) do
      nil ->
        :ok

      category_id ->
        Animina.Traits.UserCategoryOptIn.changeset(
          %Animina.Traits.UserCategoryOptIn{},
          %{user_id: user.id, category_id: category_id}
        )
        |> Repo.insert(on_conflict: :nothing)
    end
  end
end
