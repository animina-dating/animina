defmodule Animina.Repo.Migrations.SeedFlag do
  @moduledoc """
  Seed flags.
  """

  use Ecto.Migration

  def up do
    flags()
    |> Enum.map(&{&1.category_id, &1.category_name, &1.items})
    |> Enum.map(fn val ->
      case val do
        {name, %{de: name_de, en: name_en}, items} ->
          category = Animina.Traits.Category.create!(%{name: name})

          _de =
            Animina.Traits.CategoryTranslation.create!(%{
              category_id: category.id,
              name: name_de,
              language: "de"
            })

          _en =
            Animina.Traits.CategoryTranslation.create!(%{
              category_id: category.id,
              name: name_en,
              language: "en"
            })

          Enum.map(items, fn item ->
            case item do
              %{
                name: %{de: name_de, en: name_en},
                hashtags: %{de: hashtags_de, en: hashtags_en},
                emoji: emoji
              } ->
                flag =
                  Animina.Traits.Flag.create!(%{
                    category_id: category.id,
                    name: name_en,
                    emoji: emoji
                  })

                _de =
                  Animina.Traits.FlagTranslation.create!(%{
                    flag_id: flag.id,
                    name: name_de,
                    language: "de",
                    hashtag: hashtags_de
                  })

                _en =
                  Animina.Traits.FlagTranslation.create!(%{
                    flag_id: flag.id,
                    name: name_en,
                    language: "en",
                    hashtag: hashtags_en
                  })
            end
          end)

        _ ->
          IO.puts("No match")
      end
    end)
  end

  def down do
  end

  defp flags do
    [
      %{
        category_id: "characters",
        category_name: %{de: "Charakter", en: "Character"},
        items: [
          %{
            name: %{de: "Bescheidenheit", en: "Modesty"},
            hashtags: %{de: "#Bescheidenheit", en: "#Modesty"},
            emoji: "🌼"
          },
          %{
            name: %{de: "Gerechtigkeitssinn", en: "Sense of Justice"},
            hashtags: %{de: "#Gerechtigkeitssinn", en: "#SenseOfJustice"},
            emoji: "⚖️"
          },
          %{
            name: %{de: "Ehrlichkeit", en: "Honesty"},
            hashtags: %{de: "#Ehrlichkeit", en: "#Honesty"},
            emoji: "🤝"
          },
          %{
            name: %{de: "Mut", en: "Courage"},
            hashtags: %{de: "#Mut", en: "#Courage"},
            emoji: "🦁"
          },
          %{
            name: %{de: "Widerstandsfähigkeit", en: "Resilience"},
            hashtags: %{de: "#Widerstandsfähigkeit", en: "#Resilience"},
            emoji: "🪨"
          },
          %{
            name: %{de: "Verantwortungsbewusstsein", en: "Sense of Responsibility"},
            hashtags: %{de: "#Verantwortungsbewusstsein", en: "#SenseOfResponsibility"},
            emoji: "🔑"
          },
          %{
            name: %{de: "Humor", en: "Humor"},
            hashtags: %{de: "#Humor", en: "#Humor"},
            emoji: "😄"
          },
          %{
            name: %{de: "Fürsorglichkeit", en: "Caring"},
            hashtags: %{de: "#Fürsorglichkeit", en: "#Caring"},
            emoji: "💖"
          },
          %{
            name: %{de: "Großzügigkeit", en: "Generosity"},
            hashtags: %{de: "#Großzügigkeit", en: "#Generosity"},
            emoji: "🎁"
          },
          %{
            name: %{de: "Selbstakzeptanz", en: "Self-Acceptance"},
            hashtags: %{de: "#Selbstakzeptanz", en: "#SelfAcceptance"},
            emoji: "🤗"
          },
          %{
            name: %{de: "Familienorientiert", en: "Family-Oriented"},
            hashtags: %{de: "#Familienorientiert", en: "#FamilyOriented"},
            emoji: "👨‍👩‍👧‍👦"
          },
          %{
            name: %{de: "Intelligenz", en: "Intelligence"},
            hashtags: %{de: "#Intelligenz", en: "#Intelligence"},
            emoji: "🧠"
          },
          %{
            name: %{de: "Abenteuerlust", en: "Love of Adventure"},
            hashtags: %{de: "#Abenteuerlust", en: "#LoveOfAdventure"},
            emoji: "🌍"
          },
          %{
            name: %{de: "Aktiv", en: "Active"},
            hashtags: %{de: "#Aktiv", en: "#Active"},
            emoji: "🏃"
          },
          %{
            name: %{de: "Empathie", en: "Empathy"},
            hashtags: %{de: "#Empathie", en: "#Empathy"},
            emoji: "💞"
          },
          %{
            name: %{de: "Kreativität", en: "Creativity"},
            hashtags: %{de: "#Kreativität", en: "#Creativity"},
            emoji: "🎨"
          },
          %{
            name: %{de: "Optimismus", en: "Optimism"},
            hashtags: %{de: "#Optimismus", en: "#Optimism"},
            emoji: "☀️"
          },
          %{
            name: %{de: "Romantisch sein", en: "Being Romantic"},
            hashtags: %{de: "#RomantischSein", en: "#BeingRomantic"},
            emoji: "💐"
          },
          %{
            name: %{de: "Selbstvertrauen", en: "Self-Confidence"},
            hashtags: %{de: "#Selbstvertrauen", en: "#SelfConfidence"},
            emoji: "💪"
          },
          %{
            name: %{de: "Soziales Bewusstsein", en: "Social Awareness"},
            hashtags: %{de: "#SozialesBewusstsein", en: "#SocialAwareness"},
            emoji: "🌐"
          }
        ]
      },
      %{
        category_id: "family_planning",
        category_name: %{de: "Familienplanung", en: "Family Planning"},
        items: [
          %{
            name: %{
              de: "Habe Kinder",
              en: "Have Children"
            },
            hashtags: %{de: "#HabeKinder", en: "#HaveChildren"},
            emoji: "👨‍👩‍👧‍👦"
          },
          %{
            name: %{
              de: "Möchte keine weiteren Kinder",
              en: "Want No More Children"
            },
            hashtags: %{de: "#KeineWeiterenKinder", en: "#NoMoreChildren"},
            emoji: "👨‍👩‍👧‍👦❌"
          },
          %{
            name: %{de: "Offen für weitere Kinder", en: "Open to More Children"},
            hashtags: %{de: "#OffenFürMehrKinder", en: "#OpenToMoreChildren"},
            emoji: "👨‍👩‍👧‍👦➕"
          }
        ]
      },
      %{
        category_id: "substance_use",
        category_name: %{de: "Substanzgebrauch", en: "Substance Use"},
        items: [
          %{
            name: %{de: "Rauchen", en: "Smoking"},
            hashtags: %{de: "#Rauchen", en: "#Smoking"},
            emoji: "🚬"
          },
          %{
            name: %{de: "Alkohol", en: "Alcohol"},
            hashtags: %{de: "#Alkohol", en: "#Alcohol"},
            emoji: "🍻"
          },
          %{
            name: %{de: "Marihuana", en: "Marijuana"},
            hashtags: %{de: "#Marihuana", en: "#Marijuana"},
            emoji: "🌿"
          }
        ]
      },
      %{
        category_id: "animals",
        category_name: %{de: "Tiere", en: "Animals"},
        items: [
          %{name: %{de: "Hund", en: "Dog"}, hashtags: %{de: "#Hund", en: "#Dog"}, emoji: "🐶"},
          %{name: %{de: "Katze", en: "Cat"}, hashtags: %{de: "#Katze", en: "#Cat"}, emoji: "🐱"},
          %{name: %{de: "Maus", en: "Mouse"}, hashtags: %{de: "#Maus", en: "#Mouse"}, emoji: "🐭"},
          %{
            name: %{de: "Kaninchen", en: "Rabbit"},
            hashtags: %{de: "#Kaninchen", en: "#Rabbit"},
            emoji: "🐰"
          },
          %{
            name: %{de: "Meerschweinchen", en: "Guinea Pig"},
            hashtags: %{de: "#Meerschweinchen", en: "#GuineaPig"},
            emoji: "🐹"
          },
          %{
            name: %{de: "Hamster", en: "Hamster"},
            hashtags: %{de: "#Hamster", en: "#Hamster"},
            emoji: "🐹"
          },
          %{name: %{de: "Vogel", en: "Bird"}, hashtags: %{de: "#Vogel", en: "#Bird"}, emoji: "🐦"},
          %{name: %{de: "Fisch", en: "Fish"}, hashtags: %{de: "#Fisch", en: "#Fish"}, emoji: "🐠"},
          %{
            name: %{de: "Reptil", en: "Reptile"},
            hashtags: %{de: "#Reptil", en: "#Reptile"},
            emoji: "🦎"
          },
          %{
            name: %{de: "Pferd", en: "Horse"},
            hashtags: %{de: "#Pferd", en: "#Horse"},
            emoji: "🐴"
          }
        ]
      },
      %{
        category_id: "food",
        category_name: %{de: "Essen", en: "Food"},
        items: [
          %{
            name: %{de: "Vegan", en: "Vegan"},
            hashtags: %{de: "#Vegan", en: "#Vegan"},
            emoji: "🌱"
          },
          %{
            name: %{de: "Vegetarier", en: "Vegetarian"},
            hashtags: %{de: "#Vegetarier", en: "#Vegetarian"},
            emoji: "🥦"
          },
          %{
            name: %{de: "Italienisch", en: "Italian"},
            hashtags: %{de: "#Italienisch", en: "#Italian"},
            emoji: "🍝"
          },
          %{
            name: %{de: "Chinesisch", en: "Chinese"},
            hashtags: %{de: "#Chinesisch", en: "#Chinese"},
            emoji: "🥡"
          },
          %{
            name: %{de: "Indisch", en: "Indian"},
            hashtags: %{de: "#Indisch", en: "#Indian"},
            emoji: "🍛"
          },
          %{
            name: %{de: "Französisch", en: "French"},
            hashtags: %{de: "#Französisch", en: "#French"},
            emoji: "🥖"
          },
          %{
            name: %{de: "Spanisch", en: "Spanish"},
            hashtags: %{de: "#Spanisch", en: "#Spanish"},
            emoji: "🥘"
          },
          %{
            name: %{de: "Mexikanisch", en: "Mexican"},
            hashtags: %{de: "#Mexikanisch", en: "#Mexican"},
            emoji: "🌮"
          },
          %{
            name: %{de: "Japanisch", en: "Japanese"},
            hashtags: %{de: "#Japanisch", en: "#Japanese"},
            emoji: "🍣"
          },
          %{
            name: %{de: "Türkisch", en: "Turkish"},
            hashtags: %{de: "#Türkisch", en: "#Turkish"},
            emoji: "🍢"
          },
          %{name: %{de: "Thai", en: "Thai"}, hashtags: %{de: "#Thai", en: "#Thai"}, emoji: "🍲"},
          %{
            name: %{de: "Griechisch", en: "Greek"},
            hashtags: %{de: "#Griechisch", en: "#Greek"},
            emoji: "🥙"
          },
          %{
            name: %{de: "Amerikanisch", en: "American"},
            hashtags: %{de: "#Amerikanisch", en: "#American"},
            emoji: "🍔"
          },
          %{
            name: %{de: "Vietnamesisch", en: "Vietnamese"},
            hashtags: %{de: "#Vietnamesisch", en: "#Vietnamese"},
            emoji: "🍜"
          },
          %{
            name: %{de: "Koreanisch", en: "Korean"},
            hashtags: %{de: "#Koreanisch", en: "#Korean"},
            emoji: "🍚"
          },
          %{
            name: %{de: "Deutsch", en: "German"},
            hashtags: %{de: "#Deutsch", en: "#German"},
            emoji: "🌭"
          },
          %{
            name: %{de: "Mediterran", en: "Mediterranean"},
            hashtags: %{de: "#Mediterran", en: "#Mediterranean"},
            emoji: "🍇"
          },
          %{
            name: %{de: "Fast Food", en: "Fast Food"},
            hashtags: %{de: "#FastFood", en: "#FastFood"},
            emoji: "🍟"
          },
          %{
            name: %{de: "Street Food", en: "Street Food"},
            hashtags: %{de: "#StreetFood", en: "#StreetFood"},
            emoji: "🥡"
          },
          %{
            name: %{de: "Gesundes Essen", en: "Healthy Food"},
            hashtags: %{de: "#GesundesEssen", en: "#HealthyFood"},
            emoji: "🥗"
          },
          %{
            name: %{de: "Desserts", en: "Desserts"},
            hashtags: %{de: "#Desserts", en: "#Desserts"},
            emoji: "🍰"
          },
          %{
            name: %{de: "Backwaren", en: "Pastries"},
            hashtags: %{de: "#Backwaren", en: "#Pastries"},
            emoji: "🥐"
          },
          %{
            name: %{de: "Grillen", en: "BBQ"},
            hashtags: %{de: "#Grillen", en: "#BBQ"},
            emoji: "🍖"
          },
          %{
            name: %{de: "Snacks", en: "Snacks"},
            hashtags: %{de: "#Snacks", en: "#Snacks"},
            emoji: "🍿"
          }
        ]
      },
      %{
        category_id: "sports",
        category_name: %{de: "Sport", en: "Sports"},
        items: [
          %{
            name: %{de: "Fußball", en: "Soccer"},
            hashtags: %{de: "#Fußball", en: "#Soccer"},
            emoji: "⚽"
          },
          %{
            name: %{de: "Turnen", en: "Gymnastics"},
            hashtags: %{de: "#Turnen", en: "#Gymnastics"},
            emoji: "🤸"
          },
          %{
            name: %{de: "Tennis", en: "Tennis"},
            hashtags: %{de: "#Tennis", en: "#Tennis"},
            emoji: "🎾"
          },
          %{
            name: %{de: "Wandern", en: "Hiking"},
            hashtags: %{de: "#Wandern", en: "#Hiking"},
            emoji: "🥾"
          },
          %{
            name: %{de: "Klettern", en: "Climbing"},
            hashtags: %{de: "#Klettern", en: "#Climbing"},
            emoji: "🧗"
          },
          %{name: %{de: "Ski", en: "Skiing"}, hashtags: %{de: "#Ski", en: "#Skiing"}, emoji: "⛷"},
          %{
            name: %{de: "Leichtathletik", en: "Athletics"},
            hashtags: %{de: "#Leichtathletik", en: "#Athletics"},
            emoji: "🏃"
          },
          %{
            name: %{de: "Handball", en: "Handball"},
            hashtags: %{de: "#Handball", en: "#Handball"},
            emoji: "🤾"
          },
          %{
            name: %{de: "Reiten", en: "Horse Riding"},
            hashtags: %{de: "#Reiten", en: "#HorseRiding"},
            emoji: "🏇"
          },
          %{name: %{de: "Golf", en: "Golf"}, hashtags: %{de: "#Golf", en: "#Golf"}, emoji: "⛳"},
          %{
            name: %{de: "Schwimmen", en: "Swimming"},
            hashtags: %{de: "#Schwimmen", en: "#Swimming"},
            emoji: "🏊"
          },
          %{
            name: %{de: "Volleyball", en: "Volleyball"},
            hashtags: %{de: "#Volleyball", en: "#Volleyball"},
            emoji: "🏐"
          },
          %{
            name: %{de: "Basketball", en: "Basketball"},
            hashtags: %{de: "#Basketball", en: "#Basketball"},
            emoji: "🏀"
          },
          %{
            name: %{de: "Eishockey", en: "Ice Hockey"},
            hashtags: %{de: "#Eishockey", en: "#IceHockey"},
            emoji: "🏒"
          },
          %{
            name: %{de: "Tischtennis", en: "Table Tennis"},
            hashtags: %{de: "#Tischtennis", en: "#TableTennis"},
            emoji: "🏓"
          },
          %{
            name: %{de: "Badminton", en: "Badminton"},
            hashtags: %{de: "#Badminton", en: "#Badminton"},
            emoji: "🏸"
          },
          %{name: %{de: "Yoga", en: "Yoga"}, hashtags: %{de: "#Yoga", en: "#Yoga"}, emoji: "🧘"},
          %{
            name: %{de: "Tauchen", en: "Diving"},
            hashtags: %{de: "#Tauchen", en: "#Diving"},
            emoji: "🤿"
          },
          %{
            name: %{de: "Surfen", en: "Surfing"},
            hashtags: %{de: "#Surfen", en: "#Surfing"},
            emoji: "🏄"
          },
          %{
            name: %{de: "Segeln", en: "Sailing"},
            hashtags: %{de: "#Segeln", en: "#Sailing"},
            emoji: "⛵"
          },
          %{
            name: %{de: "Rudern", en: "Rowing"},
            hashtags: %{de: "#Rudern", en: "#Rowing"},
            emoji: "🚣"
          },
          %{
            name: %{de: "Boxen", en: "Boxing"},
            hashtags: %{de: "#Boxen", en: "#Boxing"},
            emoji: "🥊"
          },
          %{
            name: %{de: "Radfahren", en: "Cycling"},
            hashtags: %{de: "#Radfahren", en: "#Cycling"},
            emoji: "🚴"
          },
          %{
            name: %{de: "Joggen", en: "Jogging"},
            hashtags: %{de: "#Joggen", en: "#Jogging"},
            emoji: "🏃‍♂️"
          },
          %{
            name: %{de: "Pilates", en: "Pilates"},
            hashtags: %{de: "#Pilates", en: "#Pilates"},
            emoji: "🤸‍♀️"
          },
          %{
            name: %{de: "Fitnessstudio", en: "Gym"},
            hashtags: %{de: "#Fitnessstudio", en: "#Gym"},
            emoji: "🏋️"
          },
          %{
            name: %{de: "Kampfsport", en: "Martial Arts"},
            hashtags: %{de: "#Kampfsport", en: "#MartialArts"},
            emoji: "🥋"
          }
        ]
      },
      %{
        category_id: "travels",
        category_name: %{de: "Reisen", en: "Travels"},
        items: [
          %{
            name: %{de: "Strand", en: "Beach"},
            hashtags: %{de: "#Strand", en: "#Beach"},
            emoji: "🏖️"
          },
          %{
            name: %{de: "Städtereisen", en: "City Trips"},
            hashtags: %{de: "#Städtereisen", en: "#CityTrips"},
            emoji: "🏙️"
          },
          %{
            name: %{de: "Wandern", en: "Hiking Vacation"},
            hashtags: %{de: "#Wanderurlaub", en: "#HikingVacation"},
            emoji: "🥾"
          },
          %{
            name: %{de: "Kreuzfahrten", en: "Cruises"},
            hashtags: %{de: "#Kreuzfahrten", en: "#Cruises"},
            emoji: "🚢"
          },
          %{
            name: %{de: "Fahrradtouren", en: "Bike Tours"},
            hashtags: %{de: "#Fahrradtouren", en: "#BikeTours"},
            emoji: "🚴"
          },
          %{
            name: %{de: "Wellness", en: "Wellness"},
            hashtags: %{de: "#Wellness", en: "#Wellness"},
            emoji: "🧘‍♀️"
          },
          %{
            name: %{de: "Aktiv und Sporturlaub", en: "Active and Sports Vacation"},
            hashtags: %{de: "#AktivUndSporturlaub", en: "#ActiveAndSportsVacation"},
            emoji: "🏋️‍♂️"
          },
          %{
            name: %{de: "Camping", en: "Camping"},
            hashtags: %{de: "#Camping", en: "#Camping"},
            emoji: "🏕️"
          },
          %{
            name: %{de: "Kulturreisen", en: "Cultural Trips"},
            hashtags: %{de: "#Kulturreisen", en: "#CulturalTrips"},
            emoji: "🕌"
          },
          %{
            name: %{de: "Wintersport", en: "Winter Sports"},
            hashtags: %{de: "#Wintersport", en: "#WinterSports"},
            emoji: "🏂"
          }
        ]
      },
      %{
        category_id: "favorite_destinations",
        category_name: %{de: "Lieblingsziele", en: "Favorite Destinations"},
        items: [
          %{
            name: %{de: "Europa", en: "Europe"},
            hashtags: %{de: "#Europa", en: "#Europe"},
            emoji: "🇪🇺"
          },
          %{name: %{de: "Asien", en: "Asia"}, hashtags: %{de: "#Asien", en: "#Asia"}, emoji: "🌏"},
          %{
            name: %{de: "Afrika", en: "Africa"},
            hashtags: %{de: "#Afrika", en: "#Africa"},
            emoji: "🌍"
          },
          %{
            name: %{de: "Nordamerika", en: "North America"},
            hashtags: %{de: "#Nordamerika", en: "#NorthAmerica"},
            emoji: "🌎"
          },
          %{
            name: %{de: "Südamerika", en: "South America"},
            hashtags: %{de: "#Südamerika", en: "#SouthAmerica"},
            emoji: "🌎"
          },
          %{
            name: %{de: "Australien", en: "Australia"},
            hashtags: %{de: "#Australien", en: "#Australia"},
            emoji: "🇦🇺"
          },
          %{
            name: %{de: "Antarktis", en: "Antarctica"},
            hashtags: %{de: "#Antarktis", en: "#Antarctica"},
            emoji: "❄️"
          },
          %{
            name: %{de: "Spanien", en: "Spain"},
            hashtags: %{de: "#Spanien", en: "#Spain"},
            emoji: "🇪🇸"
          },
          %{
            name: %{de: "Italien", en: "Italy"},
            hashtags: %{de: "#Italien", en: "#Italy"},
            emoji: "🇮🇹"
          },
          %{
            name: %{de: "Türkei", en: "Turkey"},
            hashtags: %{de: "#Türkei", en: "#Turkey"},
            emoji: "🇹🇷"
          },
          %{
            name: %{de: "Österreich", en: "Austria"},
            hashtags: %{de: "#Österreich", en: "#Austria"},
            emoji: "🇦🇹"
          },
          %{
            name: %{de: "Griechenland", en: "Greece"},
            hashtags: %{de: "#Griechenland", en: "#Greece"},
            emoji: "🇬🇷"
          },
          %{
            name: %{de: "Frankreich", en: "France"},
            hashtags: %{de: "#Frankreich", en: "#France"},
            emoji: "🇫🇷"
          },
          %{
            name: %{de: "Kroatien", en: "Croatia"},
            hashtags: %{de: "#Kroatien", en: "#Croatia"},
            emoji: "🇭🇷"
          },
          %{
            name: %{de: "Deutschland", en: "Germany"},
            hashtags: %{de: "#Deutschland", en: "#Germany"},
            emoji: "🇩🇪"
          },
          %{
            name: %{de: "Thailand", en: "Thailand"},
            hashtags: %{de: "#Thailand", en: "#Thailand"},
            emoji: "🇹🇭"
          },
          %{name: %{de: "USA", en: "USA"}, hashtags: %{de: "#USA", en: "#USA"}, emoji: "🇺🇸"},
          %{
            name: %{de: "Portugal", en: "Portugal"},
            hashtags: %{de: "#Portugal", en: "#Portugal"},
            emoji: "🇵🇹"
          },
          %{
            name: %{de: "Schweiz", en: "Switzerland"},
            hashtags: %{de: "#Schweiz", en: "#Switzerland"},
            emoji: "🇨🇭"
          },
          %{
            name: %{de: "Niederlande", en: "Netherlands"},
            hashtags: %{de: "#Niederlande", en: "#Netherlands"},
            emoji: "🇳🇱"
          },
          %{
            name: %{de: "Ägypten", en: "Egypt"},
            hashtags: %{de: "#Ägypten", en: "#Egypt"},
            emoji: "🇪🇬"
          },
          %{
            name: %{de: "Kanarische Inseln", en: "Canary Islands"},
            hashtags: %{de: "#KanarischeInseln", en: "#CanaryIslands"},
            emoji: "🌴"
          },
          %{
            name: %{de: "Mallorca", en: "Mallorca"},
            hashtags: %{de: "#Mallorca", en: "#Mallorca"},
            emoji: "🏝️"
          },
          %{name: %{de: "Bali", en: "Bali"}, hashtags: %{de: "#Bali", en: "#Bali"}, emoji: "🌺"},
          %{
            name: %{de: "Norwegen", en: "Norway"},
            hashtags: %{de: "#Norwegen", en: "#Norway"},
            emoji: "🇳🇴"
          },
          %{
            name: %{de: "Kanada", en: "Canada"},
            hashtags: %{de: "#Kanada", en: "#Canada"},
            emoji: "🇨🇦"
          },
          %{
            name: %{de: "Großbritannien", en: "United Kingdom"},
            hashtags: %{de: "#Großbritannien", en: "#UnitedKingdom"},
            emoji: "🇬🇧"
          }
        ]
      },
      %{
        category_id: "music",
        category_name: %{de: "Musik", en: "Music"},
        items: [
          %{name: %{de: "Pop", en: "Pop"}, hashtags: %{de: "#Pop", en: "#Pop"}, emoji: "🎤"},
          %{name: %{de: "Rock", en: "Rock"}, hashtags: %{de: "#Rock", en: "#Rock"}, emoji: "🎸"},
          %{
            name: %{de: "Hip-Hop", en: "Hip-Hop"},
            hashtags: %{de: "#HipHop", en: "#HipHop"},
            emoji: "🧢"
          },
          %{name: %{de: "Rap", en: "Rap"}, hashtags: %{de: "#Rap", en: "#Rap"}, emoji: "🎙️"},
          %{
            name: %{de: "Techno", en: "Techno"},
            hashtags: %{de: "#Techno", en: "#Techno"},
            emoji: "🎛️"
          },
          %{
            name: %{de: "Schlager", en: "Schlager"},
            hashtags: %{de: "#Schlager", en: "#Schlager"},
            emoji: "🍻"
          },
          %{
            name: %{de: "Klassik", en: "Classical"},
            hashtags: %{de: "#Klassik", en: "#Classical"},
            emoji: "🎻"
          },
          %{name: %{de: "Jazz", en: "Jazz"}, hashtags: %{de: "#Jazz", en: "#Jazz"}, emoji: "🎷"},
          %{
            name: %{de: "Heavy Metal", en: "Heavy Metal"},
            hashtags: %{de: "#HeavyMetal", en: "#HeavyMetal"},
            emoji: "🤘"
          },
          %{
            name: %{de: "Indie", en: "Indie"},
            hashtags: %{de: "#Indie", en: "#Indie"},
            emoji: "👓"
          },
          %{name: %{de: "Folk", en: "Folk"}, hashtags: %{de: "#Folk", en: "#Folk"}, emoji: "🪕"},
          %{
            name: %{de: "Volksmusik", en: "Folk Music"},
            hashtags: %{de: "#Volksmusik", en: "#FolkMusic"},
            emoji: "🏞️"
          },
          %{
            name: %{de: "Blues", en: "Blues"},
            hashtags: %{de: "#Blues", en: "#Blues"},
            emoji: "🎵"
          },
          %{
            name: %{de: "Reggae", en: "Reggae"},
            hashtags: %{de: "#Reggae", en: "#Reggae"},
            emoji: "🇯🇲"
          },
          %{name: %{de: "Soul", en: "Soul"}, hashtags: %{de: "#Soul", en: "#Soul"}, emoji: "💖"},
          %{
            name: %{de: "Country", en: "Country"},
            hashtags: %{de: "#Country", en: "#Country"},
            emoji: "🤠"
          },
          %{name: %{de: "R&B", en: "R&B"}, hashtags: %{de: "#RB", en: "#RnB"}, emoji: "💿"},
          %{
            name: %{de: "Elektro", en: "Electronic"},
            hashtags: %{de: "#Elektro", en: "#Electronic"},
            emoji: "🔊"
          },
          %{
            name: %{de: "House", en: "House"},
            hashtags: %{de: "#House", en: "#House"},
            emoji: "🏠🎶"
          },
          %{
            name: %{de: "Dance", en: "Dance"},
            hashtags: %{de: "#Dance", en: "#Dance"},
            emoji: "💃"
          },
          %{
            name: %{de: "Latin", en: "Latin"},
            hashtags: %{de: "#Latin", en: "#Latin"},
            emoji: "🕺"
          },
          %{name: %{de: "Punk", en: "Punk"}, hashtags: %{de: "#Punk", en: "#Punk"}, emoji: "🧷"},
          %{
            name: %{de: "Alternative", en: "Alternative"},
            hashtags: %{de: "#Alternative", en: "#Alternative"},
            emoji: "🚀"
          }
        ]
      },
      %{
        category_id: "movies",
        category_name: %{de: "Filme", en: "Movies"},
        items: [
          %{
            name: %{de: "Komödie", en: "Comedy"},
            hashtags: %{de: "#KomödieFilme", en: "#ComedyMovies"},
            emoji: "😄"
          },
          %{
            name: %{de: "Drama", en: "Drama"},
            hashtags: %{de: "#DramaFilme", en: "#DramaMovies"},
            emoji: "🎭"
          },
          %{
            name: %{de: "Thriller", en: "Thriller"},
            hashtags: %{de: "#ThrillerFilme", en: "#ThrillerMovies"},
            emoji: "🔪"
          },
          %{
            name: %{de: "Action", en: "Action"},
            hashtags: %{de: "#ActionFilme", en: "#ActionMovies"},
            emoji: "💥"
          },
          %{
            name: %{de: "Science-Fiction", en: "Science Fiction"},
            hashtags: %{de: "#ScienceFictionFilme", en: "#ScienceFictionMovies"},
            emoji: "👽"
          },
          %{
            name: %{de: "Horror", en: "Horror"},
            hashtags: %{de: "#HorrorFilme", en: "#HorrorMovies"},
            emoji: "😱"
          },
          %{
            name: %{de: "Romantik", en: "Romance"},
            hashtags: %{de: "#RomantikFilme", en: "#RomanceMovies"},
            emoji: "💘"
          },
          %{
            name: %{de: "Fantasy", en: "Fantasy"},
            hashtags: %{de: "#FantasyFilme", en: "#FantasyMovies"},
            emoji: "🧝"
          },
          %{
            name: %{de: "Krimi", en: "Crime"},
            hashtags: %{de: "#KrimiFilme", en: "#CrimeMovies"},
            emoji: "🕵️"
          },
          %{
            name: %{de: "Dokumentarfilme", en: "Documentaries"},
            hashtags: %{de: "#Dokumentarfilme", en: "#DocumentariesMovies"},
            emoji: "🎥"
          },
          %{
            name: %{de: "Historienfilme", en: "Historical Movies"},
            hashtags: %{de: "#Historienfilme", en: "#HistoricalMoviesMovies"},
            emoji: "🏰"
          },
          %{
            name: %{de: "Animationsfilme", en: "Animated Movies"},
            hashtags: %{de: "#Animationsfilme", en: "#AnimatedMoviesMovies"},
            emoji: "🐭"
          },
          %{
            name: %{de: "Abenteuer", en: "Adventure"},
            hashtags: %{de: "#AbenteuerFilme", en: "#AdventureMovies"},
            emoji: "🗺️"
          },
          %{
            name: %{de: "Kinder- und Familien", en: "Children and Family"},
            hashtags: %{de: "#KinderUndFamilien", en: "#ChildrenAndFamily"},
            emoji: "👨‍👩‍👧‍👦"
          },
          %{
            name: %{de: "Mystery", en: "Mystery"},
            hashtags: %{de: "#MysteryFilme", en: "#MysteryMovies"},
            emoji: "🔍"
          },
          %{
            name: %{de: "Romcom", en: "Romantic Comedy"},
            hashtags: %{de: "#RomcomFilme", en: "#RomanticComedyMovies"},
            emoji: "😂💕"
          },
          %{
            name: %{de: "Superhelden", en: "Superheroes"},
            hashtags: %{de: "#SuperheldenFilme", en: "#SuperheroesMovies"},
            emoji: "🦸"
          },
          %{
            name: %{de: "Gameshows", en: "Game Shows"},
            hashtags: %{de: "#GameshowsFilme", en: "#GameShowsMovies"},
            emoji: "🎲"
          },
          %{
            name: %{de: "Reality TV", en: "Reality TV"},
            hashtags: %{de: "#RealityTVFilme", en: "#RealityTVMovies"},
            emoji: "📺"
          },
          %{
            name: %{de: "Kochsendungen", en: "Cooking Shows"},
            hashtags: %{de: "#KochsendungenFilme", en: "#CookingShowsMovies"},
            emoji: "👩‍🍳"
          },
          %{
            name: %{de: "Tatort", en: "Crime Scene"},
            hashtags: %{de: "#TatortFilme", en: "#CrimeSceneMovies"},
            emoji: "🔎"
          },
          %{
            name: %{de: "Erotik", en: "Erotica"},
            hashtags: %{de: "#ErotikFilme", en: "#EroticaMovies"},
            emoji: "💋"
          }
        ]
      },
      %{
        category_id: "literature",
        category_name: %{de: "Literatur", en: "Literature"},
        items: [
          %{
            name: %{de: "Krimi", en: "Crime"},
            hashtags: %{de: "#KrimiLit", en: "#CrimeLit"},
            emoji: "🔍"
          },
          %{
            name: %{de: "Romane", en: "Novels"},
            hashtags: %{de: "#RomaneLit", en: "#NovelsLit"},
            emoji: "📚"
          },
          %{
            name: %{de: "Liebesromane", en: "Romance Novels"},
            hashtags: %{de: "#LiebesromaneLit", en: "#RomanceNovelsLit"},
            emoji: "❤️"
          },
          %{
            name: %{de: "Historische Romane", en: "Historical Novels"},
            hashtags: %{de: "#HistorischeRomaneLit", en: "#HistoricalNovelsLit"},
            emoji: "🏰"
          },
          %{
            name: %{de: "Fantasy", en: "Fantasy"},
            hashtags: %{de: "#FantasyLit", en: "#FantasyLit"},
            emoji: "🐉"
          },
          %{
            name: %{de: "Science-Fiction", en: "Science Fiction"},
            hashtags: %{de: "#ScienceFictionLit", en: "#ScienceFictionLit"},
            emoji: "🚀"
          },
          %{
            name: %{de: "Sachbücher", en: "Non-Fiction"},
            hashtags: %{de: "#SachbücherLit", en: "#NonFictionLit"},
            emoji: "📘"
          },
          %{
            name: %{de: "Biografien", en: "Biographies"},
            hashtags: %{de: "#BiografienLit", en: "#BiographiesLit"},
            emoji: "👤"
          },
          %{
            name: %{de: "Erotik", en: "Erotica"},
            hashtags: %{de: "#ErotikLit", en: "#EroticaLit"},
            emoji: "💋"
          },
          %{
            name: %{
              de: "Kinder- und Jugend",
              en: "Children's and Young Adult"
            },
            hashtags: %{
              de: "#KinderUndJugendLit",
              en: "#ChildrensAndYoungAdultLit"
            },
            emoji: "👧👦"
          },
          %{
            name: %{de: "Humor", en: "Humor"},
            hashtags: %{de: "#HumorLit", en: "#HumorLit"},
            emoji: "😄"
          },
          %{
            name: %{de: "Klassiker", en: "Classics"},
            hashtags: %{de: "#KlassikerLit", en: "#ClassicsLit"},
            emoji: "📖"
          },
          %{
            name: %{de: "Horror", en: "Horror"},
            hashtags: %{de: "#HorrorLit", en: "#HorrorLit"},
            emoji: "👻"
          },
          %{
            name: %{de: "Ratgeber", en: "Guidebooks"},
            hashtags: %{de: "#RatgeberLit", en: "#GuidebooksLit"},
            emoji: "📙"
          },
          %{
            name: %{de: "Poesie", en: "Poetry"},
            hashtags: %{de: "#PoesieLit", en: "#PoetryLit"},
            emoji: "🍂"
          },
          %{
            name: %{de: "Abenteuer", en: "Adventure"},
            hashtags: %{de: "#AbenteuerLit", en: "#AdventureLit"},
            emoji: "🌍"
          },
          %{
            name: %{de: "Philosophie", en: "Philosophy"},
            hashtags: %{de: "#PhilosophieLit", en: "#PhilosophyLit"},
            emoji: "💭"
          },
          %{
            name: %{de: "Thriller", en: "Thriller"},
            hashtags: %{de: "#ThrillerLit", en: "#ThrillerLit"},
            emoji: "💣"
          },
          %{
            name: %{de: "Psychologie", en: "Psychology"},
            hashtags: %{de: "#PsychologieLit", en: "#PsychologyLit"},
            emoji: "🧠"
          },
          %{
            name: %{de: "Wissenschaft", en: "Science"},
            hashtags: %{de: "#WissenschaftLit", en: "#ScienceLit"},
            emoji: "🔬"
          }
        ]
      },
      %{
        category_id: "at_home",
        category_name: %{de: "Zu Hause", en: "At Home"},
        items: [
          %{
            name: %{de: "Kochen", en: "Cooking"},
            hashtags: %{de: "#Kochen", en: "#Cooking"},
            emoji: "🍳"
          },
          %{
            name: %{de: "Backen", en: "Baking"},
            hashtags: %{de: "#Backen", en: "#Baking"},
            emoji: "🍰"
          },
          %{
            name: %{de: "Lesen", en: "Reading"},
            hashtags: %{de: "#Lesen", en: "#Reading"},
            emoji: "📖"
          },
          %{
            name: %{de: "Filme", en: "Movies"},
            hashtags: %{de: "#Filme", en: "#Movies"},
            emoji: "🎬"
          },
          %{
            name: %{de: "Serien", en: "Series"},
            hashtags: %{de: "#Serien", en: "#Series"},
            emoji: "📺"
          },
          %{
            name: %{de: "Online-Kurse", en: "Online Courses"},
            hashtags: %{de: "#OnlineKurse", en: "#OnlineCourses"},
            emoji: "💻"
          },
          %{
            name: %{de: "Fitnessübungen", en: "Fitness Exercises"},
            hashtags: %{de: "#Fitnessübungen", en: "#FitnessExercises"},
            emoji: "🏋️‍♂️"
          },
          %{
            name: %{de: "Gartenarbeit", en: "Gardening"},
            hashtags: %{de: "#Gartenarbeit", en: "#Gardening"},
            emoji: "🌱"
          },
          %{
            name: %{de: "Handarbeiten", en: "Handicrafts"},
            hashtags: %{de: "#Handarbeiten", en: "#Handicrafts"},
            emoji: "🧵"
          },
          %{
            name: %{de: "Zeichnen", en: "Drawing"},
            hashtags: %{de: "#Zeichnen", en: "#Drawing"},
            emoji: "🎨"
          },
          %{
            name: %{de: "Musik", en: "Music"},
            hashtags: %{de: "#Musik", en: "#Music"},
            emoji: "🎵"
          },
          %{
            name: %{de: "Puzzles", en: "Puzzles"},
            hashtags: %{de: "#Puzzles", en: "#Puzzles"},
            emoji: "🧩"
          },
          %{
            name: %{de: "Brettspiele", en: "Board Games"},
            hashtags: %{de: "#Brettspiele", en: "#BoardGames"},
            emoji: "🎲"
          },
          %{
            name: %{de: "Meditation", en: "Meditation"},
            hashtags: %{de: "#Meditation", en: "#Meditation"},
            emoji: "🧘"
          },
          %{
            name: %{de: "DIY-Projekte", en: "DIY Projects"},
            hashtags: %{de: "#DIYProjekte", en: "#DIYProjects"},
            emoji: "🔨"
          },
          %{
            name: %{de: "Tagebuch schreiben", en: "Journaling"},
            hashtags: %{de: "#TagebuchSchreiben", en: "#Journaling"},
            emoji: "📓"
          },
          %{
            name: %{de: "Podcasts", en: "Podcasts"},
            hashtags: %{de: "#Podcasts", en: "#Podcasts"},
            emoji: "🎧"
          },
          %{
            name: %{de: "Hörbücher", en: "Audiobooks"},
            hashtags: %{de: "#Hörbücher", en: "#Audiobooks"},
            emoji: "🔊"
          },
          %{
            name: %{de: "Videospiele", en: "Video Games"},
            hashtags: %{de: "#Videospiele", en: "#VideoGames"},
            emoji: "🎮"
          }
        ]
      },
      %{
        category_id: "creativity",
        category_name: %{de: "Kreativität", en: "Creativity"},
        items: [
          %{
            name: %{de: "Fotografie", en: "Photography"},
            hashtags: %{de: "#Fotografie", en: "#Photography"},
            emoji: "📷"
          },
          %{
            name: %{de: "Design", en: "Design"},
            hashtags: %{de: "#Design", en: "#Design"},
            emoji: "🎨"
          },
          %{
            name: %{de: "Handarbeit", en: "Crafting"},
            hashtags: %{de: "#Handarbeit", en: "#Crafting"},
            emoji: "🧶"
          },
          %{name: %{de: "Kunst", en: "Art"}, hashtags: %{de: "#Kunst", en: "#Art"}, emoji: "🖌️"},
          %{
            name: %{de: "Make-up", en: "Make-up"},
            hashtags: %{de: "#MakeUp", en: "#MakeUp"},
            emoji: "💄"
          },
          %{
            name: %{de: "Schreiben", en: "Writing"},
            hashtags: %{de: "#Schreiben", en: "#Writing"},
            emoji: "✍️"
          },
          %{
            name: %{de: "Singen", en: "Singing"},
            hashtags: %{de: "#Singen", en: "#Singing"},
            emoji: "🎤"
          },
          %{
            name: %{de: "Tanzen", en: "Dancing"},
            hashtags: %{de: "#Tanzen", en: "#Dancing"},
            emoji: "💃"
          },
          %{
            name: %{de: "Videos drehen", en: "Video Production"},
            hashtags: %{de: "#VideosDrehen", en: "#VideoProduction"},
            emoji: "🎥"
          },
          %{
            name: %{de: "Social Media", en: "Social Media"},
            hashtags: %{de: "#SocialMedia", en: "#SocialMedia"},
            emoji: "📱"
          },
          %{
            name: %{de: "Musik machen", en: "Making Music"},
            hashtags: %{de: "#MusikMachen", en: "#MakingMusic"},
            emoji: "🎶"
          },
          %{
            name: %{de: "Schauspielen", en: "Acting"},
            hashtags: %{de: "#Schauspielen", en: "#Acting"},
            emoji: "🎭"
          },
          %{
            name: %{de: "Malen", en: "Painting"},
            hashtags: %{de: "#Malen", en: "#Painting"},
            emoji: "🖼️"
          },
          %{
            name: %{de: "Häkeln", en: "Crocheting"},
            hashtags: %{de: "#Häkeln", en: "#Crocheting"},
            emoji: "🧵"
          },
          %{
            name: %{de: "Stricken", en: "Knitting"},
            hashtags: %{de: "#Stricken", en: "#Knitting"},
            emoji: "🧶"
          },
          %{
            name: %{de: "Nähen", en: "Sewing"},
            hashtags: %{de: "#Nähen", en: "#Sewing"},
            emoji: "🪡"
          }
        ]
      },
      %{
        category_id: "going_out",
        category_name: %{de: "Ausgehen", en: "Going Out"},
        items: [
          %{name: %{de: "Bars", en: "Bars"}, hashtags: %{de: "#Bars", en: "#Bars"}, emoji: "🍹"},
          %{
            name: %{de: "Cafés", en: "Cafes"},
            hashtags: %{de: "#Cafés", en: "#Cafes"},
            emoji: "☕"
          },
          %{
            name: %{de: "Clubbing", en: "Clubbing"},
            hashtags: %{de: "#Clubbing", en: "#Clubbing"},
            emoji: "🎉"
          },
          %{
            name: %{de: "Drag-Shows", en: "Drag Shows"},
            hashtags: %{de: "#DragShows", en: "#DragShows"},
            emoji: "💃"
          },
          %{
            name: %{de: "Festivals", en: "Festivals"},
            hashtags: %{de: "#Festivals", en: "#Festivals"},
            emoji: "🎪"
          },
          %{
            name: %{de: "Karaoke", en: "Karaoke"},
            hashtags: %{de: "#Karaoke", en: "#Karaoke"},
            emoji: "🎤"
          },
          %{
            name: %{de: "Konzerte", en: "Concerts"},
            hashtags: %{de: "#Konzerte", en: "#Concerts"},
            emoji: "🎵"
          },
          %{
            name: %{de: "LGBTQ+-Nightlife", en: "LGBTQ+ Nightlife"},
            hashtags: %{de: "#LGBTQPlusNightlife", en: "#LGBTQPlusNightlife"},
            emoji: "🌈"
          },
          %{
            name: %{de: "Museen & Galerien", en: "Museums & Galleries"},
            hashtags: %{de: "#MuseenUndGalerien", en: "#MuseumsAndGalleries"},
            emoji: "🖼️"
          },
          %{
            name: %{de: "Stand-Up Comedy", en: "Stand-Up Comedy"},
            hashtags: %{de: "#StandUpComedy", en: "#StandUpComedy"},
            emoji: "😆"
          },
          %{
            name: %{de: "Theater", en: "Theater"},
            hashtags: %{de: "#Theater", en: "#Theater"},
            emoji: "🎭"
          }
        ]
      },
      %{
        category_id: "self_care",
        category_name: %{de: "Selbstfürsorge", en: "Self Care"},
        items: [
          %{
            name: %{de: "Guter Schlaf", en: "Good Sleep"},
            hashtags: %{de: "#GuterSchlaf", en: "#GoodSleep"},
            emoji: "😴"
          },
          %{
            name: %{de: "Tiefe Gespräche", en: "Deep Conversations"},
            hashtags: %{de: "#TiefeGespräche", en: "#DeepConversations"},
            emoji: "💬"
          },
          %{
            name: %{de: "Achtsamkeit", en: "Mindfulness"},
            hashtags: %{de: "#Achtsamkeit", en: "#Mindfulness"},
            emoji: "🧘"
          },
          %{
            name: %{de: "Counseling", en: "Counseling"},
            hashtags: %{de: "#Counseling", en: "#Counseling"},
            emoji: "👥"
          },
          %{
            name: %{de: "Ernährung", en: "Nutrition"},
            hashtags: %{de: "#Ernährung", en: "#Nutrition"},
            emoji: "🍏"
          },
          %{
            name: %{de: "Offline gehen", en: "Going Offline"},
            hashtags: %{de: "#OfflineGehen", en: "#GoingOffline"},
            emoji: "📵"
          },
          %{
            name: %{de: "Sex Positivity", en: "Sex Positivity"},
            hashtags: %{de: "#SexPositivity", en: "#SexPositivity"},
            emoji: "❤️‍🔥"
          }
        ]
      },
      %{
        category_id: "politics",
        category_name: %{de: "Politik", en: "Politics"},
        items: [
          %{
            name: %{
              de: "CDU",
              en: "CDU"
            },
            hashtags: %{de: "#CDU", en: "#CDU"},
            emoji: nil
          },
          %{
            name: %{
              de: "SPD",
              en: "SPD"
            },
            hashtags: %{de: "#SPD", en: "#SPD"},
            emoji: nil
          },
          %{
            name: %{de: "Die Grünen", en: "Die Grünen"},
            hashtags: %{de: "#Grüne", en: "#Greens"},
            emoji: nil
          },
          %{
            name: %{de: "FDP", en: "FDP"},
            hashtags: %{de: "#FDP", en: "#FDP"},
            emoji: nil
          },
          %{
            name: %{de: "AfD", en: "AfD"},
            hashtags: %{de: "#AfD", en: "#AfD"},
            emoji: nil
          },
          %{
            name: %{de: "Die Linke", en: "The Left"},
            hashtags: %{de: "#DieLinke", en: "#TheLeft"},
            emoji: nil
          },
          %{
            name: %{
              de: "CSU",
              en: "CSU"
            },
            hashtags: %{de: "#CSU", en: "#CSU"},
            emoji: nil
          }
        ]
      },
      %{
        category_id: "religion",
        category_name: %{de: "Religion", en: "Religion"},
        items: [
          %{
            name: %{de: "Römisch-Katholische", en: "Roman Catholic"},
            hashtags: %{de: "#Katholisch", en: "#Catholic"},
            emoji: "✝️"
          },
          %{
            name: %{de: "Evangelisch", en: "Protestant"},
            hashtags: %{de: "#Evangelisch", en: "#Protestant"},
            emoji: "✝️"
          },
          %{
            name: %{de: "Orthodoxes Christentum", en: "Orthodox Christianity"},
            hashtags: %{de: "#Orthodox", en: "#Orthodox"},
            emoji: "☦️"
          },
          %{
            name: %{de: "Islam", en: "Islam"},
            hashtags: %{de: "#Islam", en: "#Islam"},
            emoji: "☪️"
          },
          %{
            name: %{de: "Judentum", en: "Judaism"},
            hashtags: %{de: "#Judentum", en: "#Judaism"},
            emoji: "✡️"
          },
          %{
            name: %{de: "Buddhismus", en: "Buddhism"},
            hashtags: %{de: "#Buddhismus", en: "#Buddhism"},
            emoji: "☸️"
          },
          %{
            name: %{de: "Hinduismus", en: "Hinduism"},
            hashtags: %{de: "#Hinduismus", en: "#Hinduism"},
            emoji: "🕉️"
          },
          %{
            name: %{de: "Atheismus", en: "Atheism"},
            hashtags: %{de: "#Atheismus", en: "#Atheism"},
            emoji: "⚛️"
          },
          %{
            name: %{de: "Agnostizismus", en: "Agnosticism"},
            hashtags: %{de: "#Agnostizismus", en: "#Agnosticism"},
            emoji: "❓"
          },
          %{
            name: %{de: "Spiritualität", en: "Spirituality"},
            hashtags: %{de: "#Spiritualität", en: "#Spirituality"},
            emoji: "🕊️"
          }
        ]
      }
    ]
  end
end
