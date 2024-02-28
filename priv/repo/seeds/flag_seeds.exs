# Script for populating the database with flag data. You can run it as:
#
#     mix run priv/repo/seeds/flag_seeds.exs

[
  %{
    category_id: "sports",
    category_name: %{de: "Sport", en: "Sports"},
    items: [
      %{name: %{de: "Fußball", en: "Soccer"}, hashtags: %{de: "#Fußball", en: "#Soccer"}},
      %{name: %{de: "Turnen", en: "Gymnastics"}, hashtags: %{de: "#Turnen", en: "#Gymnastics"}},
      %{name: %{de: "Tennis", en: "Tennis"}, hashtags: %{de: "#Tennis", en: "#Tennis"}},
      %{name: %{de: "Wandern", en: "Hiking"}, hashtags: %{de: "#Wandern", en: "#Hiking"}},
      %{name: %{de: "Klettern", en: "Climbing"}, hashtags: %{de: "#Klettern", en: "#Climbing"}},
      %{name: %{de: "Ski", en: "Skiing"}, hashtags: %{de: "#Ski", en: "#Skiing"}},
      %{
        name: %{de: "Leichtathletik", en: "Athletics"},
        hashtags: %{de: "#Leichtathletik", en: "#Athletics"}
      },
      %{name: %{de: "Handball", en: "Handball"}, hashtags: %{de: "#Handball", en: "#Handball"}},
      %{
        name: %{de: "Reiten", en: "Horse Riding"},
        hashtags: %{de: "#Reiten", en: "#HorseRiding"}
      },
      %{name: %{de: "Golf", en: "Golf"}, hashtags: %{de: "#Golf", en: "#Golf"}},
      %{
        name: %{de: "Schwimmen", en: "Swimming"},
        hashtags: %{de: "#Schwimmen", en: "#Swimming"}
      },
      %{
        name: %{de: "Volleyball", en: "Volleyball"},
        hashtags: %{de: "#Volleyball", en: "#Volleyball"}
      },
      %{
        name: %{de: "Basketball", en: "Basketball"},
        hashtags: %{de: "#Basketball", en: "#Basketball"}
      },
      %{
        name: %{de: "Eishockey", en: "Ice Hockey"},
        hashtags: %{de: "#Eishockey", en: "#IceHockey"}
      },
      %{
        name: %{de: "Tischtennis", en: "Table Tennis"},
        hashtags: %{de: "#Tischtennis", en: "#TableTennis"}
      },
      %{
        name: %{de: "Badminton", en: "Badminton"},
        hashtags: %{de: "#Badminton", en: "#Badminton"}
      },
      %{name: %{de: "Yoga", en: "Yoga"}, hashtags: %{de: "#Yoga", en: "#Yoga"}},
      %{name: %{de: "Tauchen", en: "Diving"}, hashtags: %{de: "#Tauchen", en: "#Diving"}},
      %{name: %{de: "Surfen", en: "Surfing"}, hashtags: %{de: "#Surfen", en: "#Surfing"}},
      %{name: %{de: "Segeln", en: "Sailing"}, hashtags: %{de: "#Segeln", en: "#Sailing"}},
      %{name: %{de: "Rudern", en: "Rowing"}, hashtags: %{de: "#Rudern", en: "#Rowing"}},
      %{name: %{de: "Boxen", en: "Boxing"}, hashtags: %{de: "#Boxen", en: "#Boxing"}},
      %{name: %{de: "Radfahren", en: "Cycling"}, hashtags: %{de: "#Radfahren", en: "#Cycling"}},
      %{name: %{de: "Joggen", en: "Jogging"}, hashtags: %{de: "#Joggen", en: "#Jogging"}},
      %{name: %{de: "Pilates", en: "Pilates"}, hashtags: %{de: "#Pilates", en: "#Pilates"}},
      %{name: %{de: "Fitnessstudio", en: "Gym"}, hashtags: %{de: "#Fitnessstudio", en: "#Gym"}},
      %{
        name: %{de: "Kampfsport", en: "Martial Arts"},
        hashtags: %{de: "#Kampfsport", en: "#MartialArts"}
      }
    ]
  },
  %{
    category_id: "characters",
    category_name: %{de: "Charakter", en: "Character"},
    items: [
      %{
        name: %{de: "Bescheidenheit", en: "Modesty"},
        hashtags: %{de: "#Bescheidenheit", en: "#Modesty"}
      },
      %{
        name: %{de: "Gerechtigkeitssinn", en: "Sense of Justice"},
        hashtags: %{de: "#Gerechtigkeitssinn", en: "#SenseOfJustice"}
      },
      %{
        name: %{de: "Ehrlichkeit", en: "Honesty"},
        hashtags: %{de: "#Ehrlichkeit", en: "#Honesty"}
      },
      %{name: %{de: "Mut", en: "Courage"}, hashtags: %{de: "#Mut", en: "#Courage"}},
      %{
        name: %{de: "Widerstandsfähigkeit", en: "Resilience"},
        hashtags: %{de: "#Widerstandsfähigkeit", en: "#Resilience"}
      },
      %{
        name: %{de: "Verantwortungsbewusstsein", en: "Sense of Responsibility"},
        hashtags: %{de: "#Verantwortungsbewusstsein", en: "#SenseOfResponsibility"}
      },
      %{name: %{de: "Humor", en: "Humor"}, hashtags: %{de: "#Humor", en: "#Humor"}},
      %{
        name: %{de: "Fürsorglichkeit", en: "Caring"},
        hashtags: %{de: "#Fürsorglichkeit", en: "#Caring"}
      },
      %{
        name: %{de: "Großzügigkeit", en: "Generosity"},
        hashtags: %{de: "#Großzügigkeit", en: "#Generosity"}
      },
      %{
        name: %{de: "Selbstakzeptanz", en: "Self-Acceptance"},
        hashtags: %{de: "#Selbstakzeptanz", en: "#SelfAcceptance"}
      },
      %{
        name: %{de: "Familienorientiert", en: "Family-Oriented"},
        hashtags: %{de: "#Familienorientiert", en: "#FamilyOriented"}
      },
      %{
        name: %{de: "Intelligenz", en: "Intelligence"},
        hashtags: %{de: "#Intelligenz", en: "#Intelligence"}
      },
      %{
        name: %{de: "Abenteuerlust", en: "Love of Adventure"},
        hashtags: %{de: "#Abenteuerlust", en: "#LoveOfAdventure"}
      },
      %{name: %{de: "Aktiv", en: "Active"}, hashtags: %{de: "#Aktiv", en: "#Active"}},
      %{name: %{de: "Empathie", en: "Empathy"}, hashtags: %{de: "#Empathie", en: "#Empathy"}},
      %{
        name: %{de: "Kreativität", en: "Creativity"},
        hashtags: %{de: "#Kreativität", en: "#Creativity"}
      },
      %{
        name: %{de: "Optimismus", en: "Optimism"},
        hashtags: %{de: "#Optimismus", en: "#Optimism"}
      },
      %{
        name: %{de: "Romantisch sein", en: "Being Romantic"},
        hashtags: %{de: "#RomantischSein", en: "#BeingRomantic"}
      },
      %{
        name: %{de: "Selbstvertrauen", en: "Self-Confidence"},
        hashtags: %{de: "#Selbstvertrauen", en: "#SelfConfidence"}
      },
      %{
        name: %{de: "Soziales Bewusstsein", en: "Social Awareness"},
        hashtags: %{de: "#SozialesBewusstsein", en: "#SocialAwareness"}
      }
    ]
  },
  %{
    category_id: "travels",
    category_name: %{de: "Reisen", en: "Travels"},
    items: [
      %{
        name: %{de: "Strandurlaub", en: "Beach Vacation"},
        hashtags: %{de: "#Strandurlaub", en: "#BeachVacation"}
      },
      %{
        name: %{de: "Städtereisen", en: "City Trips"},
        hashtags: %{de: "#Städtereisen", en: "#CityTrips"}
      },
      %{
        name: %{de: "Wanderurlaub", en: "Hiking Vacation"},
        hashtags: %{de: "#Wanderurlaub", en: "#HikingVacation"}
      },
      %{
        name: %{de: "Skiurlaub", en: "Ski Vacation"},
        hashtags: %{de: "#Skiurlaub", en: "#SkiVacation"}
      },
      %{
        name: %{de: "Kreuzfahrten", en: "Cruises"},
        hashtags: %{de: "#Kreuzfahrten", en: "#Cruises"}
      },
      %{
        name: %{de: "Fahrradtouren", en: "Bike Tours"},
        hashtags: %{de: "#Fahrradtouren", en: "#BikeTours"}
      },
      %{name: %{de: "Wellness", en: "Wellness"}, hashtags: %{de: "#Wellness", en: "#Wellness"}},
      %{
        name: %{de: "Aktiv und Sporturlaub", en: "Active and Sports Vacation"},
        hashtags: %{de: "#AktivUndSporturlaub", en: "#ActiveAndSportsVacation"}
      },
      %{
        name: %{de: "Campingurlaub", en: "Camping Vacation"},
        hashtags: %{de: "#Campingurlaub", en: "#CampingVacation"}
      },
      %{
        name: %{de: "Kulturreisen", en: "Cultural Trips"},
        hashtags: %{de: "#Kulturreisen", en: "#CulturalTrips"}
      },
      %{
        name: %{de: "Wintersport", en: "Winter Sports"},
        hashtags: %{de: "#Wintersport", en: "#WinterSports"}
      }
    ]
  },
  %{
    category_id: "favorite_destinations",
    category_name: %{de: "Lieblingsziele", en: "Favorite Destinations"},
    items: [
      %{name: %{de: "Spanien", en: "Spain"}, hashtags: %{de: "#Spanien", en: "#Spain"}},
      %{name: %{de: "Italien", en: "Italy"}, hashtags: %{de: "#Italien", en: "#Italy"}},
      %{name: %{de: "Türkei", en: "Turkey"}, hashtags: %{de: "#Türkei", en: "#Turkey"}},
      %{
        name: %{de: "Österreich", en: "Austria"},
        hashtags: %{de: "#Österreich", en: "#Austria"}
      },
      %{
        name: %{de: "Griechenland", en: "Greece"},
        hashtags: %{de: "#Griechenland", en: "#Greece"}
      },
      %{name: %{de: "Frankreich", en: "France"}, hashtags: %{de: "#Frankreich", en: "#France"}},
      %{name: %{de: "Kroatien", en: "Croatia"}, hashtags: %{de: "#Kroatien", en: "#Croatia"}},
      %{
        name: %{de: "Deutschland", en: "Germany"},
        hashtags: %{de: "#Deutschland", en: "#Germany"}
      },
      %{name: %{de: "Thailand", en: "Thailand"}, hashtags: %{de: "#Thailand", en: "#Thailand"}},
      %{name: %{de: "USA", en: "USA"}, hashtags: %{de: "#USA", en: "#USA"}},
      %{name: %{de: "Portugal", en: "Portugal"}, hashtags: %{de: "#Portugal", en: "#Portugal"}},
      %{
        name: %{de: "Schweiz", en: "Switzerland"},
        hashtags: %{de: "#Schweiz", en: "#Switzerland"}
      },
      %{
        name: %{de: "Niederlande", en: "Netherlands"},
        hashtags: %{de: "#Niederlande", en: "#Netherlands"}
      },
      %{name: %{de: "Ägypten", en: "Egypt"}, hashtags: %{de: "#Ägypten", en: "#Egypt"}},
      %{
        name: %{de: "Kanarische Inseln", en: "Canary Islands"},
        hashtags: %{de: "#KanarischeInseln", en: "#CanaryIslands"}
      },
      %{name: %{de: "Mallorca", en: "Mallorca"}, hashtags: %{de: "#Mallorca", en: "#Mallorca"}},
      %{name: %{de: "Bali", en: "Bali"}, hashtags: %{de: "#Bali", en: "#Bali"}},
      %{name: %{de: "Norwegen", en: "Norway"}, hashtags: %{de: "#Norwegen", en: "#Norway"}},
      %{name: %{de: "Kanada", en: "Canada"}, hashtags: %{de: "#Kanada", en: "#Canada"}},
      %{
        name: %{de: "Großbritannien", en: "United Kingdom"},
        hashtags: %{de: "#Großbritannien", en: "#UnitedKingdom"}
      },
      %{name: %{de: "Europa", en: "Europe"}, hashtags: %{de: "#Europa", en: "#Europe"}},
      %{name: %{de: "Asien", en: "Asia"}, hashtags: %{de: "#Asien", en: "#Asia"}},
      %{name: %{de: "Afrika", en: "Africa"}, hashtags: %{de: "#Afrika", en: "#Africa"}},
      %{
        name: %{de: "Nordamerika", en: "North America"},
        hashtags: %{de: "#Nordamerika", en: "#NorthAmerica"}
      },
      %{
        name: %{de: "Südamerika", en: "South America"},
        hashtags: %{de: "#Südamerika", en: "#SouthAmerica"}
      },
      %{
        name: %{de: "Australien", en: "Australia"},
        hashtags: %{de: "#Australien", en: "#Australia"}
      },
      %{
        name: %{de: "Antarktis", en: "Antarctica"},
        hashtags: %{de: "#Antarktis", en: "#Antarctica"}
      }
    ]
  },
  %{
    category_id: "animals",
    category_name: %{de: "Tiere", en: "Animals"},
    items: [
      %{name: %{de: "Katze", en: "Cat"}, hashtags: %{de: "#Katze", en: "#Cat"}},
      %{name: %{de: "Hund", en: "Dog"}, hashtags: %{de: "#Hund", en: "#Dog"}},
      %{name: %{de: "Kaninchen", en: "Rabbit"}, hashtags: %{de: "#Kaninchen", en: "#Rabbit"}},
      %{
        name: %{de: "Meerschweinchen", en: "Guinea Pig"},
        hashtags: %{de: "#Meerschweinchen", en: "#GuineaPig"}
      },
      %{name: %{de: "Hamster", en: "Hamster"}, hashtags: %{de: "#Hamster", en: "#Hamster"}},
      %{name: %{de: "Vogel", en: "Bird"}, hashtags: %{de: "#Vogel", en: "#Bird"}},
      %{name: %{de: "Fisch", en: "Fish"}, hashtags: %{de: "#Fisch", en: "#Fish"}},
      %{name: %{de: "Reptil", en: "Reptile"}, hashtags: %{de: "#Reptil", en: "#Reptile"}},
      %{name: %{de: "Maus", en: "Mouse"}, hashtags: %{de: "#Maus", en: "#Mouse"}},
      %{name: %{de: "Spinne", en: "Spider"}, hashtags: %{de: "#Spinne", en: "#Spider"}},
      %{name: %{de: "Pferd", en: "Horse"}, hashtags: %{de: "#Pferd", en: "#Horse"}}
    ]
  },
  %{
    category_id: "food",
    category_name: %{de: "Essen", en: "Food"},
    items: [
      %{name: %{de: "Vegan", en: "Vegan"}, hashtags: %{de: "#Vegan", en: "#Vegan"}},
      %{
        name: %{de: "Vegetarier", en: "Vegetarian"},
        hashtags: %{de: "#Vegetarier", en: "#Vegetarian"}
      },
      %{
        name: %{de: "Italienisch", en: "Italian"},
        hashtags: %{de: "#Italienisch", en: "#Italian"}
      },
      %{
        name: %{de: "Chinesisch", en: "Chinese"},
        hashtags: %{de: "#Chinesisch", en: "#Chinese"}
      },
      %{name: %{de: "Indisch", en: "Indian"}, hashtags: %{de: "#Indisch", en: "#Indian"}},
      %{
        name: %{de: "Französisch", en: "French"},
        hashtags: %{de: "#Französisch", en: "#French"}
      },
      %{name: %{de: "Spanisch", en: "Spanish"}, hashtags: %{de: "#Spanisch", en: "#Spanish"}},
      %{
        name: %{de: "Mexikanisch", en: "Mexican"},
        hashtags: %{de: "#Mexikanisch", en: "#Mexican"}
      },
      %{
        name: %{de: "Japanisch", en: "Japanese"},
        hashtags: %{de: "#Japanisch", en: "#Japanese"}
      },
      %{name: %{de: "Türkisch", en: "Turkish"}, hashtags: %{de: "#Türkisch", en: "#Turkish"}},
      %{name: %{de: "Thai", en: "Thai"}, hashtags: %{de: "#Thai", en: "#Thai"}},
      %{name: %{de: "Griechisch", en: "Greek"}, hashtags: %{de: "#Griechisch", en: "#Greek"}},
      %{
        name: %{de: "Amerikanisch", en: "American"},
        hashtags: %{de: "#Amerikanisch", en: "#American"}
      },
      %{
        name: %{de: "Vietnamesisch", en: "Vietnamese"},
        hashtags: %{de: "#Vietnamesisch", en: "#Vietnamese"}
      },
      %{name: %{de: "Koreanisch", en: "Korean"}, hashtags: %{de: "#Koreanisch", en: "#Korean"}},
      %{name: %{de: "Deutsch", en: "German"}, hashtags: %{de: "#Deutsch", en: "#German"}},
      %{
        name: %{de: "Mediterran", en: "Mediterranean"},
        hashtags: %{de: "#Mediterran", en: "#Mediterranean"}
      },
      %{
        name: %{de: "Fast Food", en: "Fast Food"},
        hashtags: %{de: "#FastFood", en: "#FastFood"}
      },
      %{
        name: %{de: "Street Food", en: "Street Food"},
        hashtags: %{de: "#StreetFood", en: "#StreetFood"}
      },
      %{
        name: %{de: "Gesundes Essen", en: "Healthy Food"},
        hashtags: %{de: "#GesundesEssen", en: "#HealthyFood"}
      },
      %{name: %{de: "Desserts", en: "Desserts"}, hashtags: %{de: "#Desserts", en: "#Desserts"}},
      %{name: %{de: "Backwaren", en: "Pastries"}, hashtags: %{de: "#Backwaren", en: "#Pastries"}},
      %{name: %{de: "Grillen", en: "BBQ"}, hashtags: %{de: "#Grillen", en: "#BBQ"}},
      %{
        name: %{de: "Frühstück", en: "Breakfast"},
        hashtags: %{de: "#Frühstück", en: "#Breakfast"}
      },
      %{name: %{de: "Snacks", en: "Snacks"}, hashtags: %{de: "#Snacks", en: "#Snacks"}}
    ]
  },
  %{
    category_id: "drinks",
    category_name: %{de: "Trinken", en: "Drinks"},
    items: [
      %{
        name: %{de: "Spirituosen", en: "Spirits"},
        hashtags: %{de: "#Spirituosen", en: "#Spirits"}
      },
      %{name: %{de: "Wasser", en: "Water"}, hashtags: %{de: "#Wasser", en: "#Water"}},
      %{name: %{de: "Kaffee", en: "Coffee"}, hashtags: %{de: "#Kaffee", en: "#Coffee"}},
      %{name: %{de: "Tee", en: "Tea"}, hashtags: %{de: "#Tee", en: "#Tea"}},
      %{name: %{de: "Bier", en: "Beer"}, hashtags: %{de: "#Bier", en: "#Beer"}},
      %{name: %{de: "Wein", en: "Wine"}, hashtags: %{de: "#Wein", en: "#Wine"}},
      %{name: %{de: "Saft", en: "Juice"}, hashtags: %{de: "#Saft", en: "#Juice"}},
      %{name: %{de: "Limonade", en: "Lemonade"}, hashtags: %{de: "#Limonade", en: "#Lemonade"}},
      %{
        name: %{de: "Smoothies", en: "Smoothies"},
        hashtags: %{de: "#Smoothies", en: "#Smoothies"}
      },
      %{
        name: %{de: "Cocktails", en: "Cocktails"},
        hashtags: %{de: "#Cocktails", en: "#Cocktails"}
      },
      %{name: %{de: "Milch", en: "Milk"}, hashtags: %{de: "#Milch", en: "#Milk"}},
      %{name: %{de: "Espresso", en: "Espresso"}, hashtags: %{de: "#Espresso", en: "#Espresso"}},
      %{
        name: %{de: "Cappuccino", en: "Cappuccino"},
        hashtags: %{de: "#Cappuccino", en: "#Cappuccino"}
      },
      %{
        name: %{de: "Energy Drinks", en: "Energy Drinks"},
        hashtags: %{de: "#EnergyDrinks", en: "#EnergyDrinks"}
      },
      %{
        name: %{de: "Mineralwasser", en: "Mineral Water"},
        hashtags: %{de: "#Mineralwasser", en: "#MineralWater"}
      },
      %{
        name: %{de: "Sekt", en: "Sparkling Wine"},
        hashtags: %{de: "#Sekt", en: "#SparklingWine"}
      }
    ]
  },
  %{
    category_id: "music",
    category_name: %{de: "Musik", en: "Music"},
    items: [
      %{name: %{de: "Pop", en: "Pop"}, hashtags: %{de: "#Pop", en: "#Pop"}},
      %{name: %{de: "Rock", en: "Rock"}, hashtags: %{de: "#Rock", en: "#Rock"}},
      %{name: %{de: "Hip-Hop", en: "Hip-Hop"}, hashtags: %{de: "#HipHop", en: "#HipHop"}},
      %{name: %{de: "Rap", en: "Rap"}, hashtags: %{de: "#Rap", en: "#Rap"}},
      %{name: %{de: "Techno", en: "Techno"}, hashtags: %{de: "#Techno", en: "#Techno"}},
      %{name: %{de: "Schlager", en: "Schlager"}, hashtags: %{de: "#Schlager", en: "#Schlager"}},
      %{name: %{de: "Klassik", en: "Classical"}, hashtags: %{de: "#Klassik", en: "#Classical"}},
      %{name: %{de: "Jazz", en: "Jazz"}, hashtags: %{de: "#Jazz", en: "#Jazz"}},
      %{
        name: %{de: "Heavy Metal", en: "Heavy Metal"},
        hashtags: %{de: "#HeavyMetal", en: "#HeavyMetal"}
      },
      %{name: %{de: "Indie", en: "Indie"}, hashtags: %{de: "#Indie", en: "#Indie"}},
      %{name: %{de: "Folk", en: "Folk"}, hashtags: %{de: "#Folk", en: "#Folk"}},
      %{
        name: %{de: "Volksmusik", en: "Folk Music"},
        hashtags: %{de: "#Volksmusik", en: "#FolkMusic"}
      },
      %{name: %{de: "Blues", en: "Blues"}, hashtags: %{de: "#Blues", en: "#Blues"}},
      %{name: %{de: "Reggae", en: "Reggae"}, hashtags: %{de: "#Reggae", en: "#Reggae"}},
      %{name: %{de: "Soul", en: "Soul"}, hashtags: %{de: "#Soul", en: "#Soul"}},
      %{name: %{de: "Country", en: "Country"}, hashtags: %{de: "#Country", en: "#Country"}},
      %{name: %{de: "R&B", en: "R&B"}, hashtags: %{de: "#RB", en: "#RnB"}},
      %{
        name: %{de: "Elektro", en: "Electronic"},
        hashtags: %{de: "#Elektro", en: "#Electronic"}
      },
      %{name: %{de: "House", en: "House"}, hashtags: %{de: "#House", en: "#House"}},
      %{name: %{de: "Dance", en: "Dance"}, hashtags: %{de: "#Dance", en: "#Dance"}},
      %{name: %{de: "Latin", en: "Latin"}, hashtags: %{de: "#Latin", en: "#Latin"}},
      %{name: %{de: "Punk", en: "Punk"}, hashtags: %{de: "#Punk", en: "#Punk"}},
      %{
        name: %{de: "Alternative", en: "Alternative"},
        hashtags: %{de: "#Alternative", en: "#Alternative"}
      }
    ]
  },
  %{
    category_id: "movies",
    category_name: %{de: "Filme", en: "Movies"},
    items: [
      %{
        name: %{de: "Komödie", en: "Comedy"},
        hashtags: %{de: "#KomödieFilme", en: "#ComedyMovies"}
      },
      %{name: %{de: "Drama", en: "Drama"}, hashtags: %{de: "#DramaFilme", en: "#DramaMovies"}},
      %{
        name: %{de: "Thriller", en: "Thriller"},
        hashtags: %{de: "#ThrillerFilme", en: "#ThrillerMovies"}
      },
      %{
        name: %{de: "Action", en: "Action"},
        hashtags: %{de: "#ActionFilme", en: "#ActionMovies"}
      },
      %{
        name: %{de: "Science-Fiction", en: "Science Fiction"},
        hashtags: %{de: "#ScienceFictionFilme", en: "#ScienceFictionMovies"}
      },
      %{
        name: %{de: "Horror", en: "Horror"},
        hashtags: %{de: "#HorrorFilme", en: "#HorrorMovies"}
      },
      %{
        name: %{de: "Romantik", en: "Romance"},
        hashtags: %{de: "#RomantikFilme", en: "#RomanceMovies"}
      },
      %{
        name: %{de: "Fantasy", en: "Fantasy"},
        hashtags: %{de: "#FantasyFilme", en: "#FantasyMovies"}
      },
      %{name: %{de: "Krimi", en: "Crime"}, hashtags: %{de: "#KrimiFilme", en: "#CrimeMovies"}},
      %{
        name: %{de: "Dokumentarfilme", en: "Documentaries"},
        hashtags: %{de: "#Dokumentarfilme", en: "#DocumentariesMovies"}
      },
      %{
        name: %{de: "Historienfilme", en: "Historical Movies"},
        hashtags: %{de: "#Historienfilme", en: "#HistoricalMoviesMovies"}
      },
      %{
        name: %{de: "Animationsfilme", en: "Animated Movies"},
        hashtags: %{de: "#Animationsfilme", en: "#AnimatedMoviesMovies"}
      },
      %{
        name: %{de: "Abenteuer", en: "Adventure"},
        hashtags: %{de: "#AbenteuerFilme", en: "#AdventureMovies"}
      },
      %{
        name: %{de: "Kinder- und Familienfilme", en: "Children and Family Movies"},
        hashtags: %{de: "#KinderUndFamilienfilme", en: "#ChildrenAndFamilyMoviesMovies"}
      },
      %{
        name: %{de: "Mystery", en: "Mystery"},
        hashtags: %{de: "#MysteryFilme", en: "#MysteryMovies"}
      },
      %{
        name: %{de: "Romcom", en: "Romantic Comedy"},
        hashtags: %{de: "#RomcomFilme", en: "#RomanticComedyMovies"}
      },
      %{
        name: %{de: "Superhelden", en: "Superheroes"},
        hashtags: %{de: "#SuperheldenFilme", en: "#SuperheroesMovies"}
      },
      %{
        name: %{de: "Gameshows", en: "Game Shows"},
        hashtags: %{de: "#GameshowsFilme", en: "#GameShowsMovies"}
      },
      %{
        name: %{de: "Reality TV", en: "Reality TV"},
        hashtags: %{de: "#RealityTVFilme", en: "#RealityTVMovies"}
      },
      %{
        name: %{de: "Kochsendungen", en: "Cooking Shows"},
        hashtags: %{de: "#KochsendungenFilme", en: "#CookingShowsMovies"}
      },
      %{
        name: %{de: "Tatort", en: "Crime Scene"},
        hashtags: %{de: "#TatortFilme", en: "#CrimeSceneMovies"}
      },
      %{
        name: %{de: "Erotik", en: "Erotica"},
        hashtags: %{de: "#ErotikFilme", en: "#EroticaMovies"}
      }
    ]
  },
  %{
    category_id: "literature",
    category_name: %{de: "Literatur", en: "Literature"},
    items: [
      %{name: %{de: "Krimi", en: "Crime"}, hashtags: %{de: "#KrimiLit", en: "#CrimeLit"}},
      %{name: %{de: "Romane", en: "Novels"}, hashtags: %{de: "#RomaneLit", en: "#NovelsLit"}},
      %{
        name: %{de: "Liebesromane", en: "Romance Novels"},
        hashtags: %{de: "#LiebesromaneLit", en: "#RomanceNovelsLit"}
      },
      %{
        name: %{de: "Historische Romane", en: "Historical Novels"},
        hashtags: %{de: "#HistorischeRomaneLit", en: "#HistoricalNovelsLit"}
      },
      %{name: %{de: "Fantasy", en: "Fantasy"}, hashtags: %{de: "#FantasyLit", en: "#FantasyLit"}},
      %{
        name: %{de: "Science-Fiction", en: "Science Fiction"},
        hashtags: %{de: "#ScienceFictionLit", en: "#ScienceFictionLit"}
      },
      %{
        name: %{de: "Sachbücher", en: "Non-Fiction"},
        hashtags: %{de: "#SachbücherLit", en: "#NonFictionLit"}
      },
      %{
        name: %{de: "Biografien", en: "Biographies"},
        hashtags: %{de: "#BiografienLit", en: "#BiographiesLit"}
      },
      %{name: %{de: "Erotik", en: "Erotica"}, hashtags: %{de: "#ErotikLit", en: "#EroticaLit"}},
      %{
        name: %{de: "Kinder- und Jugendliteratur", en: "Children's and Young Adult Literature"},
        hashtags: %{
          de: "#KinderUndJugendliteraturLit",
          en: "#ChildrensAndYoungAdultLiteratureLit"
        }
      },
      %{name: %{de: "Humor", en: "Humor"}, hashtags: %{de: "#HumorLit", en: "#HumorLit"}},
      %{
        name: %{de: "Klassiker", en: "Classics"},
        hashtags: %{de: "#KlassikerLit", en: "#ClassicsLit"}
      },
      %{name: %{de: "Horror", en: "Horror"}, hashtags: %{de: "#HorrorLit", en: "#HorrorLit"}},
      %{
        name: %{de: "Ratgeber", en: "Guidebooks"},
        hashtags: %{de: "#RatgeberLit", en: "#GuidebooksLit"}
      },
      %{name: %{de: "Poesie", en: "Poetry"}, hashtags: %{de: "#PoesieLit", en: "#PoetryLit"}},
      %{
        name: %{de: "Abenteuerliteratur", en: "Adventure Literature"},
        hashtags: %{de: "#AbenteuerliteraturLit", en: "#AdventureLiteratureLit"}
      },
      %{
        name: %{de: "Philosophie", en: "Philosophy"},
        hashtags: %{de: "#PhilosophieLit", en: "#PhilosophyLit"}
      },
      %{
        name: %{de: "Thriller", en: "Thriller"},
        hashtags: %{de: "#ThrillerLit", en: "#ThrillerLit"}
      },
      %{
        name: %{de: "Psychologie", en: "Psychology"},
        hashtags: %{de: "#PsychologieLit", en: "#PsychologyLit"}
      },
      %{
        name: %{de: "Wissenschaft", en: "Science"},
        hashtags: %{de: "#WissenschaftLit", en: "#ScienceLit"}
      }
    ]
  },
  %{
    category_id: "at_home",
    category_name: %{de: "Zu Hause", en: "At Home"},
    items: [
      %{name: %{de: "Kochen", en: "Cooking"}, hashtags: %{de: "#Kochen", en: "#Cooking"}},
      %{name: %{de: "Backen", en: "Baking"}, hashtags: %{de: "#Backen", en: "#Baking"}},
      %{name: %{de: "Lesen", en: "Reading"}, hashtags: %{de: "#Lesen", en: "#Reading"}},
      %{name: %{de: "Filme", en: "Movies"}, hashtags: %{de: "#Filme", en: "#Movies"}},
      %{name: %{de: "Serien", en: "Series"}, hashtags: %{de: "#Serien", en: "#Series"}},
      %{
        name: %{de: "Online-Kurse", en: "Online Courses"},
        hashtags: %{de: "#OnlineKurse", en: "#OnlineCourses"}
      },
      %{
        name: %{de: "Fitnessübungen", en: "Fitness Exercises"},
        hashtags: %{de: "#Fitnessübungen", en: "#FitnessExercises"}
      },
      %{
        name: %{de: "Gartenarbeit", en: "Gardening"},
        hashtags: %{de: "#Gartenarbeit", en: "#Gardening"}
      },
      %{
        name: %{de: "Handarbeiten", en: "Handicrafts"},
        hashtags: %{de: "#Handarbeiten", en: "#Handicrafts"}
      },
      %{name: %{de: "Zeichnen", en: "Drawing"}, hashtags: %{de: "#Zeichnen", en: "#Drawing"}},
      %{name: %{de: "Musik", en: "Music"}, hashtags: %{de: "#Musik", en: "#Music"}},
      %{name: %{de: "Puzzles", en: "Puzzles"}, hashtags: %{de: "#Puzzles", en: "#Puzzles"}},
      %{
        name: %{de: "Brettspiele", en: "Board Games"},
        hashtags: %{de: "#Brettspiele", en: "#BoardGames"}
      },
      %{
        name: %{de: "Meditation", en: "Meditation"},
        hashtags: %{de: "#Meditation", en: "#Meditation"}
      },
      %{
        name: %{de: "DIY-Projekte", en: "DIY Projects"},
        hashtags: %{de: "#DIYProjekte", en: "#DIYProjects"}
      },
      %{
        name: %{de: "Tagebuch schreiben", en: "Journaling"},
        hashtags: %{de: "#TagebuchSchreiben", en: "#Journaling"}
      },
      %{name: %{de: "Podcasts", en: "Podcasts"}, hashtags: %{de: "#Podcasts", en: "#Podcasts"}},
      %{
        name: %{de: "Hörbücher", en: "Audiobooks"},
        hashtags: %{de: "#Hörbücher", en: "#Audiobooks"}
      },
      %{
        name: %{de: "Videospiele", en: "Video Games"},
        hashtags: %{de: "#Videospiele", en: "#VideoGames"}
      }
    ]
  },
  %{
    category_id: "creativity",
    category_name: %{de: "Kreativität", en: "Creativity"},
    items: [
      %{
        name: %{de: "Fotografie", en: "Photography"},
        hashtags: %{de: "#Fotografie", en: "#Photography"}
      },
      %{name: %{de: "Design", en: "Design"}, hashtags: %{de: "#Design", en: "#Design"}},
      %{
        name: %{de: "Handarbeit", en: "Crafting"},
        hashtags: %{de: "#Handarbeit", en: "#Crafting"}
      },
      %{name: %{de: "Kunst", en: "Art"}, hashtags: %{de: "#Kunst", en: "#Art"}},
      %{name: %{de: "Make-up", en: "Make-up"}, hashtags: %{de: "#MakeUp", en: "#MakeUp"}},
      %{name: %{de: "Schreiben", en: "Writing"}, hashtags: %{de: "#Schreiben", en: "#Writing"}},
      %{name: %{de: "Singen", en: "Singing"}, hashtags: %{de: "#Singen", en: "#Singing"}},
      %{name: %{de: "Tanzen", en: "Dancing"}, hashtags: %{de: "#Tanzen", en: "#Dancing"}},
      %{
        name: %{de: "Videos drehen", en: "Video Production"},
        hashtags: %{de: "#VideosDrehen", en: "#VideoProduction"}
      },
      %{
        name: %{de: "Social Media", en: "Social Media"},
        hashtags: %{de: "#SocialMedia", en: "#SocialMedia"}
      },
      %{
        name: %{de: "Musik machen", en: "Making Music"},
        hashtags: %{de: "#MusikMachen", en: "#MakingMusic"}
      },
      %{
        name: %{de: "Schauspielen", en: "Acting"},
        hashtags: %{de: "#Schauspielen", en: "#Acting"}
      },
      %{name: %{de: "Malen", en: "Painting"}, hashtags: %{de: "#Malen", en: "#Painting"}},
      %{name: %{de: "Häkeln", en: "Crocheting"}, hashtags: %{de: "#Häkeln", en: "#Crocheting"}},
      %{name: %{de: "Stricken", en: "Knitting"}, hashtags: %{de: "#Stricken", en: "#Knitting"}},
      %{name: %{de: "Nähen", en: "Sewing"}, hashtags: %{de: "#Nähen", en: "#Sewing"}}
    ]
  },
  %{
    category_id: "going_out",
    category_name: %{de: "Ausgehen", en: "Going Out"},
    items: [
      %{name: %{de: "Bars", en: "Bars"}, hashtags: %{de: "#Bars", en: "#Bars"}},
      %{name: %{de: "Cafés", en: "Cafes"}, hashtags: %{de: "#Cafés", en: "#Cafes"}},
      %{name: %{de: "Clubbing", en: "Clubbing"}, hashtags: %{de: "#Clubbing", en: "#Clubbing"}},
      %{
        name: %{de: "Drag-Shows", en: "Drag Shows"},
        hashtags: %{de: "#DragShows", en: "#DragShows"}
      },
      %{
        name: %{de: "Festivals", en: "Festivals"},
        hashtags: %{de: "#Festivals", en: "#Festivals"}
      },
      %{name: %{de: "Karaoke", en: "Karaoke"}, hashtags: %{de: "#Karaoke", en: "#Karaoke"}},
      %{name: %{de: "Konzerte", en: "Concerts"}, hashtags: %{de: "#Konzerte", en: "#Concerts"}},
      %{
        name: %{de: "LGBTQ+-Nightlife", en: "LGBTQ+ Nightlife"},
        hashtags: %{de: "#LGBTQPlusNightlife", en: "#LGBTQPlusNightlife"}
      },
      %{
        name: %{de: "Museen & Galerien", en: "Museums & Galleries"},
        hashtags: %{de: "#MuseenUndGalerien", en: "#MuseumsAndGalleries"}
      },
      %{
        name: %{de: "Stand-Up Comedy", en: "Stand-Up Comedy"},
        hashtags: %{de: "#StandUpComedy", en: "#StandUpComedy"}
      },
      %{name: %{de: "Theater", en: "Theater"}, hashtags: %{de: "#Theater", en: "#Theater"}}
    ]
  },
  %{
    category_id: "self_care",
    category_name: %{de: "Selbstfürsorge", en: "Self Care"},
    items: [
      %{
        name: %{de: "Guter Schlaf", en: "Good Sleep"},
        hashtags: %{de: "#GuterSchlaf", en: "#GoodSleep"}
      },
      %{
        name: %{de: "Tiefe Gespräche", en: "Deep Conversations"},
        hashtags: %{de: "#TiefeGespräche", en: "#DeepConversations"}
      },
      %{
        name: %{de: "Achtsamkeit", en: "Mindfulness"},
        hashtags: %{de: "#Achtsamkeit", en: "#Mindfulness"}
      },
      %{
        name: %{de: "Counseling", en: "Counseling"},
        hashtags: %{de: "#Counseling", en: "#Counseling"}
      },
      %{
        name: %{de: "Ernährung", en: "Nutrition"},
        hashtags: %{de: "#Ernährung", en: "#Nutrition"}
      },
      %{
        name: %{de: "Offline gehen", en: "Going Offline"},
        hashtags: %{de: "#OfflineGehen", en: "#GoingOffline"}
      },
      %{
        name: %{de: "Sex Positivity", en: "Sex Positivity"},
        hashtags: %{de: "#SexPositivity", en: "#SexPositivity"}
      }
    ]
  },
  %{
    category_id: "political_parties",
    category_name: %{de: "Parteien", en: "Parties"},
    items: [
      %{
        name: %{
          de: "Christlich Demokratische Union Deutschlands",
          en: "Christian Democratic Union of Germany"
        },
        hashtags: %{de: "#CDU", en: "#CDU"}
      },
      %{
        name: %{
          de: "Sozialdemokratische Partei Deutschlands",
          en: "Social Democratic Party of Germany"
        },
        hashtags: %{de: "#SPD", en: "#SPD"}
      },
      %{
        name: %{de: "Bündnis 90/Die Grünen", en: "Alliance 90/The Greens"},
        hashtags: %{de: "#Grüne", en: "#Greens"}
      },
      %{
        name: %{de: "Freie Demokratische Partei", en: "Free Democratic Party"},
        hashtags: %{de: "#FDP", en: "#FDP"}
      },
      %{
        name: %{de: "Alternative für Deutschland", en: "Alternative for Germany"},
        hashtags: %{de: "#AfD", en: "#AfD"}
      },
      %{name: %{de: "Die Linke", en: "The Left"}, hashtags: %{de: "#DieLinke", en: "#TheLeft"}},
      %{
        name: %{
          de: "Christlich-Soziale Union in Bayern",
          en: "Christian Social Union in Bavaria"
        },
        hashtags: %{de: "#CSU", en: "#CSU"}
      },
      %{
        name: %{de: "Freie Wähler", en: "Free Voters"},
        hashtags: %{de: "#FreieWähler", en: "#FreeVoters"}
      },
      %{
        name: %{
          de:
            "Partei für Arbeit, Rechtsstaat, Tierschutz, Elitenförderung und basisdemokratische Initiative",
          en:
            "Party for Labour, Rule of Law, Animal Protection, Promotion of Elites and Grassroots Democratic Initiative"
        },
        hashtags: %{de: "#DiePARTEI", en: "#TheParty"}
      },
      %{
        name: %{de: "Piratenpartei Deutschland", en: "Pirate Party Germany"},
        hashtags: %{de: "#Piratenpartei", en: "#PirateParty"}
      }
    ]
  },
  %{
    category_id: "religion",
    category_name: %{de: "Religion", en: "Religion"},
    items: [
      # Traditionelle Religionen
      %{
        name: %{de: "Römisch-Katholische Kirche", en: "Roman Catholic Church"},
        hashtags: %{de: "#Katholisch", en: "#Catholic"}
      },
      %{
        name: %{de: "Evangelische Kirche", en: "Protestant Church"},
        hashtags: %{de: "#Evangelisch", en: "#Protestant"}
      },
      %{
        name: %{de: "Orthodoxes Christentum", en: "Orthodox Christianity"},
        hashtags: %{de: "#Orthodox", en: "#Orthodox"}
      },
      %{name: %{de: "Islam", en: "Islam"}, hashtags: %{de: "#Islam", en: "#Islam"}},
      %{name: %{de: "Judentum", en: "Judaism"}, hashtags: %{de: "#Judentum", en: "#Judaism"}},
      %{
        name: %{de: "Buddhismus", en: "Buddhism"},
        hashtags: %{de: "#Buddhismus", en: "#Buddhism"}
      },
      %{
        name: %{de: "Hinduismus", en: "Hinduism"},
        hashtags: %{de: "#Hinduismus", en: "#Hinduism"}
      },
      # Nicht-religiöse Überzeugungen
      %{name: %{de: "Atheismus", en: "Atheism"}, hashtags: %{de: "#Atheismus", en: "#Atheism"}},
      %{
        name: %{de: "Agnostizismus", en: "Agnosticism"},
        hashtags: %{de: "#Agnostizismus", en: "#Agnosticism"}
      },
      %{
        name: %{de: "Humanismus", en: "Humanism"},
        hashtags: %{de: "#Humanismus", en: "#Humanism"}
      },
      %{
        name: %{de: "Säkularismus", en: "Secularism"},
        hashtags: %{de: "#Säkularismus", en: "#Secularism"}
      },
      %{
        name: %{de: "Freidenker", en: "Freethought"},
        hashtags: %{de: "#Freidenker", en: "#Freethought"}
      },
      %{
        name: %{de: "Spiritualität", en: "Spirituality"},
        hashtags: %{de: "#Spiritualität", en: "#Spirituality"}
      }
    ]
  }
]
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
          %{name: %{de: name_de, en: name_en}, hashtags: %{de: hashtags_de, en: hashtags_en}} ->
            flag = Animina.Traits.Flag.create!(%{category_id: category.id, name: name_en})

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
