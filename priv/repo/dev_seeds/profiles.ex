defmodule Animina.Seeds.Profiles do
  @moduledoc """
  Personality profiles (20 profiles) for development seed personas.
  Each profile defines white/green/red flag assignments by category.
  Flag counts respect limits: white ≤16, green ≤10, red ≤10.
  White counts below are BEFORE the automatic +1 Deutsch flag.
  """

  def all do
    [
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
  end
end
