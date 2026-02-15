# Development seed data for testing
# This file is only loaded in dev environment via seeds.exs

defmodule Animina.Seeds.DevUsers do
  @moduledoc """
  Seeds development test accounts with full profiles, traits, and moodboards.
  All accounts use the password "password" and are located in Koblenz (56068).
  Avatars are dynamically generated from this-person-does-not-exist.com and cached locally.
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

  # 10 personality profiles designed as 5 complementary pairs.
  # Males cycle 0..9, females cycle 1..9,0 (offset by 1) so complementary
  # profiles land on opposite genders for high discovery scores.
  #
  # Flag counts are deliberately varied to test the per-color limits
  # (white: 16, green: 10, red: 10 — configured via admin settings).
  # Each white count below is BEFORE the automatic +1 Deutsch flag.
  #
  # Profile  | White (+1) | Green | Red  | Test purpose
  # ---------|------------|-------|------|-------------------------------
  # 0 Adven  |  5  (= 6)  |   3   |  1   | Minimal user, lots of room
  # 1 Nature |  8  (= 9)  |   4   |  2   | Moderate, filters out 6
  # 2 Create | 11  (=12)  |   5   |  2   | Active, filters out 4
  # 3 Intell | 14  (=15)  |   5   |  2   | Near white limit, filters 4,6
  # 4 Family | 15  (=16)  |   9   |  1   | At white limit, near green
  # 5 Caring | 15  (=16)  |  10   |  1   | At white + green limits
  # 6 Social |  8  (= 9)  |  10   |  2   | At green limit, filters 1,3,9
  # 7 Free   | 10  (=11)  |   5   |  9   | Near red limit, filters 1,3,4,5,9
  # 8 Quiet  |  3  (= 4)  |   4   |  2   | Very minimal, filters out 6
  # 9 Romant | 15  (=16)  |  10   | 10   | Maxed all colors, filters 4,6,7
  #
  # IMPORTANT: No flag appears in more than one color within the same profile
  # (validate_no_mixing would reject it).
  @trait_profiles [
    # Profile 0: Adventurer — loves outdoor action, travel (5 white, 3 green, 1 red)
    # Green flags chosen to match Profile 1's white (Empathy, Caring, Hiking)
    %{
      white: %{
        "Relationship Status" => ["Single"],
        "Character" => ["Love of Adventure", "Courage"],
        "Sports" => ["Hiking", "Surfing"]
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
    # Profile 1: Nature Soul — calm outdoors lover, wellness (8 white, 4 green, 2 red)
    # Green flags chosen to match Profile 0's white (Love of Adventure, Courage, Hiking, Surfing)
    # Red conflicts: Hip-Hop → filters out Profile 6; Soccer → filters out Profile 6
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
    # Profile 2: Creative — artistic, music-loving, design-focused (11 white, 5 green, 2 red)
    # Green flags chosen to match Profile 3's white (Intelligence, Honesty, Classical, Reading)
    # Red conflicts: Schlager → filters out Profile 4; Camping → filters out Profile 4
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
    # Profile 3: Intellectual — reader, thinker, deep conversations (14 white, 5 green, 2 red)
    # Green flags chosen to match Profile 2's white (Creativity, Empathy, Jazz, Yoga, Painting)
    # Red conflicts: Schlager → filters out Profile 4; Hip-Hop → filters out Profile 6
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
    # Profile 4: Family Person — caring, home-loving, traditional (15 white, 9 green, 1 red)
    # Green flags chosen to match Profile 5's white (Caring, Empathy, Yoga, Swimming, Pop, Cooking)
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
    # Profile 5: Caring Partner — nurturing, empathetic, family-ready (15 white, 10 green, 1 red)
    # Green flags chosen to match Profile 4's white (Family-Oriented, Honesty, Swimming, Beach, Pop, Cooking, Baking)
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
    # Profile 6: Social Star — party-loving, outgoing, sporty (8 white, 10 green, 2 red)
    # Green flags chosen to match Profile 7's white (Self-Confidence, Humor, Love of Adventure, Surfing, Yoga, Reggae)
    # Red conflicts: Classical → filters out Profiles 1, 3, 9; Folk → filters out Profile 1
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
    # Profile 7: Free Spirit — independent, spontaneous, travel-loving (10 white, 5 green, 9 red)
    # Green flags chosen to match Profile 6's white (Humor, Active, Soccer, Basketball, Hip-Hop)
    # Red conflicts: Schlager → 4; Pop → 4,5,9; Classical → 1,3,9; Cooking → 4,5,9
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
    # Profile 8: Quiet Thinker — introverted, deep, book-loving (3 white, 4 green, 2 red)
    # Green flags chosen to match Profile 9's white (Empathy, Honesty, Yoga, Swimming, Classical)
    # Red conflicts: Hip-Hop → filters out Profile 6; Soccer → filters out Profile 6
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
    # Profile 9: Romantic — loving, sentimental, partner-focused (15 white, 10 green, 10 red)
    # Green flags chosen to match Profile 8's white (Honesty, Intelligence)
    # Red conflicts: Hip-Hop/Soccer/Basketball → 6; Electronic/Self-Confidence → 6,7; Camping → 4
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
    }
  ]

  # 40 additional female users for V2 discovery funnel testing.
  # Grouped by which filter step should drop them from Thomas's perspective.
  # Thomas: age 32, height 186, male, prefers female, Koblenz 56068,
  #         search_radius 60, hard-red Vegan, white Hiking/Surfing/Camping/Rock
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

    # --- Group B: Distance Drops — outside Thomas's 60km radius (8 users) ---
    # Mainz ~62km, Siegen ~65km → just outside; Köln ~80km, Frankfurt ~82km, Trier ~96km → clearly outside
    %{group: :distance, name: "Pia", last: "Moeller", zip: "55116", age: 30, height: 168, search_radius: 45},
    %{group: :distance, name: "Romy", last: "Naumann", zip: "55116", age: 29, height: 170, search_radius: 40},
    %{group: :distance, name: "Sofia", last: "Otto", zip: "57072", age: 31, height: 166, search_radius: 50},
    %{group: :distance, name: "Theresa", last: "Peters", zip: "57072", age: 33, height: 172, search_radius: 45},
    %{group: :distance, name: "Anja", last: "Reuter", zip: "50667", age: 30, height: 168, search_radius: 50},
    %{group: :distance, name: "Bettina", last: "Seidel", zip: "50667", age: 28, height: 165, search_radius: 50},
    %{group: :distance, name: "Carla", last: "Thiel", zip: "60311", age: 32, height: 170, search_radius: 50},
    %{group: :distance, name: "Dina", last: "Ulrich", zip: "54290", age: 29, height: 167, search_radius: 50},

    # --- Group C: Height Drops — partner height prefs exclude Thomas at 186cm (6 users) ---
    %{group: :height, name: "Edith", last: "Vogt", zip: "56068", age: 30, height: 165, search_radius: 100, partner_height_min: 195},
    %{group: :height, name: "Frieda", last: "Walther", zip: "56068", age: 29, height: 162, search_radius: 100, partner_height_min: 195},
    %{group: :height, name: "Gisela", last: "Xander", zip: "56068", age: 31, height: 170, search_radius: 100, partner_height_min: 195},
    %{group: :height, name: "Hedwig", last: "Yildiz", zip: "56068", age: 28, height: 168, search_radius: 100, partner_height_max: 175},
    %{group: :height, name: "Irene", last: "Ziegler", zip: "56068", age: 33, height: 163, search_radius: 100, partner_height_max: 175},
    %{group: :height, name: "Jutta", last: "Adler", zip: "56068", age: 30, height: 167, search_radius: 100, partner_height_max: 175},

    # --- Group D: Blacklisted — blacklist Thomas's email or phone (5 users) ---
    %{group: :blacklist, name: "Klara", last: "Bach", zip: "56068", age: 30, height: 168, search_radius: 100, blacklist: "dev-thomas@animina.test"},
    %{group: :blacklist, name: "Lotte", last: "Conrad", zip: "56068", age: 29, height: 170, search_radius: 100, blacklist: "dev-thomas@animina.test"},
    %{group: :blacklist, name: "Magda", last: "Dreyer", zip: "56068", age: 31, height: 165, search_radius: 100, blacklist: "dev-thomas@animina.test"},
    %{group: :blacklist, name: "Nele", last: "Ebert", zip: "56068", age: 28, height: 172, search_radius: 100, blacklist: "+4915010000000"},
    %{group: :blacklist, name: "Olivia", last: "Fink", zip: "56068", age: 33, height: 167, search_radius: 100, blacklist: "+4915010000000"},

    # --- Group E: Hard-Red Conflicts (5 users) ---
    # 3 have Vegan as white → Thomas's hard-red Vegan triggers Direction A
    # 2 have hard-red Hiking → Thomas's white Hiking triggers Direction B
    %{group: :red, name: "Paula", last: "Graf", zip: "56068", age: 30, height: 168, search_radius: 100, trait: {:white, "Diet", "Vegan"}},
    %{group: :red, name: "Renate", last: "Horn", zip: "56068", age: 29, height: 170, search_radius: 100, trait: {:white, "Diet", "Vegan"}},
    %{group: :red, name: "Svenja", last: "Iske", zip: "56068", age: 31, height: 165, search_radius: 100, trait: {:white, "Diet", "Vegan"}},
    %{group: :red, name: "Thea", last: "Janssen", zip: "56068", age: 28, height: 172, search_radius: 100, trait: {:red, "Sports", "Hiking"}},
    %{group: :red, name: "Ursula", last: "Keller", zip: "56068", age: 33, height: 167, search_radius: 100, trait: {:red, "Sports", "Hiking"}},

    # --- Group F: Age Drops — outside Thomas's bidirectional age range (6 users) ---
    # Young (21): Thomas accepts 26-34, so 21 is out; also 21+2=23 < Thomas's 32
    # Older (44): Thomas accepts 26-34, so 44 is out; also 44-2=42 > Thomas's 32
    %{group: :age, name: "Veronika", last: "Lang", zip: "56068", age: 21, height: 168, search_radius: 100, partner_maximum_age_offset: 2},
    %{group: :age, name: "Wiebke", last: "Marx", zip: "56068", age: 21, height: 170, search_radius: 100, partner_maximum_age_offset: 2},
    %{group: :age, name: "Xenia", last: "Nowak", zip: "56068", age: 21, height: 165, search_radius: 100, partner_maximum_age_offset: 2},
    %{group: :age, name: "Yvonne", last: "Oswald", zip: "56068", age: 44, height: 167, search_radius: 100, partner_minimum_age_offset: 2},
    %{group: :age, name: "Zara", last: "Pohl", zip: "56068", age: 44, height: 163, search_radius: 100, partner_minimum_age_offset: 2},
    %{group: :age, name: "Astrid", last: "Ritter", zip: "56068", age: 44, height: 172, search_radius: 100, partner_minimum_age_offset: 2}
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

  @doc """
  Seeds 40 additional female users designed to exercise every V2 discovery
  filter step when viewed from Thomas's perspective.
  """
  def seed_v2_test_users do
    IO.puts("\n=== Seeding V2 Discovery Test Users ===\n")

    country = GeoData.get_country_by_code("DE")

    unless country do
      raise "Germany (DE) not found in countries table. Run geo data seeds first."
    end

    lookup = build_flag_lookup()

    for {user_data, idx} <- Enum.with_index(@v2_test_users) do
      create_v2_user(user_data, country.id, idx, lookup)
    end

    IO.puts("\n=== V2 Test Users Seeded (#{length(@v2_test_users)} users) ===\n")
  end

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

        # Create avatar
        cache_key = "avatar-" <> (email |> String.split("@") |> hd())
        create_avatar(user, "female", data.age, cache_key)

        IO.puts("  Created: #{data.name} #{data.last} (#{email}) [#{data.group}]")
        {:ok, user}

      {:error, reason} ->
        IO.puts("  ERROR: #{data.name} #{data.last}: #{inspect(reason)}")
        {:error, reason}
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
      nil -> :ok
      category_id ->
        Animina.Traits.UserCategoryOptIn.changeset(
          %Animina.Traits.UserCategoryOptIn{},
          %{user_id: user.id, category_id: category_id}
        )
        |> Repo.insert(on_conflict: :nothing)
    end
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
        cache_key = "avatar-" <> (user_data.email |> String.split("@") |> hd())
        create_avatar(user, gender, user_data.age, cache_key)

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

  defp create_avatar(user, gender, age, cache_key) do
    avatar_path = generate_avatar(gender, age, cache_key)

    case Photos.upload_photo("User", user.id, avatar_path, type: "avatar") do
      {:ok, photo} ->
        Moodboard.link_avatar_to_pinned_item(user.id, photo.id)
        {:ok, photo}

      {:error, reason} ->
        IO.puts("    Warning: Could not create avatar for #{user.display_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_avatar(gender, age, cache_key) do
    avatar_dir = Path.join([:code.priv_dir(:animina), "static", "images", "seeds", "avatars", gender])
    dest_path = Path.join(avatar_dir, "#{cache_key}.jpg")

    if File.exists?(dest_path) do
      dest_path
    else
      File.mkdir_p!(avatar_dir)
      download_and_resize_avatar(gender, age, dest_path)
      dest_path
    end
  end

  defp download_and_resize_avatar(gender, age, dest_path) do
    :inets.start()
    :ssl.start()

    age_bracket = age_to_api_bracket(age)
    ms = System.system_time(:millisecond)
    api_url = "https://this-person-does-not-exist.com/new?time=#{ms}&gender=#{gender}&age=#{age_bracket}"

    IO.puts("    Downloading avatar: #{gender}/#{Path.basename(dest_path)} (age #{age_bracket})...")

    ssl_opts = [ssl: [verify: :verify_none]]

    {:ok, {{_, 200, _}, _, json_body}} =
      :httpc.request(:get, {String.to_charlist(api_url), []}, ssl_opts ++ [timeout: 15_000], [])

    %{"src" => src} = Jason.decode!(List.to_string(json_body))
    image_url = "https://this-person-does-not-exist.com#{src}"

    {:ok, {{_, 200, _}, _, image_data}} =
      :httpc.request(:get, {String.to_charlist(image_url), []}, ssl_opts ++ [timeout: 30_000], [])

    File.write!(dest_path, IO.iodata_to_binary(image_data))

    # Resize to 400x400 using sips (macOS) or convert (Linux)
    case System.cmd("sips", ["-z", "400", "400", dest_path], stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ ->
        case System.cmd("convert", [dest_path, "-resize", "400x400!", dest_path], stderr_to_stdout: true) do
          {_, 0} -> :ok
          _ -> :ok
        end
    end

    # Rate limit: 1.5s between API calls
    Process.sleep(1_500)
  end

  defp age_to_api_bracket(age) when age <= 25, do: "19-25"
  defp age_to_api_bracket(age) when age <= 35, do: "26-35"
  defp age_to_api_bracket(age) when age <= 50, do: "35-50"
  defp age_to_api_bracket(_age), do: "50+"

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
end
