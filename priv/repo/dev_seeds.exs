# Development seed data for testing
# This file is only loaded in dev environment via seeds.exs

defmodule Animina.Seeds.DevUsers do
  @moduledoc """
  Seeds 50 development test accounts with full profiles, traits, and moodboards.
  All accounts use the password "password" and are located in Koblenz (56068).
  """

  import Ecto.Query

  alias Animina.Accounts
  alias Animina.GeoData
  alias Animina.Moodboard
  alias Animina.Photos
  alias Animina.Repo
  alias Animina.Traits

  @password "password12345"
  @zip_code "56068"

  @male_users [
    %{first_name: "Thomas", last_name: "Müller", email: "dev-thomas@animina.test", age: 32, roles: [:admin]},
    %{first_name: "Michael", last_name: "Schmidt", email: "dev-michael@animina.test", age: 28, roles: [:moderator]},
    %{first_name: "Andreas", last_name: "Schneider", email: "dev-andreas@animina.test", age: 35, roles: [:admin, :moderator]},
    %{first_name: "Stefan", last_name: "Fischer", email: "dev-stefan@animina.test", age: 41, roles: []},
    %{first_name: "Christian", last_name: "Weber", email: "dev-christian@animina.test", age: 29, roles: []},
    %{first_name: "Markus", last_name: "Meyer", email: "dev-markus@animina.test", age: 38, roles: [:admin]},
    %{first_name: "Daniel", last_name: "Wagner", email: "dev-daniel@animina.test", age: 26, roles: []},
    %{first_name: "Martin", last_name: "Becker", email: "dev-martin@animina.test", age: 44, roles: []},
    %{first_name: "Sebastian", last_name: "Hoffmann", email: "dev-sebastian@animina.test", age: 31, roles: []},
    %{first_name: "Jan", last_name: "Schäfer", email: "dev-jan@animina.test", age: 27, roles: []},
    %{first_name: "Tobias", last_name: "Koch", email: "dev-tobias@animina.test", age: 33, roles: []},
    %{first_name: "Patrick", last_name: "Bauer", email: "dev-patrick@animina.test", age: 30, roles: []},
    %{first_name: "Felix", last_name: "Richter", email: "dev-felix@animina.test", age: 25, roles: []},
    %{first_name: "Florian", last_name: "Klein", email: "dev-florian@animina.test", age: 37, roles: []},
    %{first_name: "Matthias", last_name: "Wolf", email: "dev-matthias@animina.test", age: 42, roles: []},
    %{first_name: "Alexander", last_name: "Schröder", email: "dev-alexander@animina.test", age: 29, roles: []},
    %{first_name: "Philipp", last_name: "Neumann", email: "dev-philipp@animina.test", age: 34, roles: []},
    %{first_name: "Dominik", last_name: "Schwarz", email: "dev-dominik@animina.test", age: 27, roles: []},
    %{first_name: "Marcel", last_name: "Zimmermann", email: "dev-marcel@animina.test", age: 40, roles: []},
    %{first_name: "Tim", last_name: "Braun", email: "dev-tim@animina.test", age: 26, roles: []},
    %{first_name: "Lukas", last_name: "Krüger", email: "dev-lukas@animina.test", age: 31, roles: []},
    %{first_name: "Maximilian", last_name: "Hartmann", email: "dev-maximilian@animina.test", age: 36, roles: []},
    %{first_name: "Jens", last_name: "Lange", email: "dev-jens@animina.test", age: 43, roles: []},
    %{first_name: "Dennis", last_name: "Werner", email: "dev-dennis@animina.test", age: 28, roles: []},
    %{first_name: "Nico", last_name: "Lehmann", email: "dev-nico@animina.test", age: 25, roles: []},
    %{first_name: "Oliver", last_name: "Schmitt", email: "dev-oliver@animina.test", age: 34, roles: []},
    %{first_name: "Robert", last_name: "Schulz", email: "dev-robert@animina.test", age: 39, roles: []},
    %{first_name: "Konstantin", last_name: "Maier", email: "dev-konstantin@animina.test", age: 30, roles: []},
    %{first_name: "Benjamin", last_name: "Köhler", email: "dev-benjamin@animina.test", age: 27, roles: []},
    %{first_name: "Moritz", last_name: "Herrmann", email: "dev-moritz@animina.test", age: 33, roles: []}
  ]

  @female_users [
    %{first_name: "Julia", last_name: "Müller", email: "dev-julia@animina.test", age: 30, roles: [:admin]},
    %{first_name: "Anna", last_name: "Schmidt", email: "dev-anna@animina.test", age: 25, roles: [:moderator]},
    %{first_name: "Sarah", last_name: "Schneider", email: "dev-sarah@animina.test", age: 33, roles: [:admin, :moderator]},
    %{first_name: "Laura", last_name: "Fischer", email: "dev-laura@animina.test", age: 28, roles: [:moderator]},
    %{first_name: "Lisa", last_name: "Weber", email: "dev-lisa@animina.test", age: 36, roles: []},
    %{first_name: "Maria", last_name: "Meyer", email: "dev-maria@animina.test", age: 42, roles: []},
    %{first_name: "Katharina", last_name: "Wagner", email: "dev-katharina@animina.test", age: 29, roles: []},
    %{first_name: "Sandra", last_name: "Becker", email: "dev-sandra@animina.test", age: 34, roles: []},
    %{first_name: "Stefanie", last_name: "Hoffmann", email: "dev-stefanie@animina.test", age: 27, roles: []},
    %{first_name: "Christina", last_name: "Schäfer", email: "dev-christina@animina.test", age: 39, roles: []},
    %{first_name: "Nicole", last_name: "Koch", email: "dev-nicole@animina.test", age: 31, roles: []},
    %{first_name: "Melanie", last_name: "Bauer", email: "dev-melanie@animina.test", age: 26, roles: []},
    %{first_name: "Sabrina", last_name: "Richter", email: "dev-sabrina@animina.test", age: 35, roles: []},
    %{first_name: "Jennifer", last_name: "Klein", email: "dev-jennifer@animina.test", age: 29, roles: []},
    %{first_name: "Nadine", last_name: "Wolf", email: "dev-nadine@animina.test", age: 32, roles: []},
    %{first_name: "Vanessa", last_name: "Schröder", email: "dev-vanessa@animina.test", age: 27, roles: []},
    %{first_name: "Daniela", last_name: "Neumann", email: "dev-daniela@animina.test", age: 41, roles: []},
    %{first_name: "Claudia", last_name: "Schwarz", email: "dev-claudia@animina.test", age: 38, roles: []},
    %{first_name: "Tanja", last_name: "Zimmermann", email: "dev-tanja@animina.test", age: 30, roles: []},
    %{first_name: "Susanne", last_name: "Braun", email: "dev-susanne@animina.test", age: 44, roles: []},
    %{first_name: "Martina", last_name: "Krüger", email: "dev-martina@animina.test", age: 37, roles: []},
    %{first_name: "Kerstin", last_name: "Hartmann", email: "dev-kerstin@animina.test", age: 33, roles: []},
    %{first_name: "Bianca", last_name: "Lange", email: "dev-bianca@animina.test", age: 26, roles: []},
    %{first_name: "Simone", last_name: "Werner", email: "dev-simone@animina.test", age: 40, roles: []},
    %{first_name: "Petra", last_name: "Lehmann", email: "dev-petra@animina.test", age: 45, roles: []},
    %{first_name: "Elena", last_name: "Schmitt", email: "dev-elena@animina.test", age: 31, roles: []},
    %{first_name: "Charlotte", last_name: "Schulz", email: "dev-charlotte@animina.test", age: 28, roles: []},
    %{first_name: "Franziska", last_name: "Maier", email: "dev-franziska@animina.test", age: 35, roles: []},
    %{first_name: "Marie", last_name: "Köhler", email: "dev-marie@animina.test", age: 29, roles: []},
    %{first_name: "Lena", last_name: "Herrmann", email: "dev-lena@animina.test", age: 32, roles: []}
  ]

  @german_story_contents [
    # Hobbies & Interests
    "Ich liebe es, am Wochenende in der Natur zu wandern und neue Orte zu entdecken. Wer kommt mit?",
    "Kaffee und ein gutes Buch - das ist mein perfekter Sonntagmorgen. Bonuspunkte, wenn du mir neue Bücher empfehlen kannst!",
    "Musik ist meine Leidenschaft. Ich spiele seit meiner Kindheit Gitarre und suche jemanden zum Duett.",
    "Kochen ist für mich Entspannung. Ich probiere gerne neue Rezepte aus - am liebsten zu zweit.",
    "Sport gehört zu meinem Alltag - ob Joggen, Yoga oder Schwimmen. Ein Trainingspartner wäre toll!",
    "Reisen erweitert den Horizont. Mein Traum ist eine Weltreise. Wohin würdest du zuerst fliegen?",
    "Ich bin ein Familienmensch und verbringe gerne Zeit mit meinen Liebsten. Familie ist mir sehr wichtig.",
    "Fotografie ist mein kreatives Ventil. Ich liebe es, Momente festzuhalten und Erinnerungen zu schaffen.",
    "Ein gutes Gespräch bei einem Glas Wein - das schätze ich sehr. Die besten Abende enden spät.",
    "Ich bin neugierig und lerne ständig Neues - aktuell eine neue Sprache. Welche sprichst du?",
    "Die kleinen Dinge im Leben machen mich glücklich - ein Sonnenuntergang, ein Lächeln, eine warme Umarmung.",
    "Humor ist wichtig. Wer über sich selbst lachen kann, hat schon gewonnen. Ich lache gerne und viel!",
    "Ich bin spontan und offen für Abenteuer - ob nah oder fern. Manchmal die besten Ideen um Mitternacht.",
    "Gartenarbeit entspannt mich. Es gibt nichts Schöneres als selbst angebautes Gemüse und frische Kräuter.",

    # Dating-specific
    "Ich glaube an Ehrlichkeit und offene Kommunikation in Beziehungen. Ohne Vertrauen geht nichts.",
    "Ich suche jemanden, mit dem ich lachen, weinen und alles dazwischen teilen kann.",
    "Für mich zählt Charakter mehr als Aussehen. Schönheit vergeht, aber ein gutes Herz bleibt.",
    "Ich bin hier, weil ich glaube, dass die große Liebe nicht einfach an der Tür klopft. Man muss sie suchen.",
    "Treue und Loyalität sind für mich keine verhandelbaren Werte. Ich gebe 100% und erwarte dasselbe.",
    "Ich suche keine Perfektion, sondern jemanden, dessen Macken zu meinen passen.",
    "Gemeinsame Werte sind mir wichtiger als gemeinsame Hobbies. Den Rest kann man lernen.",
    "Ich möchte jemanden finden, mit dem aus Dates irgendwann Alltag wird - im besten Sinne.",

    # Lifestyle
    "Morgens Yoga, abends Netflix - ich mag die Balance zwischen aktiv und gemütlich.",
    "Ich koche lieber selbst als Essen zu bestellen. Kommst du zum Probieren vorbei?",
    "Wochenenden am liebsten mit Brunch, Spaziergang und einem guten Film. Simpel, aber schön.",
    "Ich bin eher der Typ für tiefe Gespräche als für Small Talk. Erzähl mir von deinen Träumen!",
    "Meine Freunde sagen, ich bin ein guter Zuhörer. Ich finde, das ist unterschätzt.",
    "Ich genieße die Ruhe genauso wie das Abenteuer. Mit der richtigen Person ist beides perfekt.",
    "Home Office hat mich zum Hobbykoch gemacht. Mein Risotto ist legendär - sagen zumindest meine Freunde.",
    "Ich liebe es, neue Restaurants zu entdecken. Hast du einen Geheimtipp für mich?",

    # What I'm looking for
    "Ich suche jemanden zum Reden, Lachen, Schweigen und Händchenhalten. Klingt das gut?",
    "Mir ist wichtig, dass wir auch ohne Worte verstehen, was der andere braucht.",
    "Ich wünsche mir eine Beziehung, in der wir uns gegenseitig wachsen lassen.",
    "Gemeinsame Ziele und Träume - das ist für mich die Basis einer starken Partnerschaft.",
    "Ich suche keinen perfekten Menschen, sondern jemanden, der perfekt zu mir passt."
  ]

  @german_intro_stories [
    "Hey! Ich bin auf der Suche nach jemandem, der mit mir die Welt entdecken möchte. Ob spontane Roadtrips oder gemütliche Abende zu Hause - mit der richtigen Person macht alles doppelt so viel Spaß.",
    "Lebensfroh, neugierig und immer für ein Abenteuer zu haben. Ich suche jemanden, der das Leben genauso genießt wie ich und offen für Neues ist.",
    "Bei mir gibt es keine halben Sachen - ob beim Kochen, Reisen oder in der Liebe. Wenn du jemanden suchst, der mit Herz und Seele dabei ist, sind wir vielleicht ein gutes Match.",
    "Ich glaube daran, dass die besten Geschichten noch geschrieben werden. Lass uns gemeinsam ein neues Kapitel beginnen!",
    "Tagsüber im Büro, abends auf dem Fahrrad oder in der Küche. Ich liebe es, aktiv zu sein, schätze aber auch ruhige Momente. Balance ist alles.",
    "Authentisch, humorvoll und manchmal ein bisschen verrückt. Wenn du über schlechte Witze lachen kannst und gerne tiefgründige Gespräche führst, könnten wir uns gut verstehen.",
    "Ich bin hier, weil ich glaube, dass es da draußen jemanden gibt, mit dem alles einfach passt. Jemand, mit dem man sowohl schweigen als auch lachen kann.",
    "Sport, Natur und gutes Essen - das sind meine drei Säulen. Wenn du Lust hast, diese mit mir zu teilen, freue ich mich auf deine Nachricht.",
    "Nicht perfekt, aber echt. Ich suche keine Märchenprinzessin, sondern eine echte Verbindung mit einem echten Menschen.",
    "Das Leben ist zu kurz für Langeweile. Ich suche jemanden, der genauso leidenschaftlich durchs Leben geht wie ich.",
    "Kreativ, spontan und immer auf der Suche nach dem nächsten Abenteuer. Wenn du auch gerne aus der Komfortzone ausbrichst, lass uns reden!",
    "Ich bin ein Mensch, der viel lacht und das Leben nicht zu ernst nimmt. Aber wenn es darauf ankommt, bin ich zu 100% da.",
    "Gute Gespräche, gemeinsames Kochen und lange Spaziergänge - das sind die Dinge, die für mich zählen. Und du?",
    "Auf der Suche nach meinem Partner in Crime für alle Lebenslagen - vom Sonntagsbrunch bis zum spontanen Wochenendtrip.",
    "Ich glaube an Ehrlichkeit, Respekt und daran, dass man sich gegenseitig zum Lachen bringen sollte. Der Rest ergibt sich."
  ]

  @german_long_stories [
    """
    **Was ich suche**

    Jemanden, der mit mir durch dick und dünn geht. Der meine Macken akzeptiert und seine eigenen mitbringt. Der mit mir lacht, bis uns die Tränen kommen, und der mich tröstet, wenn ich einen schlechten Tag habe.

    Ich glaube nicht an den perfekten Partner - aber an den Partner, der perfekt zu mir passt.
    """,
    """
    **Mein perfektes erstes Date**

    Kein fancy Restaurant, sondern ein Spaziergang am Fluss. Vielleicht ein Kaffee to go in der Hand. Zeit zum Reden, zum Lachen, zum Kennenlernen.

    Wenn die Chemie stimmt, merkt man das nicht beim Candlelight-Dinner, sondern wenn man einfach zusammen ist.
    """,
    """
    **Warum ich hier bin**

    Ehrlich gesagt? Weil ich es leid bin, im Alltag niemanden kennenzulernen. Mein Freundeskreis ist vergeben, meine Kollegen sind... naja, Kollegen.

    Ich glaube daran, dass man sein Glück selbst in die Hand nehmen muss. Also hier bin ich. Schreib mir!
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

    Ich bin nervös, wenn ich neue Leute kennenlerne. Ich rede dann entweder zu viel oder zu wenig. Falls wir uns treffen und ich seltsam bin - gib mir eine zweite Chance.

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

  @lifestyle_photos [
    "coffee-01.jpg",
    "coffee-02.jpg",
    "hiking-01.jpg",
    "hiking-02.jpg",
    "books-01.jpg",
    "books-02.jpg",
    "cooking-01.jpg",
    "cooking-02.jpg",
    "travel-01.jpg",
    "travel-02.jpg",
    "yoga-01.jpg",
    "yoga-02.jpg",
    "cycling-01.jpg",
    "cycling-02.jpg",
    "nature-01.jpg",
    "nature-02.jpg",
    "beach-01.jpg",
    "beach-02.jpg",
    "music-01.jpg",
    "music-02.jpg",
    "garden-01.jpg",
    "garden-02.jpg",
    "art-01.jpg",
    "art-02.jpg",
    "pets-01.jpg",
    "pets-02.jpg",
    "sunset-01.jpg",
    "mountains-01.jpg",
    "food-01.jpg"
  ]

  # Avatar photos - gender-specific from priv/static/images/seeds/avatars/{male,female}/
  # 25 unique male avatars (one per male user)
  @male_avatar_photos [
    "male/avatar-01.jpg",
    "male/avatar-02.jpg",
    "male/avatar-03.jpg",
    "male/avatar-04.jpg",
    "male/avatar-05.jpg",
    "male/avatar-06.jpg",
    "male/avatar-07.jpg",
    "male/avatar-08.jpg",
    "male/avatar-09.jpg",
    "male/avatar-10.jpg",
    "male/avatar-11.jpg",
    "male/avatar-12.jpg",
    "male/avatar-13.jpg",
    "male/avatar-14.jpg",
    "male/avatar-15.jpg",
    "male/avatar-16.jpg",
    "male/avatar-17.jpg",
    "male/avatar-18.jpg",
    "male/avatar-19.jpg",
    "male/avatar-20.jpg",
    "male/avatar-21.jpg",
    "male/avatar-22.jpg",
    "male/avatar-23.jpg",
    "male/avatar-24.jpg",
    "male/avatar-25.jpg"
  ]

  # 25 unique female avatars (one per female user)
  @female_avatar_photos [
    "female/avatar-01.jpg",
    "female/avatar-02.jpg",
    "female/avatar-03.jpg",
    "female/avatar-04.jpg",
    "female/avatar-05.jpg",
    "female/avatar-06.jpg",
    "female/avatar-07.jpg",
    "female/avatar-08.jpg",
    "female/avatar-09.jpg",
    "female/avatar-10.jpg",
    "female/avatar-11.jpg",
    "female/avatar-12.jpg",
    "female/avatar-13.jpg",
    "female/avatar-14.jpg",
    "female/avatar-15.jpg",
    "female/avatar-16.jpg",
    "female/avatar-17.jpg",
    "female/avatar-18.jpg",
    "female/avatar-19.jpg",
    "female/avatar-20.jpg",
    "female/avatar-21.jpg",
    "female/avatar-22.jpg",
    "female/avatar-23.jpg",
    "female/avatar-24.jpg",
    "female/avatar-25.jpg"
  ]

  # 10 personality profiles designed as 5 complementary pairs.
  # Males cycle 0..9, females cycle 1..9,0 (offset by 1) so complementary
  # profiles land on opposite genders for high discovery scores.
  @trait_profiles [
    # Profile 0: Adventurer — loves outdoor action, travel, rock music
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship"],
        "Character" => ["Love of Adventure", "Courage", "Active", "Self-Confidence", "Humor"],
        "Sports" => ["Hiking", "Climbing", "Surfing", "Cycling"],
        "Travels" => ["Hiking Vacation", "Active and Sports Vacation", "Camping"],
        "Favorite Destinations" => ["Norway", "Australia", "Canada"],
        "Music" => ["Rock", "Indie", "Alternative"],
        "At Home" => ["Fitness Exercises", "Podcasts", "Cooking"],
        "Going Out" => ["Festivals", "Concerts"],
        "Food" => ["BBQ", "Street Food", "Mexican"],
        "Creativity" => ["Photography", "Video Production"]
      },
      green: %{
        "Character" => ["Love of Adventure", "Active", "Humor"],
        "What I'm Looking For" => ["Long-term Relationship", "Shared Activities"],
        "Sports" => ["Hiking", "Climbing"]
      },
      red: %{
        "Diet" => ["Vegan"]
      }
    },
    # Profile 1: Nature Soul — calm outdoors lover, wellness, folk music
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship"],
        "Character" => ["Empathy", "Caring", "Modesty", "Active", "Love of Adventure"],
        "Sports" => ["Hiking", "Yoga", "Swimming", "Jogging"],
        "Travels" => ["Hiking Vacation", "Wellness", "Beach"],
        "Favorite Destinations" => ["Austria", "Switzerland", "Norway"],
        "Music" => ["Folk", "Indie", "Classical"],
        "At Home" => ["Gardening", "Reading", "Meditation", "Cooking"],
        "Going Out" => ["Cafes", "Museums & Galleries"],
        "Food" => ["Healthy Food", "Mediterranean", "Italian"],
        "Self Care" => ["Mindfulness", "Good Sleep", "Nutrition"],
        "Pets" => ["Dog", "Cat"]
      },
      green: %{
        "Character" => ["Love of Adventure", "Active", "Empathy", "Caring"],
        "What I'm Looking For" => ["Long-term Relationship"],
        "Sports" => ["Hiking", "Yoga"]
      },
      red: %{
        "Substance Use" => ["Hard Drugs"]
      }
    },
    # Profile 2: Creative — artistic, music-loving, design-focused
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship", "Dates"],
        "Character" => ["Creativity", "Intelligence", "Empathy", "Optimism", "Being Romantic"],
        "Sports" => ["Yoga", "Pilates", "Swimming"],
        "Travels" => ["City Trips", "Cultural Trips"],
        "Favorite Destinations" => ["Italy", "France", "Spain"],
        "Music" => ["Jazz", "Soul", "Classical", "Indie"],
        "At Home" => ["Drawing", "Music", "Reading", "Movies"],
        "Going Out" => ["Museums & Galleries", "Theater", "Concerts"],
        "Food" => ["French", "Italian", "Japanese"],
        "Creativity" => ["Painting", "Photography", "Design", "Making Music"],
        "Literature" => ["Novels", "Poetry", "Philosophy"]
      },
      green: %{
        "Character" => ["Intelligence", "Creativity", "Empathy"],
        "What I'm Looking For" => ["Long-term Relationship"],
        "Sports" => ["Yoga"]
      },
      red: %{}
    },
    # Profile 3: Intellectual — reader, thinker, deep conversations
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship", "Friendship"],
        "Character" => ["Intelligence", "Honesty", "Empathy", "Creativity", "Sense of Justice"],
        "Sports" => ["Swimming", "Jogging", "Cycling"],
        "Travels" => ["Cultural Trips", "City Trips"],
        "Favorite Destinations" => ["United Kingdom", "France", "Germany"],
        "Music" => ["Classical", "Jazz", "Blues", "Folk"],
        "At Home" => ["Reading", "Online Courses", "Podcasts", "Board Games"],
        "Going Out" => ["Museums & Galleries", "Theater", "Stand-Up Comedy"],
        "Food" => ["Indian", "Japanese", "Mediterranean"],
        "Creativity" => ["Writing", "Photography"],
        "Literature" => ["Science", "Philosophy", "Non-Fiction", "Biographies"],
        "Self Care" => ["Deep Conversations", "Mindfulness"]
      },
      green: %{
        "Character" => ["Intelligence", "Empathy", "Creativity", "Honesty"],
        "What I'm Looking For" => ["Long-term Relationship"]
      },
      red: %{}
    },
    # Profile 4: Family Person — caring, home-loving, traditional values
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship", "Marriage"],
        "Character" => ["Family-Oriented", "Honesty", "Caring", "Sense of Responsibility", "Generosity"],
        "Want Children" => ["I Want (More) Children"],
        "Sports" => ["Swimming", "Cycling", "Jogging"],
        "Travels" => ["Beach", "Camping", "Wellness"],
        "Favorite Destinations" => ["Spain", "Italy", "Croatia"],
        "Music" => ["Pop", "Schlager", "Folk Music"],
        "At Home" => ["Cooking", "Baking", "Gardening", "Board Games", "Movies"],
        "Going Out" => ["Cafes", "Theater"],
        "Food" => ["German", "Italian", "BBQ", "Pastries"],
        "Pets" => ["Dog"]
      },
      green: %{
        "Character" => ["Family-Oriented", "Honesty", "Caring"],
        "What I'm Looking For" => ["Long-term Relationship", "Marriage"]
      },
      red: %{
        "Want Children" => ["I Don't Want (More) Children"]
      }
    },
    # Profile 5: Caring Partner — nurturing, empathetic, family-ready
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship", "Marriage"],
        "Character" => ["Caring", "Empathy", "Family-Oriented", "Honesty", "Modesty"],
        "Want Children" => ["I Want (More) Children"],
        "Sports" => ["Yoga", "Pilates", "Swimming"],
        "Travels" => ["Beach", "Wellness", "Cultural Trips"],
        "Favorite Destinations" => ["Greece", "Italy", "Portugal"],
        "Music" => ["Pop", "Soul", "R&B"],
        "At Home" => ["Cooking", "Baking", "Reading", "Handicrafts", "Series"],
        "Going Out" => ["Cafes", "Karaoke"],
        "Food" => ["Italian", "Greek", "Healthy Food", "Desserts"],
        "Self Care" => ["Deep Conversations", "Good Sleep"],
        "Pets" => ["Cat", "Dog"]
      },
      green: %{
        "Character" => ["Family-Oriented", "Caring", "Honesty", "Empathy"],
        "What I'm Looking For" => ["Long-term Relationship", "Marriage"]
      },
      red: %{
        "Want Children" => ["I Don't Want (More) Children"]
      }
    },
    # Profile 6: Social Star — party-loving, outgoing, sporty
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship", "Something Casual"],
        "Character" => ["Humor", "Self-Confidence", "Active", "Optimism", "Social Awareness"],
        "Sports" => ["Soccer", "Basketball", "Gym", "Boxing"],
        "Travels" => ["City Trips", "Beach", "Active and Sports Vacation"],
        "Favorite Destinations" => ["USA", "Spain", "Thailand"],
        "Music" => ["Hip-Hop", "Rap", "Techno", "House"],
        "At Home" => ["Video Games", "Fitness Exercises", "Cooking"],
        "Going Out" => ["Clubbing", "Bars", "Concerts", "Stand-Up Comedy"],
        "Food" => ["American", "Mexican", "Fast Food", "Street Food"],
        "Creativity" => ["Video Production", "Social Media"]
      },
      green: %{
        "Character" => ["Humor", "Self-Confidence", "Active"],
        "What I'm Looking For" => ["Long-term Relationship"],
        "Sports" => ["Gym"]
      },
      red: %{}
    },
    # Profile 7: Free Spirit — independent, spontaneous, travel-loving
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship", "Dates"],
        "Character" => ["Self-Confidence", "Humor", "Love of Adventure", "Active", "Courage"],
        "Sports" => ["Surfing", "Yoga", "Cycling", "Jogging"],
        "Travels" => ["Beach", "City Trips", "Camping", "Bike Tours"],
        "Favorite Destinations" => ["Bali", "Thailand", "Portugal", "South America"],
        "Music" => ["Reggae", "Electronic", "Latin", "Indie"],
        "At Home" => ["Cooking", "Podcasts", "Meditation", "Music"],
        "Going Out" => ["Festivals", "Bars", "Concerts"],
        "Food" => ["Thai", "Vietnamese", "Street Food", "Healthy Food"],
        "Creativity" => ["Photography", "Making Music", "Dancing"],
        "Self Care" => ["Mindfulness", "Going Offline"]
      },
      green: %{
        "Character" => ["Humor", "Active", "Self-Confidence", "Love of Adventure"],
        "What I'm Looking For" => ["Long-term Relationship"]
      },
      red: %{}
    },
    # Profile 8: Quiet Thinker — introverted, deep, book-loving
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship"],
        "Character" => ["Honesty", "Intelligence", "Empathy", "Modesty", "Resilience"],
        "Sports" => ["Hiking", "Swimming", "Yoga"],
        "Travels" => ["Cultural Trips", "Hiking Vacation"],
        "Favorite Destinations" => ["Germany", "Austria", "United Kingdom"],
        "Music" => ["Classical", "Folk", "Blues", "Jazz"],
        "At Home" => ["Reading", "Puzzles", "Meditation", "Audiobooks", "Journaling"],
        "Going Out" => ["Museums & Galleries", "Cafes"],
        "Food" => ["Japanese", "Indian", "Mediterranean"],
        "Literature" => ["Philosophy", "Science Fiction", "Classics", "Psychology"],
        "Self Care" => ["Deep Conversations", "Mindfulness", "Good Sleep"]
      },
      green: %{
        "Character" => ["Honesty", "Empathy", "Intelligence"],
        "What I'm Looking For" => ["Long-term Relationship"]
      },
      red: %{}
    },
    # Profile 9: Romantic — loving, sentimental, partner-focused
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "What I'm Looking For" => ["Long-term Relationship", "Marriage"],
        "Character" => ["Being Romantic", "Empathy", "Honesty", "Caring", "Intelligence"],
        "Sports" => ["Yoga", "Swimming", "Pilates"],
        "Travels" => ["Beach", "Wellness", "Cruises"],
        "Favorite Destinations" => ["Italy", "Greece", "France", "Mallorca"],
        "Music" => ["Pop", "Soul", "Classical", "R&B"],
        "At Home" => ["Cooking", "Movies", "Series", "Reading", "Baking"],
        "Going Out" => ["Theater", "Cafes", "Concerts"],
        "Food" => ["Italian", "French", "Desserts", "Mediterranean"],
        "Creativity" => ["Photography", "Writing"],
        "Literature" => ["Romance Novels", "Novels", "Poetry"]
      },
      green: %{
        "Character" => ["Honesty", "Empathy", "Being Romantic", "Intelligence"],
        "What I'm Looking For" => ["Long-term Relationship", "Marriage"]
      },
      red: %{}
    }
  ]

  def seed_all do
    IO.puts("\n=== Seeding Development Users ===\n")

    country = GeoData.get_country_by_code("DE")

    unless country do
      raise "Germany (DE) not found in countries table. Run geo data seeds first."
    end

    # Seed male users
    IO.puts("Creating male users...")

    for {user_data, index} <- Enum.with_index(@male_users) do
      create_user(user_data, "male", country.id, index)
    end

    # Seed female users
    IO.puts("\nCreating female users...")

    for {user_data, index} <- Enum.with_index(@female_users) do
      create_user(user_data, "female", country.id, index + 30)
    end

    IO.puts("\n=== Development Users Seeded Successfully ===")
    IO.puts("Total users created: 60")
    IO.puts("Password for all: #{@password}\n")
  end

  defp create_user(user_data, gender, country_id, index) do
    birthday = birthday_from_age(user_data.age)
    phone = generate_phone(index)
    preferred_gender = if gender == "male", do: ["female"], else: ["male"]
    height = if gender == "male", do: Enum.random(170..195), else: Enum.random(155..180)

    attrs = %{
      email: user_data.email,
      password: @password,
      first_name: user_data.first_name,
      last_name: user_data.last_name,
      display_name: user_data.first_name,
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
        # Confirm and activate the user
        user = confirm_and_activate_user(user)

        # Assign roles
        assign_roles(user, user_data.roles)

        # Add traits from personality profile
        assign_traits(user, gender, index)

        # Update pinned intro item with actual content
        update_intro_story(user, index)

        # Create avatar and link to pinned item
        create_avatar(user, gender, index)

        # Create moodboard items
        create_moodboard(user, index)

        IO.puts("  Created: #{user_data.first_name} #{user_data.last_name} (#{user_data.email})")
        {:ok, user}

      {:error, reason} ->
        IO.puts("  ERROR creating #{user_data.first_name} #{user_data.last_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp birthday_from_age(age) do
    today = Date.utc_today()
    # Subtract age years and a random number of days (0-364)
    Date.add(today, -(age * 365 + Enum.random(0..364)))
  end

  defp generate_phone(index) do
    # Generate unique German mobile numbers
    # Valid mobile prefixes that ExPhoneNumber recognizes as :mobile
    # Format: +49 1xx xxxxxxxx (total 11 digits after +49)
    prefixes = ["150", "151", "152", "153", "155", "156", "157", "159", "160", "162", "163", "172", "176", "177", "178", "179"]
    prefix = Enum.at(prefixes, rem(index, length(prefixes)))
    # Generate 8 more digits for a total of 11 digits (15x + 8 = 11)
    suffix = String.pad_leading("#{10000000 + index}", 8, "0")
    "+49#{prefix}#{suffix}"
  end

  defp confirm_and_activate_user(user) do
    # Set confirmed_at and state to "normal" directly in DB
    now = DateTime.utc_now(:second)

    {1, _} =
      Repo.update_all(
        from(u in Animina.Accounts.User, where: u.id == ^user.id),
        set: [confirmed_at: now, state: "normal"]
      )

    Repo.get!(Animina.Accounts.User, user.id)
  end

  defp assign_roles(user, roles) do
    for role <- roles do
      role_str = to_string(role)
      Accounts.assign_role(user, role_str)
    end
  end

  defp update_intro_story(user, seed_index) do
    :rand.seed(:exsss, {seed_index * 17, seed_index * 19, seed_index * 23})
    story_content = Enum.random(@german_intro_stories)

    case Moodboard.get_pinned_item(user.id) do
      nil ->
        :ok

      item ->
        if item.moodboard_story do
          Moodboard.update_story(item.moodboard_story, story_content)
        end
    end
  end

  defp create_avatar(user, gender, seed_index) do
    avatar_path = get_avatar_source_path(gender, seed_index)

    case Photos.upload_photo("User", user.id, avatar_path, type: "avatar", skip_enqueue: true) do
      {:ok, photo} ->
        # Process the photo (resize, webp) and approve it
        Photos.process_for_seeding(photo)

        # Link avatar to the pinned moodboard item
        Moodboard.link_avatar_to_pinned_item(user.id, photo.id)
        {:ok, photo}

      {:error, reason} ->
        IO.puts("    Warning: Could not create avatar for #{user.display_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_avatar_source_path(gender, seed_index) do
    # Pick avatar based on gender and seed index
    avatar_list = if gender == "male", do: @male_avatar_photos, else: @female_avatar_photos
    avatar_filename = Enum.at(avatar_list, rem(seed_index, length(avatar_list)))

    Path.join([
      :code.priv_dir(:animina),
      "static",
      "images",
      "seeds",
      "avatars",
      avatar_filename
    ])
  end

  defp assign_traits(user, gender, seed_index) do
    # Ensure default published categories are set
    Traits.ensure_default_published_categories(user)

    # Build lookup once and assign from personality profile
    lookup = build_flag_lookup()

    # Males use position directly (0,1,2,...), females offset by 1 (1,2,3,...,0)
    # so complementary profile pairs land on opposite genders
    position = if gender == "male", do: seed_index, else: seed_index - 30
    profile_index = if gender == "male", do: rem(position, 10), else: rem(position + 1, 10)
    profile = Enum.at(@trait_profiles, profile_index)

    assign_profile_traits(user, profile, lookup)

    # Always assign "Deutsch" as spoken language
    case get_in(lookup, ["Languages", "Deutsch"]) do
      nil -> :ok
      flag -> Traits.add_user_flag(%{user_id: user.id, flag_id: flag.id, color: "white", intensity: "hard", position: 1})
    end
  end

  defp build_flag_lookup do
    # Build %{category_name => %{flag_name => flag}} for efficient lookups
    for category <- Traits.list_categories(), into: %{} do
      flags = Traits.list_flags_by_category(category)
      flag_map = for f <- flags, into: %{}, do: {f.name, f}
      {category.name, flag_map}
    end
  end

  defp assign_profile_traits(user, profile, lookup) do
    # Assign white flags
    for {category_name, flag_names} <- profile.white do
      for {flag_name, pos} <- Enum.with_index(flag_names, 1) do
        case get_in(lookup, [category_name, flag_name]) do
          nil ->
            IO.puts("    Warning: flag '#{flag_name}' not found in '#{category_name}'")

          flag ->
            Traits.add_user_flag(%{
              user_id: user.id,
              flag_id: flag.id,
              color: "white",
              intensity: "hard",
              position: pos
            })
        end
      end
    end

    # Assign green flags
    for {category_name, flag_names} <- profile.green do
      for {flag_name, pos} <- Enum.with_index(flag_names, 1) do
        case get_in(lookup, [category_name, flag_name]) do
          nil -> :ok
          flag ->
            Traits.add_user_flag(%{
              user_id: user.id,
              flag_id: flag.id,
              color: "green",
              intensity: "hard",
              position: pos
            })
        end
      end
    end

    # Assign red flags
    for {category_name, flag_names} <- profile.red do
      for {flag_name, pos} <- Enum.with_index(flag_names, 1) do
        case get_in(lookup, [category_name, flag_name]) do
          nil -> :ok
          flag ->
            Traits.add_user_flag(%{
              user_id: user.id,
              flag_id: flag.id,
              color: "red",
              intensity: "hard",
              position: pos
            })
        end
      end
    end
  end

  defp create_moodboard(user, seed_index) do
    # Determine moodboard size based on seed index (doubled from original)
    # ~15 users with 4-6 items, ~20 with 8-12, ~15 with 16-20
    item_count =
      cond do
        seed_index < 15 -> Enum.random(4..6)
        seed_index < 35 -> Enum.random(8..12)
        true -> Enum.random(16..20)
      end

    # Shuffle photos for this user (cycle through if needed)
    :rand.seed(:exsss, {seed_index * 7, seed_index * 11, seed_index * 13})
    shuffled_photos = Enum.shuffle(@lifestyle_photos)

    # Cycle through photos if we need more than available
    photos_to_use =
      Stream.cycle(shuffled_photos)
      |> Enum.take(item_count)

    for {photo_filename, idx} <- Enum.with_index(photos_to_use) do
      source_path = photo_source_path(photo_filename)

      # Mix of item types: ~50% photo+text, ~30% photo only, ~20% text only
      rand_val = :rand.uniform()

      cond do
        rand_val < 0.5 ->
          # Combined photo + story
          story = Enum.random(@german_story_contents)
          create_combined_moodboard_item(user, source_path, story)

        rand_val < 0.8 ->
          # Photo only
          create_photo_moodboard_item(user, source_path)

        true ->
          # Text only (every 5th text-only gets a longer story)
          story =
            if rem(idx, 5) == 0 do
              Enum.random(@german_long_stories)
            else
              Enum.random(@german_story_contents)
            end

          create_story_moodboard_item(user, story)
      end

      # Small delay to ensure unique positions
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
    case Moodboard.create_photo_item(user, source_path, skip_enqueue: true) do
      {:ok, item} ->
        # Process the photo (resize, webp) and approve it
        item = Repo.preload(item, moodboard_photo: :photo)

        if item.moodboard_photo && item.moodboard_photo.photo do
          Photos.process_for_seeding(item.moodboard_photo.photo)
        end

        {:ok, item}

      error ->
        error
    end
  end

  defp create_combined_moodboard_item(user, source_path, story) do
    case Moodboard.create_combined_item(user, source_path, story, skip_enqueue: true) do
      {:ok, item} ->
        # Process the photo (resize, webp) and approve it
        item = Repo.preload(item, moodboard_photo: :photo)

        if item.moodboard_photo && item.moodboard_photo.photo do
          Photos.process_for_seeding(item.moodboard_photo.photo)
        end

        {:ok, item}

      error ->
        error
    end
  end

  defp create_story_moodboard_item(user, story) do
    Moodboard.create_story_item(user, story)
  end
end
