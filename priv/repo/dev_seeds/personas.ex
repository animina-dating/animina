defmodule Animina.Seeds.Personas do
  @moduledoc """
  Persona definitions for 114 development test accounts.
  Each persona has a unique `character` description and topic-matched content.

  Thomas is at index 0 (discovery tests reference his phone and email).
  Email format: dev-{first}-{last}@animina.test (Thomas: dev-thomas@animina.test)

  Required fields:
    name, last_name, gender, age, avatar (filename stem → avatar-dev-{stem}.jpg)
    profile (index into personality_profiles), topics (for moodboard matching)
    character (unique personality description in German)

  Optional fields:
    roles, waitlisted, height, activity, group, zip_code, search_radius,
    partner_height_min/max, partner_minimum/maximum_age_offset,
    blacklist, conflict_trait
  """

  def all do
    males() ++ females() ++ discovery_test_users()
  end

  # ==========================================================================
  # MALES (30)
  # ==========================================================================
  def males do
    [
      # Thomas first — V2 discovery test anchor (profile 0 = Adventurer)
      # Activity :daily_active = logs in almost every day, multiple times
      %{name: "Thomas", last_name: "Friedrich", gender: "male", age: 32, avatar: "thomas", profile: 0, topics: [:hiking, :books, :mountains], roles: [:admin], height: 186, activity: :daily_active,
        character: "Abenteuerlustiger Bergsteiger, der Gipfelmomente sammelt und am Lagerfeuer die besten Geschichten erzählt."},

      # Activity :weekend_warrior = mainly logs in on weekends
      %{name: "Karim", last_name: "Hassan", gender: "male", age: 26, avatar: "karim", profile: 6, topics: [:music, :travel, :coffee], activity: :weekend_warrior,
        character: "Charmanter Weltenbummler mit ansteckender Lebensfreude und immer einer Playlist in der Tasche."},

      %{name: "Raj", last_name: "Sharma", gender: "male", age: 25, avatar: "raj", profile: 16, topics: [:coffee, :books, :music],
        character: "Wissbegieriger Denker, der zwischen Bücherstapeln und Podcasts sein Glück findet."},

      %{name: "Wei", last_name: "Chen", gender: "male", age: 24, avatar: "wei", profile: 3, topics: [:books, :coffee, :art],
        character: "Stiller Ästhet, der in Kunstgalerien und Philosophie-Seminaren aufblüht."},

      # Activity :sporadic = logs in a few times a month, irregularly
      %{name: "Marko", last_name: "Petrovic", gender: "male", age: 25, avatar: "marko", profile: 10, topics: [:cycling, :hiking, :nature], activity: :sporadic,
        character: "Sportbesessener Naturbursche, der jede freie Minute auf dem Rad oder im Wald verbringt."},

      # Activity :evening_regular = logs in most evenings (weekdays)
      %{name: "Fynn", last_name: "Scholz", gender: "male", age: 27, avatar: "fynn", profile: 0, topics: [:hiking, :beach, :travel], activity: :evening_regular,
        character: "Sonnenhungriger Abenteurer, der die Welt bereist und überall zu Hause ist."},

      %{name: "Nico", last_name: "Bauer", gender: "male", age: 24, avatar: "nico", profile: 7, topics: [:music, :travel, :beach],
        character: "Freigeist mit Surfbrett und Gitarre, der Konventionen hinter sich lässt."},

      # Activity :new_user = only started logging in recently (last 2 weeks)
      %{name: "Björn", last_name: "Lindqvist", gender: "male", age: 33, avatar: "bjoern", profile: 0, topics: [:hiking, :mountains, :nature], roles: [:admin], activity: :new_user,
        character: "Skandinavisch geprägter Outdoor-Enthusiast, der Berge und Stille liebt."},

      %{name: "Samuel", last_name: "Adeyemi", gender: "male", age: 32, avatar: "samuel", profile: 11, topics: [:music, :art, :coffee],
        character: "Soulvoller Musiker, der in Jazz-Clubs und Kaffeehäusern seine Inspiration findet."},

      %{name: "Torsten", last_name: "Krüger", gender: "male", age: 34, avatar: "torsten", profile: 12, topics: [:cooking, :food, :coffee], roles: [:admin],
        character: "Leidenschaftlicher Hobbykoch, der die Welt durch ihre Küchen entdeckt."},

      %{name: "Jörg", last_name: "Hauser", gender: "male", age: 43, avatar: "joerg", profile: 19, topics: [:cooking, :garden, :nature],
        character: "Bodenständiger Genussmensch mit grünem Daumen und großem Herz."},

      %{name: "Viktor", last_name: "Volkov", gender: "male", age: 35, avatar: "viktor", profile: 10, topics: [:cycling, :hiking, :nature],
        character: "Ausdauersportler mit russischen Wurzeln und einer Leidenschaft für lange Touren."},

      %{name: "Anton", last_name: "Nowak", gender: "male", age: 24, avatar: "anton", profile: 16, topics: [:coffee, :books, :music],
        character: "Digitaler Nomade, der zwischen Online-Kursen und Vinyl-Schallplatten lebt."},

      %{name: "Klaus", last_name: "Dietrich", gender: "male", age: 45, avatar: "klaus", profile: 19, topics: [:cooking, :garden, :hiking],
        character: "Erfahrener Lebensgenießer, der seine Ruhe im Garten und auf Wanderwegen findet."},

      %{name: "Emmanuel", last_name: "Asante", gender: "male", age: 24, avatar: "emmanuel", profile: 11, topics: [:music, :art, :coffee],
        character: "Kreativer Geist mit westafrikanischen Rhythmen im Blut und einem Auge für Kunst."},

      %{name: "Rafael", last_name: "Santos", gender: "male", age: 25, avatar: "rafael", profile: 14, topics: [:travel, :beach, :music],
        character: "Brasilianisch temperamentvoller Reisender, der Strände und Live-Musik sammelt."},

      %{name: "Tim", last_name: "Schneider", gender: "male", age: 24, avatar: "tim", profile: 0, topics: [:beach, :hiking, :nature],
        character: "Entspannter Naturliebhaber, der zwischen Strand und Bergen sein Gleichgewicht findet."},

      %{name: "Philipp", last_name: "Walter", gender: "male", age: 33, avatar: "philipp", profile: 4, topics: [:cooking, :garden, :pets],
        character: "Warmherziger Familienmensch, der seinen Garten pflegt und seinen Hund vergöttert."},

      %{name: "Erik", last_name: "Voss", gender: "male", age: 22, avatar: "erik", profile: 15, topics: [:yoga, :nature, :coffee],
        character: "Achtsamer Minimalist, der Yoga am Rheinufer praktiziert und Kräutertee der Party vorzieht."},

      %{name: "Osman", last_name: "Çelik", gender: "male", age: 33, avatar: "osman", profile: 12, topics: [:cooking, :food, :coffee],
        character: "Genussmensch mit türkischen Wurzeln, der die besten Gewürzmischungen kennt."},

      %{name: "Felix", last_name: "Lorenz", gender: "male", age: 25, avatar: "felix", profile: 6, topics: [:music, :travel, :coffee],
        character: "Energiegeladener Netzwerker, der auf jedem Festival die besten Leute kennenlernt."},

      %{name: "Patrick", last_name: "Klein", gender: "male", age: 34, avatar: "patrick", profile: 9, topics: [:sunset, :cooking, :coffee],
        character: "Hoffnungsloser Romantiker, der Sonnenuntergänge sammelt und mit Herzblut kocht."},

      %{name: "Kwame", last_name: "Owusu", gender: "male", age: 33, avatar: "kwame", profile: 2, topics: [:art, :books, :music],
        character: "Ghanaisch-deutscher Künstler, der zwischen Atelier und Buchhandlung pendelt."},

      %{name: "Hamid", last_name: "Tehrani", gender: "male", age: 44, avatar: "hamid", profile: 5, topics: [:garden, :cooking, :books],
        character: "Fürsorglicher Familienmensch persischer Herkunft, der im Garten seine Ruhe findet."},

      %{name: "Arjun", last_name: "Patel", gender: "male", age: 27, avatar: "arjun", profile: 16, topics: [:coffee, :books, :music],
        character: "Technikbegeisterter Informatiker, der abends Gitarre spielt und Sachbücher verschlingt."},

      %{name: "Samir", last_name: "Mansour", gender: "male", age: 25, avatar: "samir", profile: 18, topics: [:coffee, :books, :travel],
        character: "Ambitionierter Jungunternehmer, der zwischen Startup-Events und Städtereisen jongliert."},

      %{name: "Gabriel", last_name: "Costa", gender: "male", age: 26, avatar: "gabriel", profile: 11, topics: [:music, :art, :coffee],
        character: "Brasilianischer Musiker, der Bossa Nova in die Koblenzer Café-Szene bringt."},

      %{name: "Leon", last_name: "Weber", gender: "male", age: 24, avatar: "leon", profile: 6, topics: [:music, :travel, :coffee],
        character: "Geselliger Stadtmensch, der auf spontane Roadtrips und guten Espresso schwört."},

      %{name: "Alessandro", last_name: "Martini", gender: "male", age: 26, avatar: "alessandro", profile: 9, topics: [:sunset, :cooking, :coffee],
        character: "Italienischer Charme trifft rheinische Gemütlichkeit — kocht Pasta und genießt Sonnenuntergänge."},

      %{name: "Daniel", last_name: "Park", gender: "male", age: 21, avatar: "daniel", profile: 0, topics: [:hiking, :beach, :nature],
        character: "Jüngster im Freundeskreis aber mit dem größten Fernweh — Strand und Berge gleichzeitig bitte."}
    ]
  end

  # ==========================================================================
  # FEMALES (45)
  # ==========================================================================
  def females do
    [
      # Activity :daily_active = very active user
      %{name: "Sabine", last_name: "Hartmann", gender: "female", age: 32, avatar: "sabine", profile: 18, topics: [:coffee, :books, :travel], roles: [:moderator], activity: :daily_active,
        character: "Zielstrebige Moderatorin mit einer Schwäche für Buchhandlungen und Städtetrips."},

      # Activity :morning_routine = logs in most mornings
      %{name: "Nina", last_name: "Schulz", gender: "female", age: 24, avatar: "nina", profile: 0, topics: [:hiking, :beach, :nature], activity: :morning_routine,
        character: "Sonnenkind mit Wanderschuhen, das den Sommer am liebsten nie enden lassen würde."},

      %{name: "Mei", last_name: "Tanaka", gender: "female", age: 26, avatar: "mei", profile: 2, topics: [:art, :coffee, :music],
        character: "Japanisch-deutsche Künstlerin, die Aquarelle malt und nebenbei Jazz hört."},

      # Activity :fading = was active weeks ago, now barely logs in
      %{name: "Claudia", last_name: "Richter", gender: "female", age: 34, avatar: "claudia", profile: 18, topics: [:books, :coffee, :yoga], roles: [:admin], activity: :fading,
        character: "Analytische Juristin, die beim Yoga und mit einem guten Buch abschalten kann."},

      # Activity :weekend_warrior
      %{name: "Amara", last_name: "Okafor", gender: "female", age: 25, avatar: "amara", profile: 6, topics: [:music, :travel, :coffee], activity: :weekend_warrior,
        character: "Lebenslustige Tänzerin mit nigerianischen Wurzeln und einem Lachen, das Räume füllt."},

      # Activity :sporadic
      %{name: "Ronja", last_name: "Lindgren", gender: "female", age: 23, avatar: "ronja", profile: 13, topics: [:pets, :nature, :garden], activity: :sporadic,
        character: "Tierflüsterin mit schwedischen Vorfahren, deren Herz für Hunde und Wildblumen schlägt."},

      %{name: "Hannah", last_name: "Weber", gender: "female", age: 22, avatar: "hannah", profile: 15, topics: [:yoga, :nature, :coffee],
        character: "Ausgeglichene Yogini, die morgens meditiert und abends Kräutertee trinkt."},

      %{name: "Svenja", last_name: "Brandt", gender: "female", age: 24, avatar: "svenja", profile: 1, topics: [:hiking, :nature, :yoga],
        character: "Stille Naturliebhaberin, die beim Wandern mehr innere Ruhe findet als in jedem Spa."},

      %{name: "Mia", last_name: "Schröder", gender: "female", age: 21, avatar: "mia", profile: 2, topics: [:art, :music, :books], waitlisted: true,
        character: "Junge Kunstgeschichtsstudentin, die in Museen lebt und Indie-Bands entdeckt."},

      %{name: "Johanna", last_name: "Fischer", gender: "female", age: 25, avatar: "johanna", profile: 4, topics: [:cooking, :garden, :pets],
        character: "Herzliche Tierliebhaberin, die sonntags für Freunde kocht und ihren Garten liebt."},

      %{name: "Nora", last_name: "Becker", gender: "female", age: 23, avatar: "nora", profile: 3, topics: [:books, :coffee, :art],
        character: "Philosophiestudentin mit einer Schwäche für starken Kaffee und lange Diskussionen."},

      %{name: "Vanessa", last_name: "König", gender: "female", age: 24, avatar: "vanessa", profile: 6, topics: [:music, :travel, :beach], waitlisted: true,
        character: "Reiselustige Musikliebhaberin, die auf jedem Festival neue Freunde findet."},

      %{name: "Leonie", last_name: "Neumann", gender: "female", age: 22, avatar: "leonie", profile: 7, topics: [:travel, :beach, :music],
        character: "Freigeist mit Fernweh, die am liebsten barfuß am Strand tanzt."},

      %{name: "Sophie", last_name: "Baumann", gender: "female", age: 25, avatar: "sophie", profile: 9, topics: [:sunset, :beach, :coffee],
        character: "Romantikerin, die Sonnenuntergänge am Meer sammelt und an die große Liebe glaubt."},

      %{name: "Greta", last_name: "Vogel", gender: "female", age: 23, avatar: "greta", profile: 1, topics: [:nature, :garden, :hiking],
        character: "Umweltbewusste Gartenliebhaberin, die jede Pflanze beim Namen kennt."},

      %{name: "Jasmin", last_name: "Yilmaz", gender: "female", age: 26, avatar: "jasmin", profile: 16, topics: [:coffee, :books, :yoga],
        character: "Neugierige Ingenieurin, die zwischen Code und Yogamatte ihre Balance findet."},

      %{name: "Clara", last_name: "Hoffmann", gender: "female", age: 24, avatar: "clara", profile: 9, topics: [:sunset, :cooking, :books],
        character: "Leseratte mit Hang zur Romantik, die gerne bei Kerzenlicht kocht."},

      %{name: "Katharina", last_name: "Engel", gender: "female", age: 33, avatar: "katharina", profile: 18, topics: [:coffee, :travel, :yoga], roles: [:admin],
        character: "Ehrgeizige Projektmanagerin, die geschäftlich reist und dabei immer Yoga macht."},

      %{name: "Anja", last_name: "Wolff", gender: "female", age: 25, avatar: "anja", profile: 2, topics: [:art, :music, :coffee],
        character: "Freischaffende Illustratorin, die in Kaffeehäusern zeichnet und Soul-Musik hört."},

      %{name: "Eva", last_name: "Seidel", gender: "female", age: 24, avatar: "eva", profile: 3, topics: [:books, :art, :coffee],
        character: "Nachdenkliche Literaturwissenschaftlerin, die in Antiquariaten und Galerien zu Hause ist."},

      %{name: "Birgit", last_name: "Krause", gender: "female", age: 35, avatar: "birgit", profile: 12, topics: [:cooking, :food, :coffee],
        character: "Experimentierfreudige Köchin, die internationale Rezepte sammelt und jeden Gewürzladen kennt."},

      %{name: "Lina", last_name: "Berger", gender: "female", age: 22, avatar: "lina", profile: 13, topics: [:pets, :nature, :hiking],
        character: "Angehende Tierärztin, die mit ihrem Retriever jedes Wochenende neue Wanderwege erkundet."},

      %{name: "Selina", last_name: "Roth", gender: "female", age: 24, avatar: "selina", profile: 7, topics: [:music, :travel, :art], waitlisted: true,
        character: "Bohème-Seele, die durch Europa trampt und in jedem Land ein Skizzenbuch füllt."},

      %{name: "Frieda", last_name: "Lange", gender: "female", age: 23, avatar: "frieda", profile: 1, topics: [:nature, :hiking, :yoga],
        character: "Kräuterkundige Waldgängerin, die Pilze sammelt und barfuß läuft."},

      %{name: "Amelie", last_name: "Huber", gender: "female", age: 24, avatar: "amelie", profile: 15, topics: [:yoga, :nature, :coffee],
        character: "Yogalehrerin in Ausbildung, die an die heilende Kraft der Natur glaubt."},

      %{name: "Tanja", last_name: "Schuster", gender: "female", age: 31, avatar: "tanja", profile: 11, topics: [:music, :art, :coffee],
        character: "Jazz-verliebte Grafikdesignerin, die abends in Kellerclubs verschwindet."},

      %{name: "Marie", last_name: "Werner", gender: "female", age: 23, avatar: "marie", profile: 9, topics: [:sunset, :beach, :coffee],
        character: "Träumerin, die am liebsten am Wasser sitzt und den Tag ausklingen lässt."},

      %{name: "Layla", last_name: "Khoury", gender: "female", age: 24, avatar: "layla", profile: 0, topics: [:hiking, :beach, :travel],
        character: "Abenteuerlustiges Energiebündel mit libanesischen Wurzeln und einem vollen Reisekalender."},

      %{name: "Emma", last_name: "Lorenz", gender: "female", age: 23, avatar: "emma", profile: 4, topics: [:cooking, :garden, :pets],
        character: "Gemütliche Seele, die am liebsten Kuchen backt und mit der Katze auf dem Sofa sitzt."},

      %{name: "Julia", last_name: "Meier", gender: "female", age: 26, avatar: "julia", profile: 10, topics: [:cycling, :yoga, :hiking],
        character: "Sportliche Allrounderin, die morgens Yoga macht und nachmittags Berge bezwingt."},

      %{name: "Natasha", last_name: "Petrov", gender: "female", age: 24, avatar: "natasha", profile: 14, topics: [:travel, :beach, :nature],
        character: "Russisch-deutsche Weltreisende, die jeden Urlaub in ein Mikroabenteuer verwandelt."},

      %{name: "Daniela", last_name: "Braun", gender: "female", age: 32, avatar: "daniela", profile: 11, topics: [:music, :coffee, :art], roles: [:admin],
        character: "Musikjournalistin, die Bands interviewt und nebenbei Vinyl sammelt."},

      %{name: "Kira", last_name: "Sommer", gender: "female", age: 24, avatar: "kira", profile: 0, topics: [:beach, :hiking, :nature],
        character: "Wassersport-Fan, die zwischen Surfbrett und Wanderrucksack wechselt."},

      %{name: "Aisha", last_name: "Mensah", gender: "female", age: 25, avatar: "aisha", profile: 10, topics: [:cycling, :yoga, :nature],
        character: "Disziplinierte Triathletin mit ghanaischen Wurzeln und einem unerschütterlichen Lächeln."},

      %{name: "Petra", last_name: "Zimmermann", gender: "female", age: 42, avatar: "petra", profile: 19, topics: [:cooking, :garden, :nature],
        character: "Erfahrene Gärtnerin und Hobbyköchin, die ihre Kräuter selbst anbaut."},

      %{name: "Lena", last_name: "Bergmann", gender: "female", age: 23, avatar: "lena", profile: 1, topics: [:nature, :hiking, :yoga],
        character: "Biologiestudentin, die Vogelstimmen erkennt und am liebsten draußen lernt."},

      %{name: "Carla", last_name: "Rossi", gender: "female", age: 22, avatar: "carla", profile: 6, topics: [:music, :travel, :coffee],
        character: "Italienisch temperamentvolle Studentin, die das Nachtleben und guten Espresso liebt."},

      %{name: "Anna", last_name: "Lehmann", gender: "female", age: 24, avatar: "anna", profile: 3, topics: [:books, :art, :coffee],
        character: "Stille Beobachterin, die in Bibliotheken aufblüht und kluge Gespräche liebt."},

      %{name: "Yuki", last_name: "Nakamura", gender: "female", age: 25, avatar: "yuki", profile: 12, topics: [:cooking, :food, :travel],
        character: "Japanische Köchin, die die Fusion zwischen asiatischer und europäischer Küche zelebriert."},

      %{name: "Teresa", last_name: "Keller", gender: "female", age: 24, avatar: "teresa", profile: 5, topics: [:garden, :cooking, :books],
        character: "Warmherzige Grundschullehrerin, die gerne vorliest und Marmelade einkocht."},

      %{name: "Milena", last_name: "Jovanovic", gender: "female", age: 23, avatar: "milena", profile: 15, topics: [:yoga, :nature, :coffee],
        character: "Serbisch-deutsche Achtsamkeits-Enthusiastin, die jeden Morgen mit Meditation beginnt."},

      %{name: "Franzi", last_name: "Horn", gender: "female", age: 24, avatar: "franzi", profile: 2, topics: [:art, :music, :coffee],
        character: "Spontane Straßenkünstlerin, die Graffiti sprüht und bei offenem Mikrofon singt."},

      %{name: "Pia", last_name: "Schwarz", gender: "female", age: 22, avatar: "pia", profile: 7, topics: [:music, :art, :travel],
        character: "Unkonventionelle Musikerin, die mit ihrer Ukulele durch Europa tingelt."},

      %{name: "Stella", last_name: "Köhler", gender: "female", age: 25, avatar: "stella", profile: 12, topics: [:cooking, :food, :coffee],
        character: "Konditormeisterin in der Ausbildung, die Torten als Kunstwerk betrachtet."},

      %{name: "Luisa", last_name: "Wagner", gender: "female", age: 24, avatar: "luisa", profile: 1, topics: [:nature, :hiking, :garden],
        character: "Umweltschützerin, die sich für Artenvielfalt einsetzt und im Gemeinschaftsgarten werkelt."}
    ]
  end

  # ==========================================================================
  # DISCOVERY TEST USERS (39 users calibrated against Thomas)
  # good: survive all filters, distance: filtered by proximity,
  # height: filtered by height prefs, blacklist: contact blacklisted,
  # red: hard-red trait conflicts, age: filtered by age prefs
  # ==========================================================================
  def discovery_test_users do
    [
      %{name: "Amelie", last_name: "Berger", gender: "female", age: 30, height: 168, avatar: "sabine", profile: 0, topics: [:hiking, :mountains, :nature], group: :good,
        character: "Bergliebhaberin, die am liebsten auf Gipfeln steht und den Horizont sucht."},

      %{name: "Greta", last_name: "Franke", gender: "female", age: 29, height: 170, avatar: "nina", profile: 1, topics: [:nature, :hiking, :yoga], group: :good,
        character: "Naturverbundene Yogini, die im Wald ihre Mitte findet."},

      %{name: "Hanna", last_name: "Dietrich", gender: "female", age: 32, height: 165, avatar: "mei", profile: 2, topics: [:art, :music, :books], group: :good, search_radius: 80,
        character: "Kulturbegeisterte Leserin mit Sinn für Musik und Kunst."},

      %{name: "Ida", last_name: "Engel", gender: "female", age: 28, height: 172, avatar: "claudia", profile: 3, topics: [:books, :coffee, :art], group: :good, zip_code: "56566",
        character: "Intellektuelle Kaffeeliebhaberin mit einer Galerie als zweitem Wohnzimmer."},

      %{name: "Jana", last_name: "Fuchs", gender: "female", age: 34, height: 163, avatar: "amara", profile: 4, topics: [:cooking, :garden, :pets], group: :good, zip_code: "56566", search_radius: 150,
        character: "Tierliebe Hobbygärtnerin, die am liebsten für alle kocht."},

      %{name: "Johanna", last_name: "Gerber", gender: "female", age: 31, height: 175, avatar: "ronja", profile: 5, topics: [:cooking, :garden, :yoga], group: :good, zip_code: "56566",
        character: "Achtsame Köchin, die ihre Zutaten im eigenen Garten erntet."},

      %{name: "Karla", last_name: "Haas", gender: "female", age: 30, height: 162, avatar: "hannah", profile: 6, topics: [:music, :travel, :coffee], group: :good, zip_code: "65556", search_radius: 80,
        character: "Reiselustige Partyliebhaberin mit Fernweh im Blut."},

      %{name: "Leonie", last_name: "Jaeger", gender: "female", age: 33, height: 170, avatar: "svenja", profile: 7, topics: [:travel, :beach, :music], group: :good, zip_code: "65556",
        character: "Surfbegeisterte Freigeistin, die Strand und Festivals liebt."},

      %{name: "Mia", last_name: "Kaiser", gender: "female", age: 29, height: 167, avatar: "johanna", profile: 8, topics: [:books, :coffee, :yoga], group: :good, zip_code: "53179", search_radius: 90,
        character: "Stille Denkerin, die sich in Yoga und Büchern verliert."},

      %{name: "Nora", last_name: "Lorenz", gender: "female", age: 31, height: 174, avatar: "nora", profile: 9, topics: [:sunset, :cooking, :coffee], group: :good, zip_code: "53179",
        character: "Romantische Köchin, die bei Sonnenuntergang am glücklichsten ist."},

      %{name: "Pia", last_name: "Moeller", gender: "female", age: 30, height: 168, avatar: "vanessa", profile: 10, topics: [:cycling, :hiking, :nature], group: :distance, zip_code: "55116", search_radius: 45,
        character: "Sportliche Radfahrerin, die jede Woche neue Wege entdeckt."},

      %{name: "Romy", last_name: "Naumann", gender: "female", age: 29, height: 170, avatar: "leonie", profile: 11, topics: [:music, :art, :coffee], group: :distance, zip_code: "55116", search_radius: 40,
        character: "Kreative Jazzfan, die in Galerien und Clubs lebt."},

      %{name: "Sofia", last_name: "Otto", gender: "female", age: 31, height: 166, avatar: "sophie", profile: 12, topics: [:cooking, :food, :coffee], group: :distance, zip_code: "57072", search_radius: 50,
        character: "Kulinarische Entdeckerin, die für gutes Essen Umwege fährt."},

      %{name: "Theresa", last_name: "Peters", gender: "female", age: 33, height: 172, avatar: "greta", profile: 13, topics: [:pets, :nature, :garden], group: :distance, zip_code: "57072", search_radius: 45,
        character: "Hundebesitzerin mit grünem Daumen und viel Geduld."},

      %{name: "Anja", last_name: "Reuter", gender: "female", age: 30, height: 168, avatar: "jasmin", profile: 14, topics: [:travel, :beach, :music], group: :distance, zip_code: "50667", search_radius: 50,
        character: "Strandliebhaberin, die Reisen und Musik verbindet."},

      %{name: "Bettina", last_name: "Seidel", gender: "female", age: 28, height: 165, avatar: "clara", profile: 15, topics: [:yoga, :nature, :coffee], group: :distance, zip_code: "50667", search_radius: 50,
        character: "Yoga-Praktizierende, die in der Natur ihre Kraft tankt."},

      %{name: "Carla", last_name: "Thiel", gender: "female", age: 32, height: 170, avatar: "katharina", profile: 16, topics: [:coffee, :books, :music], group: :distance, zip_code: "60311", search_radius: 50,
        character: "Wissbegierige Leserin mit einer Schwäche für Vinyl und Espresso."},

      %{name: "Dina", last_name: "Ulrich", gender: "female", age: 29, height: 167, avatar: "anja", profile: 17, topics: [:cooking, :books, :coffee], group: :distance, zip_code: "54290", search_radius: 50,
        character: "Gemütliche Leseratte, die am liebsten Rezepte aus Kochbüchern nachkocht."},

      %{name: "Edith", last_name: "Vogt", gender: "female", age: 30, height: 165, avatar: "eva", profile: 18, topics: [:coffee, :books, :travel], group: :height, search_radius: 100, partner_height_min: 195,
        character: "Karrierebewusste Reisende, die unterwegs immer ein Buch dabei hat."},

      %{name: "Frieda", last_name: "Walther", gender: "female", age: 29, height: 162, avatar: "birgit", profile: 19, topics: [:cooking, :garden, :nature], group: :height, search_radius: 100, partner_height_min: 195,
        character: "Traditionelle Gärtnerin, die alte Familienrezepte bewahrt."},

      %{name: "Georg", last_name: "Xander", gender: "male", age: 31, height: 170, avatar: "marko", profile: 0, topics: [:hiking, :mountains, :nature], group: :height, search_radius: 100, partner_height_min: 195,
        character: "Bergsteiger mit Kompass im Herzen und Fernweh in den Beinen."},

      %{name: "Hedwig", last_name: "Yildiz", gender: "female", age: 28, height: 168, avatar: "lina", profile: 1, topics: [:nature, :hiking, :yoga], group: :height, search_radius: 100, partner_height_max: 175,
        character: "Ruhige Naturfreundin, die am liebsten schweigend durch den Wald wandert."},

      %{name: "Irene", last_name: "Ziegler", gender: "female", age: 33, height: 163, avatar: "selina", profile: 2, topics: [:art, :music, :books], group: :height, search_radius: 100, partner_height_max: 175,
        character: "Kunstsinnige Musikerin, die Galerien und Konzerte gleichermaßen liebt."},

      %{name: "Jutta", last_name: "Adler", gender: "female", age: 30, height: 167, avatar: "frieda", profile: 3, topics: [:books, :coffee, :art], group: :height, search_radius: 100, partner_height_max: 175,
        character: "Belesene Ästhetin, die in Buchhandlungen und Cafés zu Hause ist."},

      %{name: "Klara", last_name: "Bach", gender: "female", age: 30, height: 168, avatar: "amelie", profile: 4, topics: [:cooking, :garden, :pets], group: :blacklist, search_radius: 100, blacklist: "dev-thomas@animina.test",
        character: "Tierliebe Köchin mit einem Herzen für Streuner und Selbstangebautes."},

      %{name: "Lotte", last_name: "Conrad", gender: "female", age: 29, height: 170, avatar: "tanja", profile: 5, topics: [:cooking, :garden, :yoga], group: :blacklist, search_radius: 100, blacklist: "dev-thomas@animina.test",
        character: "Achtsame Genießerin, die Yoga und Gärtnern als Meditation betrachtet."},

      %{name: "Magda", last_name: "Dreyer", gender: "female", age: 31, height: 165, avatar: "marie", profile: 6, topics: [:music, :travel, :coffee], group: :blacklist, search_radius: 100, blacklist: "dev-thomas@animina.test",
        character: "Lebenslustige Konzertgängerin mit Hang zu Spontanreisen."},

      %{name: "Nele", last_name: "Ebert", gender: "female", age: 28, height: 172, avatar: "layla", profile: 7, topics: [:travel, :beach, :music], group: :blacklist, search_radius: 100, blacklist: "+4915010000000",
        character: "Rastlose Reisende, die Strände und Musikfestivals sammelt."},

      %{name: "Olivia", last_name: "Fink", gender: "female", age: 33, height: 167, avatar: "emma", profile: 8, topics: [:books, :coffee, :yoga], group: :blacklist, search_radius: 100, blacklist: "+4915010000000",
        character: "Introvertierte Bücherliebhaberin mit Yoga als perfektem Ausgleich."},

      %{name: "Paula", last_name: "Graf", gender: "female", age: 30, height: 168, avatar: "julia", profile: 9, topics: [:sunset, :cooking, :coffee], group: :red, search_radius: 100, conflict_trait: {:white, "Diet", "Vegan"},
        character: "Romantische Seele, die am liebsten bei Abendrot für Freunde kocht."},

      %{name: "Renate", last_name: "Horn", gender: "female", age: 29, height: 170, avatar: "natasha", profile: 10, topics: [:cycling, :hiking, :nature], group: :red, search_radius: 100, conflict_trait: {:white, "Diet", "Vegan"},
        character: "Aktive Naturliebhaberin, die zwischen Rennrad und Wanderschuhen wechselt."},

      %{name: "Svenja", last_name: "Iske", gender: "female", age: 31, height: 165, avatar: "daniela", profile: 11, topics: [:music, :art, :coffee], group: :red, search_radius: 100, conflict_trait: {:white, "Diet", "Vegan"},
        character: "Musikbegeisterte Künstlerin, die in jedem Kaffeehaus ein Skizzenbuch aufschlägt."},

      %{name: "Thea", last_name: "Janssen", gender: "female", age: 28, height: 172, avatar: "kira", profile: 12, topics: [:cooking, :food, :coffee], group: :red, search_radius: 100, conflict_trait: {:red, "Sports", "Hiking"},
        character: "Experimentierfreudige Köchin mit einer Vorliebe für Street Food und Märkte."},

      %{name: "Ursula", last_name: "Keller", gender: "female", age: 33, height: 167, avatar: "aisha", profile: 13, topics: [:pets, :nature, :garden], group: :red, search_radius: 100, conflict_trait: {:red, "Sports", "Hiking"},
        character: "Tierfreundin, die im Garten Insektenhotels baut und Igel füttert."},

      %{name: "Veronika", last_name: "Lang", gender: "female", age: 21, height: 168, avatar: "petra", profile: 14, topics: [:travel, :beach, :music], group: :age, search_radius: 100, partner_maximum_age_offset: 2,
        character: "Junge Weltenbummlerin mit Sehnsucht nach fernen Stränden."},

      %{name: "Wiebke", last_name: "Marx", gender: "female", age: 21, height: 170, avatar: "lena", profile: 15, topics: [:yoga, :nature, :coffee], group: :age, search_radius: 100, partner_maximum_age_offset: 2,
        character: "Achtsamkeits-Studentin, die Yoga im Park und Kaffee mit Freunden liebt."},

      %{name: "Xenia", last_name: "Nowak", gender: "female", age: 21, height: 165, avatar: "carla", profile: 16, topics: [:coffee, :books, :music], group: :age, search_radius: 100, partner_maximum_age_offset: 2,
        character: "Studentin mit Kopfhörern, die zwischen Vorlesungen und Vinyl-Läden pendelt."},

      %{name: "Yvonne", last_name: "Oswald", gender: "female", age: 44, height: 167, avatar: "anna", profile: 17, topics: [:cooking, :books, :coffee], group: :age, search_radius: 100, partner_minimum_age_offset: 2,
        character: "Lebenserfahrene Köchin, die gerne bei einem Buch und Kaffee den Abend genießt."},

      %{name: "Zara", last_name: "Pohl", gender: "female", age: 44, height: 163, avatar: "yuki", profile: 18, topics: [:coffee, :books, :travel], group: :age, search_radius: 100, partner_minimum_age_offset: 2,
        character: "Weltoffene Reisende, die in jedem Land ein Lieblingscafé und eine Buchhandlung findet."}
    ]
  end
end
