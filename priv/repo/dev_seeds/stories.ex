defmodule Animina.Seeds.Stories do
  @moduledoc """
  Unique story content for development seed personas.
  Every intro and moodboard story is unique — no two personas share text.

  - `persona_intros/0` — 114 unique intro texts, keyed by persona index
  - `topic_stories/0` — 20 stories per topic for moodboard content
  - `long_stories/0` — 20 longer reflective stories
  - `topic_photos/0` — lifestyle photos mapped to topics
  """

  # ==========================================================================
  # PERSONA INTROS (114 unique, one per persona index)
  # ==========================================================================
  def persona_intros do
    %{
      # === Males (0-29) ===
      0 => "Abenteuerlust pur! Wenn ich nicht gerade wandere, plane ich die nächste Tour. Am liebsten in den Bergen, mit Zelt und Sternenhimmel. Couch-Potato? Das Gegenteil davon!",
      1 => "Musik und Fernweh — das sind meine zwei Grundnahrungsmittel. Ob auf einem Festival in Portugal oder in einem kleinen Café in Koblenz, Hauptsache der Sound stimmt.",
      2 => "Bücher, Kaffee und ein guter Podcast — mehr brauche ich eigentlich nicht. Aber jemanden, der mit mir darüber diskutiert, das wäre das Sahnehäubchen.",
      3 => "Kunst ist für mich wie Sauerstoff. Ich kann stundenlang in Galerien verschwinden und abends bei einem Espresso über Philosophie nachdenken.",
      4 => "Auf dem Rad bin ich in meinem Element. Die Natur zieht an mir vorbei und der Kopf wird endlich frei. Mein Ziel: jede Strecke an der Mosel mindestens einmal gefahren.",
      5 => "Die Welt sehen, neue Strände entdecken, barfuß laufen — ich bin ein Sonnenanbeter mit Wanderschuhen. Wenn du auch nicht stillsitzen kannst, lass uns reden.",
      6 => "Freiheit ist mein höchstes Gut. Ich surfe lieber als im Büro zu sitzen, spiele Gitarre am Strand und nehme das Leben wie es kommt. Bist du auch so ein Freigeist?",
      7 => "Skandinavische Gelassenheit trifft deutschen Ehrgeiz. Ich liebe die Stille der Berge, die Weite des Horizonts und Menschen, die wissen, wann Schweigen Gold ist.",
      8 => "Soul, Jazz und ein Espresso — mein Dreiklang der Glückseligkeit. Ich mache Musik, um zu fühlen, und höre zu, um zu verstehen.",
      9 => "Der Weg zu meinem Herzen führt durch den Magen. Ich koche leidenschaftlich, probiere jedes Restaurant und glaube, dass ein gutes Abendessen alles heilen kann.",
      10 => "Mein Garten ist mein kleines Paradies. Hier wachsen Tomaten, Kräuter und meine innere Ruhe. Wer mitgärtnern will, ist herzlich willkommen.",
      11 => "100 Kilometer auf dem Rad — das ist für mich Meditation. Russische Seele, deutscher Tatendrang, und eine Landschaft, die mich nie langweilt.",
      12 => "Zwischen Online-Kursen und Vinyl-Platten finde ich meine Balance. Ich bin neugierig auf alles, was die Welt zu bieten hat — digital und analog.",
      13 => "In meinem Garten wächst fast alles, was ich zum Kochen brauche. Dazu ein Wanderweg vor der Tür und ein Buch auf dem Nachttisch — mein perfektes Leben.",
      14 => "Musik ist meine Muttersprache. Mit westafrikanischen Rhythmen aufgewachsen, jetzt in der Kunstszene am Rhein zu Hause. Kreativität kennt keine Grenzen.",
      15 => "Strände sammeln ist mein Hobby. Von Lissabon bis Rio — überall klingt das Meer anders. Und die Musik vor Ort? Unbezahlbar.",
      16 => "Strand am Morgen, Wanderung am Nachmittag — warum muss man sich entscheiden? Ich bin entspannt, naturverliebt und immer bereit für ein Abenteuer.",
      17 => "Mein Hund Max und ich — ein unschlagbares Team. Dazu ein Garten, der uns beide glücklich macht, und eine Küche, die nach Liebe duftet.",
      18 => "Morgens Yoga am Rhein, mittags einen grünen Tee, abends ein Buch. Klingt langweilig? Für mich ist es das perfekte Leben. Achtsamkeit statt Hektik.",
      19 => "Gewürze sind meine Leidenschaft. Kreuzkümmel, Sumach, Ras el Hanout — meine Küche duftet nach der Welt. Gerne zeige ich dir meine Geheimrezepte.",
      20 => "Ich bin der Typ, der auf Festivals die Handynummern tauscht und danach auch wirklich anruft. Musik verbindet — und ich liebe diese Verbindungen.",
      21 => "Sonnenuntergänge am Deutschen Eck, dazu ein selbst gekochtes Abendessen — romantisch? Vielleicht. Aber vor allem ehrlich und von Herzen.",
      22 => "Zwischen meinem Atelier und der Buchhandlung um die Ecke liegt meine Welt. Kunst, Musik und die richtigen Worte — das bewegt mich.",
      23 => "Mein persischer Garten ist mein ganzer Stolz. Rosen, Granatäpfel und viel Geduld. Genau wie in einer guten Beziehung.",
      24 => "Tagsüber Code, abends Gitarrenklänge. Ich bin der lebende Beweis, dass Technik und Kreativität zusammengehören.",
      25 => "Zwischen Pitch-Decks und Boarding-Pässen — mein Leben ist schnell, aber ich genieße jeden Moment. Ein guter Kaffee zwingt mich zur Pause.",
      26 => "Bossa Nova im Herzen, Rheinwasser in den Adern. Ich bringe brasilianische Wärme in den deutschen Alltag — ein Lächeln zur Zeit.",
      27 => "Spontaner Roadtrip nach Amsterdam? Sofort! Ein guter Espresso in der Altstadt? Immer! Ich lebe für die ungeplanten Momente.",
      28 => "La dolce vita trifft Rheinromantik. Ich koche Pasta wie Nonna es mich gelehrt hat und genieße Sonnenuntergänge wie ein Gemälde.",
      29 => "Mit 21 habe ich mehr Fernweh als die meisten mit 40. Mein Rucksack ist immer halb gepackt, mein Herz ist immer ganz offen.",

      # === Females (30-74) ===
      30 => "Zwischen Bücherstapeln und Boarding-Pässen finde ich meinen Rhythmus. Karriere und Leidenschaft sind kein Widerspruch — sie brauchen nur die richtige Balance.",
      31 => "Sonne, Sand und Wanderwege — ich kann mich nicht entscheiden und muss es auch nicht. Das Leben ist zu kurz für Kompromisse bei schönem Wetter.",
      32 => "Aquarelle am Morgen, Jazz am Abend. Meine Welt ist bunt, leise und voller kleiner Schönheiten, die andere übersehen.",
      33 => "Im Gerichtssaal analytisch, auf der Yogamatte loslassend. Ich brauche beides — den scharfen Verstand und die innere Stille.",
      34 => "Wenn ich tanze, vergesse ich die Welt. Wenn ich reise, finde ich sie wieder. Mein Leben ist ein einziger Rhythmus — und ich suche jemanden, der mittanzt.",
      35 => "Mein Hund Oskar und ich erkunden jeden Tag ein Stückchen Natur. Wildblumen, Waldwege, frische Luft — das ist mein Element.",
      36 => "Mein Tag beginnt mit Meditation und endet mit Kräutertee. Dazwischen? Viel Natur, wenig Drama und ein Lächeln für jeden.",
      37 => "Im Wald fühle ich mich lebendiger als in jeder Stadt. Die Stille zwischen den Bäumen erzählt mir mehr als tausend Worte.",
      38 => "Museen sind meine Spielplätze, Indie-Konzerte meine Wochenenden. Ich bin jung, neugierig und immer auf der Suche nach dem nächsten Kunstmoment.",
      39 => "Sonntagmorgen: Pancakes für alle, Kater auf dem Schoß, Garten voller Kräuter. Das ist mein Bild von Glück — einfach und ehrlich.",
      40 => "Philosophie, schwarzer Kaffee und ein Notizbuch — das sind meine Werkzeuge. Ich denke nach, bevor ich rede, und rede dann am liebsten stundenlang.",
      41 => "Auf jedem Festival finde ich neue Freunde und auf jeder Reise ein neues Lieblingslied. Musik und Fernweh sind meine Superkräfte.",
      42 => "Barfuß am Strand, Wind im Haar, Freiheit im Herzen. Konventionen? Kenne ich — aber ich folge lieber meinem eigenen Rhythmus.",
      43 => "Ich sammle Sonnenuntergänge wie andere Briefmarken. Jeder ist einzigartig, jeder erzählt eine Geschichte, und am schönsten sind sie zu zweit.",
      44 => "Jede Pflanze in meinem Garten hat einen Namen. Klingt verrückt? Vielleicht. Aber so lerne ich Geduld, Fürsorge und die Schönheit des Wachsens.",
      45 => "Zwischen Codezeilen und Yogaposen finde ich meine Mitte. Technik und Achtsamkeit — das ist kein Widerspruch, das ist mein Weg.",
      46 => "Ein gutes Buch, eine Kerze und etwas Selbstgekochtes — mein perfekter Abend braucht keinen Luxus, sondern Wärme und echte Verbindung.",
      47 => "Business-Class und Yogamatte — beides passt in meinen Koffer. Ich reise viel, lerne überall und finde in der Ruhe meine Stärke.",
      48 => "Mein Skizzenbuch ist mein Tagebuch. Jeder Tag wird gezeichnet, nicht geschrieben. Und die Musik dazu kommt von meiner Soul-Playlist.",
      49 => "Antiquariate sind meine Schatzkammern. Alte Bücher riechen nach Geschichte, und in Galerien finde ich die Geschichten der Gegenwart.",
      50 => "Mein Gewürzregal hat mehr Einwohner als manche Kleinstadt. Ich koche international, experimentiere mutig und freue mich über hungrige Gäste.",
      51 => "Luna, mein Retriever, und ich — wir wandern bei jedem Wetter. Sie findet die besten Stöcke, ich finde die besten Aussichten.",
      52 => "Europa ist mein Wohnzimmer. Mit dem Zug von Stadt zu Stadt, in jedem Land ein neues Skizzenbuch — so sieht mein Glück aus.",
      53 => "Ich kenne mehr Pilzarten als Tinder-Profile. Im Wald fühle ich mich zu Hause, zwischen Moos und Farnen wird die Welt ganz einfach.",
      54 => "Yoga ist mehr als Sport — es ist meine Art zu leben. Jeden Morgen auf der Matte, jeden Abend dankbar. Die Natur gibt mir den Rest.",
      55 => "Jazz nach Mitternacht in einem Kellerclub — das ist mein Glücksmoment. Tagsüber designe ich Logos, nachts lebe ich für die Musik.",
      56 => "Am Wasser sitzend, den Sonnenuntergang beobachtend, einen Cappuccino in der Hand — das ist mein persönliches Paradies. Einfach und wunderschön.",
      57 => "Libanon im Herzen, Wanderschuhe an den Füßen. Ich liebe es, verschiedene Welten zu verbinden — auf Reisen und im echten Leben.",
      58 => "Meine Katze Mimi und ich backen Kuchen. Also, ich backe, sie beobachtet mich skeptisch. Dazu ein Garten voller Blumen — perfekt.",
      59 => "Morgens Sonnengruß, nachmittags Berggipfel, abends zufriedenes Grinsen. Sport ist meine Therapie und die Natur mein Therapeut.",
      60 => "Jede Reise ist ein Mini-Leben. Man wird geboren, man erkundet, man wächst — und dann plant man schon die nächste Reise.",
      61 => "Ich schreibe über Musik und lebe dafür. Vinyl-Schallplatten, Bandinterviews und der perfekte Espresso dazwischen — mein Traumberuf.",
      62 => "Montag: Surfen. Dienstag: Wandern. Mittwoch: Beides. Ich brauche das Wasser und die Berge — und möglichst wenig dazwischen.",
      63 => "Schwimmen, Radfahren, Laufen — Triathlon ist mein Ding. Aber nach dem Training sitze ich am liebsten still in der Natur und atme.",
      64 => "Mein Kräutergarten liefert alles, was meine Küche braucht. Rosmarin, Thymian, Basilikum — gewachsen mit Geduld und ein bisschen Liebe.",
      65 => "Morgens Vogelstimmen bestimmen, mittags im Feld studieren, abends Yoga. Biologie ist nicht mein Fach — es ist mein ganzes Leben.",
      66 => "Espresso wie in Napoli, Temperament wie in Roma, Heimat am Rhein. Ich bringe italienische Lebensfreude in den deutschen Alltag.",
      67 => "In der Bibliothek finde ich Ruhe, in klugen Gesprächen finde ich Energie. Ich bin leise, aber wenn ich etwas sage, dann mit Substanz.",
      68 => "Miso trifft Sauerkraut — in meiner Küche treffen sich Japan und Deutschland. Fusion ist nicht nur ein Kochstil, sondern mein Lebensgefühl.",
      69 => "Vorlesen, Marmelade einkochen, den Garten pflegen — klingt altmodisch? Für mich ist es zeitlos schön und voller kleiner Glücksmomente.",
      70 => "Stille ist kein Mangel, sondern Fülle. Jeden Morgen beginne ich mit Meditation, jeden Abend ende ich mit Dankbarkeit. Dazwischen: bewusstes Leben.",
      71 => "Meine Graffitis erzählen Geschichten, die keine Leinwand fassen kann. Auf der Bühne singe ich, auf der Straße male ich — Kunst überall.",
      72 => "Meine Ukulele und ich haben schon 12 Länder gesehen. Klein, laut und überall willkommen — so wie ich.",
      73 => "Torten sind meine Leinwand, Sahne mein Pinsel. Jede Kreation erzählt eine Geschichte — am liebsten eine süße.",
      74 => "Artenvielfalt fängt im eigenen Garten an. Ich pflanze Wildblumen, baue Nistkästen und wandere durch die Natur, die ich schützen will.",

      # === Discovery test users (75-113) ===
      75 => "Die Berge rufen und ich folge. Jeder Gipfel ist eine Belohnung, jeder Aufstieg eine Lektion in Geduld und Ausdauer.",
      76 => "Mein Herz schlägt für den Wald. Zwischen Farnen und Bächen finde ich die Ruhe, die ich in der Stadt vermisse.",
      77 => "Kultur ist mein Lebensmittel. Ich lese, höre Musik und besuche Ausstellungen — nicht als Hobby, sondern als Lebensart.",
      78 => "Espresso, Existentialismus und expressionistische Kunst — meine drei E. Dazu ein Notizbuch und der Tag ist perfekt.",
      79 => "Kochen für meine Lieben, den Hund streicheln, im Garten graben — mein Rezept für einen perfekten Sonntag.",
      80 => "Was ich anpflanze, landet am selben Abend im Topf. Vom Garten direkt auf den Teller — frischer und ehrlicher geht es nicht.",
      81 => "Nächster Stopp: unbekannt. Ich reise spontan, feiere gern und trinke meinen Kaffee am liebsten in Ländern, deren Sprache ich nicht spreche.",
      82 => "Salz auf der Haut, Sand zwischen den Zehen und ein Beat im Ohr — so sieht mein Sommer aus. Am liebsten das ganze Jahr.",
      83 => "Stille Morgen mit Yoga und Kaffee, Nachmittage mit einem Buch — ich brauche nicht viel, aber das Richtige.",
      84 => "Wenn die Sonne untergeht und mein Risotto fertig ist, bin ich die glücklichste Frau der Welt. Einfache Dinge, große Freude.",
      85 => "Jedes Wochenende eine neue Route, jede Woche ein neues Ziel. Mein Fahrrad und ich — wir sind unzertrennlich.",
      86 => "In Galerien verliere ich die Zeit und in Jazzclubs finde ich sie wieder. Kreativität und Koffein halten mich am Laufen.",
      87 => "Marktplätze sind meine Spielplätze. Frische Zutaten finden, nach Hause tragen, etwas Wunderbares daraus zaubern — das ist mein Ritual.",
      88 => "Mein Garten ist mein Therapiezimmer und mein Hund mein Therapeut. Zusammen sind wir das perfekte Team.",
      89 => "Koffer packen, Bikini rein, Kopfhörer auf — und los geht die Reise. Am Strand angekommen, wird erst mal eine Playlist erstellt.",
      90 => "Morgens Sonnengruß im Park, nachmittags Waldspaziergang, abends Tee. Mein Rhythmus ist langsam, aber er trägt mich weit.",
      91 => "Mein Bücherregal sortiere ich nach Stimmung, nicht nach Alphabet. Heute fühlt sich nach Jazz und Espresso an.",
      92 => "Rezepte aus Kochbüchern nachkochen und dabei einen Krimi lesen — Multitasking à la Dina. Gemütlich, aber nie langweilig.",
      93 => "In jedem Land kaufe ich ein Buch und einen Kaffee. Meine Regale und mein Herz werden bei jeder Reise voller.",
      94 => "Das Rezept meiner Großmutter für Pflaumenkuchen — das ist mein größter Schatz. Tradition bewahren heißt Liebe bewahren.",
      95 => "Bergluft, Wanderkarte, gute Laune — mehr brauche ich nicht für ein perfektes Wochenende.",
      96 => "Schweigend durch den Wald zu wandern ist für mich der beste Weg, mit mir selbst ins Gespräch zu kommen.",
      97 => "Konzerte und Galerien wechseln sich bei mir ab wie Einatmen und Ausatmen. Kunst braucht alle Sinne.",
      98 => "In alten Buchhandlungen riecht es nach Möglichkeiten. Jedes Buch könnte das nächste Lieblingsbuch sein — das hält mich wach.",
      99 => "Mein Kater Moritz und meine Tomaten bekommen die gleiche liebevolle Aufmerksamkeit. Fürsorge ist mein zweiter Vorname.",
      100 => "Zwischen Yogamatte und Gemüsebeet liegt mein ganzes Universum. Achtsam leben bedeutet, bewusst wachsen.",
      101 => "Kopfhörer auf, Rucksack um, und los. Spontane Reisen und laute Musik — das ist mein Rezept gegen Langeweile.",
      102 => "Ich zähle keine Länder, sondern Momente. Der beste war barfuß auf Bali, Reggae im Ohr und Sonne im Gesicht.",
      103 => "Mein Lieblingssport: Bücherstapel auf dem Nachttisch umschichten. Dazu Yoga für den Rücken — schließlich lese ich viel.",
      104 => "Der perfekte Abend: Sonnenuntergang, eine Prise Zimt im Kaffee und ein Gericht, das langsam und mit Liebe gekocht wurde.",
      105 => "Ob auf dem Rennrad oder zu Fuß — Hauptsache draußen, Hauptsache in Bewegung. Stillsitzen ist nicht mein Talent.",
      106 => "In jedem Kaffeehaus habe ich ein Skizzenbuch dabei. Musik inspiriert meine Zeichnungen, Koffein meinen Stift.",
      107 => "Street Food Märkte sind meine Kirche. Jeder Stand ein Altar des guten Geschmacks, jeder Bissen ein kleines Gebet.",
      108 => "Insektenhotels bauen, Igel füttern, den Garten summen lassen — mein Beitrag für eine bessere Welt fängt vor der Haustür an.",
      109 => "Mit 21 und einem Reisepass voller Stempel — ich fange gerade erst an. Die nächste Reise? Wird die beste.",
      110 => "Yoga im Park, Kaffee mit Hafer, tiefe Gespräche auf der Parkbank — mein Leben klingt wie ein Klischee, fühlt sich aber echt an.",
      111 => "Zwischen Vorlesung und Plattenladen — mein Leben als Studentin in drei Worten: Kaffee, Kopfhörer, Neugier.",
      112 => "40 Jahre Kocherfahrung stecken in jeder Mahlzeit. Ein gutes Buch dazu und der Abend ist gerettet.",
      113 => "Von Kyoto bis Kopenhagen — in jedem Land habe ich ein Lieblingscafé. Bücher und Kaffee sind die universelle Sprache."
    }
  end

  # ==========================================================================
  # TOPIC STORIES (20 per topic — enough for deterministic unique selection)
  # ==========================================================================
  def topic_stories do
    %{
      hiking: [
        "Mein Wochenende beginnt am liebsten mit Wanderschuhen und Rucksack. Die Wege entlang der Mosel und durch den Hunsrück sind meine absoluten Lieblinge.",
        "Es gibt nichts Besseres als nach einer langen Wanderung den Gipfel zu erreichen. Danach schmeckt das Bier doppelt so gut!",
        "Wandern ist für mich Meditation in Bewegung. Schritt für Schritt den Kopf frei bekommen und die Natur genießen.",
        "Letzte Woche habe ich den Rheinsteig geschafft — 320 Kilometer pures Glück. Meine Füße haben protestiert, mein Herz hat gejubelt.",
        "Der Traumpfad Eltzer Burgpanorama ist mein Favorit. Burg Eltz aus der Ferne sehen — jedes Mal Gänsehaut.",
        "Wandern mit Picknick: Käse, Brot, Trauben und eine Aussicht, die kein Restaurant der Welt toppen kann.",
        "Mein Wandertagebuch hat mittlerweile 200 Einträge. Jede Route hat eine Geschichte, jede Geschichte ein Lächeln.",
        "Bei Regen wandere ich am liebsten. Dann gehört der Wald mir allein, und die Geräusche sind wie Musik.",
        "Die Ehrbachklamm im Hunsrück — ein kleiner Canyon, den kaum jemand kennt. Mein bestgehütetes Wandergeheimnis.",
        "Wanderfreunde gesucht! Ich plane gerade eine Hüttentour durch die Alpen. Vier Tage, drei Gipfel, ein Abenteuer.",
        "Mein Hund ist der beste Wanderpartner: er beschwert sich nie über das Tempo und teilt sein Wasser.",
        "Sonnenaufgangs-Wanderungen sind mein Geheimtipp. Um 5 Uhr los, um 7 Uhr am Gipfel, unbezahlbare Stille.",
        "Wandern ist günstiger als Therapie, schöner als Fernsehen und gesünder als Schokolade. Trotzdem nehme ich Schokolade mit.",
        "Der Jakobsweg ruft mich seit Jahren. Nächsten Herbst gehe ich endlich — 800 Kilometer, nur ich und der Weg.",
        "Meine Wanderschuhe sind meine teuerste Investition und jeden Cent wert. Sie haben mich durch 15 Länder getragen.",
        "Eine Nachtwanderung bei Vollmond durch den Koblenzer Stadtwald — gruseliger als jeder Horrorfilm und schöner als jedes Kino.",
        "Ich fotografiere auf Wanderungen keine Panoramen, sondern Details: Pilze, Moose, Tautropfen auf Spinnweben.",
        "Wandern in Gesellschaft ist schön, wandern allein ist heilsam. Ich brauche beides wie Ein- und Ausatmen.",
        "Die beste Wanderapp? Meine Oma. Sie kennt jeden Pfad im Hunsrück und erzählt zu jedem eine Geschichte.",
        "Nach einer Wanderung koche ich am liebsten etwas Deftiges. Kartoffelsuppe und Bauernbrot — das hat sich der Körper verdient."
      ],
      nature: [
        "Die Natur ist mein Rückzugsort. Ein Spaziergang im Wald reicht, um meinen Akku komplett aufzuladen.",
        "Sonntags bin ich am liebsten draußen — ob am Rhein, im Wald oder in einem Park mit einem guten Buch.",
        "Die kleinen Wunder der Natur faszinieren mich: der erste Frost, raschelnde Blätter, ein Sternenhimmel ohne Lichtverschmutzung.",
        "Morgens um sechs am Rheinufer — die Nebelschwaden über dem Wasser und absolute Stille. Mein tägliches Geschenk an mich.",
        "Mein Lieblingsplatz: eine Baumwurzel am Laacher See, wo ich stundenlang ins Wasser starren kann.",
        "Die Geysire in der Eifel beweisen, dass Abenteuer direkt vor der Haustür liegen. Man muss nur hinsehen.",
        "Vogelstimmen zu erkennen habe ich als Kind gelernt. Heute ist es mein Morgenritual — besser als jede Nachrichten-App.",
        "Im Frühling explodiert die Natur förmlich. Ich verbringe dann jede freie Minute draußen und sauge alles auf.",
        "Ein Picknick am Flussufer, barfuß im Gras — manchmal reichen die einfachsten Dinge für die größte Freude.",
        "Naturschutz ist für mich kein Trend, sondern Verantwortung. Ich sammle Müll beim Spazierengehen, weil es mir wichtig ist.",
        "Mein Fenster bleibt immer offen — ich brauche frische Luft wie andere ihren Morgenkaffee.",
        "Der Westerwald im Herbst: goldene Blätter, kühle Luft und dieser Geruch nach Erde und Pilzen. Perfektion.",
        "Gewitter beobachten fasziniert mich seit der Kindheit. Die Kraft der Natur ist demütigend und wunderschön zugleich.",
        "Mein Traum: einmal die Polarlichter sehen. Bis dahin tröste ich mich mit rheinischen Sonnenuntergängen.",
        "Barfuß durch taunasses Gras am Morgen — manche nennen es verrückt, ich nenne es den besten Start in den Tag.",
        "Die Moselschleifen von oben gesehen — eine der schönsten Landschaften, die ich kenne. Und ich kenne einige.",
        "Stundenlang Wolken beobachten und Geschichten darin erkennen — das konnte ich als Kind und kann es heute noch.",
        "Mein Lieblingsbaum steht in einem Park in Koblenz. Eine alte Eiche, mindestens 200 Jahre alt. Sie hat schon alles gesehen.",
        "Naturfilme schaue ich wie andere Krimis — mit Spannung, Staunen und manchmal Tränen. David Attenborough ist mein Held.",
        "Jede Jahreszeit hat ihre Magie. Aber der Moment, wenn der erste Schnee fällt und die Welt leise wird — unschlagbar."
      ],
      yoga: [
        "Yoga hat mein Leben verändert. Nicht nur körperlich, sondern auch mental. 15 Minuten am Morgen und der Tag kann kommen.",
        "Anfangs fand ich Yoga langweilig — heute ist es das Highlight meines Tages. Manchmal muss man sich eben auf Neues einlassen.",
        "Namaste am Rheinufer — meine Yogamatte und der Sonnenaufgang, das ist mein Morgenritual.",
        "Yoga ist kein Wettbewerb. Mein Kopfstand wackelt noch, aber meine innere Ruhe ist stabil wie nie.",
        "Yin Yoga am Abend — langsam, tief, heilsam. Danach schlafe ich wie ein Baby.",
        "Mein erster Yoga-Retreat war in Portugal. Eine Woche Stille, Sonne und Selbstfindung. Lebensverändernd.",
        "Pranayama — Atemübungen klingen langweilig, sind aber die kraftvollste Übung. Drei Minuten und der Stress ist weg.",
        "Yoga auf dem SUP-Board — instabil, lustig und erstaunlich meditativ. Einmal reingefallen, trotzdem weiter gemacht.",
        "Mein Yogalehrer sagt: Flexibilität beginnt im Kopf. Er hat recht — bei allem.",
        "Ashtanga-Yoga um 6 Uhr morgens: hart, schwitzend, fordernd. Danach fühle ich mich unbesiegbar.",
        "Yoga im Park mit Freunden ist mein Sonntagsritual. Danach Brunch — die beste Kombination der Welt.",
        "Nach einer stressigen Arbeitswoche brauche ich eine Stunde auf der Matte. Billiger als jeder Therapeut.",
        "Meine Yogamatte war in 8 Ländern dabei. Sie ist mein treuster Reisebegleiter — kompakt und immer bereit.",
        "Meditation fiel mir anfangs schwer. 10 Sekunden Stille, dann schon wieder Gedanken. Heute schaffe ich 10 Minuten.",
        "Yoga hat mir gezeigt, dass Stärke nicht laut sein muss. Die stärksten Menschen, die ich kenne, sind ganz ruhig.",
        "Savasana ist meine Lieblingsposition. Einfach liegen, loslassen, sein. So simpel und so schwer zugleich.",
        "Yoga-Philosophie fasziniert mich genauso wie die Praxis. Die Yamas und Niyamas — alte Weisheiten, modern relevant.",
        "Partner-Yoga ausprobiert — anfangs peinlich, am Ende berührend. Vertrauen lernen auf ganz neue Weise.",
        "Mein Ziel ist der Handstand bis Ende des Jahres. Nicht wegen Instagram, sondern weil ich es mir beweisen will.",
        "Yoga-Nidra, der yogische Schlaf: 30 Minuten liegen fühlen sich an wie 3 Stunden. Mein Geheimtipp gegen Erschöpfung."
      ],
      cooking: [
        "Kochen ist meine Art, Liebe zu zeigen. Am liebsten für Freunde, mit guter Musik und einem Glas Wein in der Hand.",
        "Mein Risotto ist legendär — zumindest sagen das meine Freunde. Übung macht den Meister, und ich habe viel geübt!",
        "Sonntags ist Kochabend. Dann wird experimentiert, ausprobiert und manchmal auch bestellt, wenn es schiefgeht.",
        "Saisonale Küche fasziniert mich. Was gerade wächst, kommt auf den Teller. Im Winter: Kürbis und Wurzelgemüse, im Sommer: Tomaten und Basilikum.",
        "Mein Sauerteig hat einen Namen: Herbert. Er ist drei Jahre alt und das Herzstück meiner Brotback-Leidenschaft.",
        "Indisch kochen habe ich in einem Kurs in Kerala gelernt. Seitdem riechen meine Schränke nach Kardamom und Kurkuma.",
        "Meal Prep Sonntag: fünf Mahlzeiten für die Woche in drei Stunden. Klingt nach Arbeit, ist aber pure Entspannung.",
        "Meine Oma hat mir beigebracht, dass man mit Liebe würzt. Das Rezept für ihren Kartoffelsalat gebe ich nie her.",
        "Fermentieren ist mein neues Hobby. Kimchi, Kombucha, Sauerkraut — meine Küche sieht aus wie ein Labor.",
        "Der beste Kochmoment: wenn Freunde am Tisch sitzen, den ersten Bissen nehmen und die Augen schließen.",
        "Pasta mache ich von Hand. Mehl, Eier, Nudelmaschine — das Ergebnis ist jedes Mal anders und jedes Mal gut.",
        "Gewürze sind meine Leidenschaft. Letztens habe ich Za'atar selbst gemischt — das Ergebnis war eine Offenbarung.",
        "Mein Kühlschrank ist ein Abenteuerspielplatz. Resteessen ist die kreativste Form des Kochens.",
        "Kochshows schaue ich zum Einschlafen. Nicht weil sie langweilig sind, sondern weil sie mich entspannen.",
        "Das perfekte Steak: 3 Minuten pro Seite, Rosmarin, Knoblauch, Butter. Simpel, aber die Technik muss stimmen.",
        "Suppen sind unterschätzt. Eine gute Ramen braucht 12 Stunden — aber das Warten lohnt sich immer.",
        "Mein Traum: einmal in einem japanischen Ryokan kochen lernen. Kaiseki — die Kunst der kleinen Gerichte.",
        "Freitagabend ist Pizzaabend. Eigener Teig, eigene Sauce, und jeder belegt seine Pizza selbst.",
        "Kochbücher sammle ich wie andere Schuhe. Ottolenghi, Ducasse, Salt Fat Acid Heat — meine Bibeln.",
        "Das größte Kompliment: Wenn jemand mein Rezept nachkocht und mir ein Foto schickt. Dann weiß ich, es war gut."
      ],
      food: [
        "Neue Restaurants entdecken ist mein liebstes Hobby. Mein aktueller Favorit: ein kleines libanesisches Lokal in der Altstadt.",
        "Street Food Märkte sind mein Happy Place. Einmal um die Welt essen, ohne den Rhein zu verlassen!",
        "Gutes Essen muss nicht teuer sein. Die besten Gerichte sind die, die mit Leidenschaft und Liebe zubereitet werden.",
        "Mein Food-Blog hat 50 Follower — alles Freunde. Aber die Fotos werden immer besser!",
        "Die beste Currywurst gibt es am Imbiss an der Ecke, nicht im fancy Restaurant. Manche Dinge sind einfach perfekt.",
        "Dim Sum am Sonntagmorgen — wer das noch nicht probiert hat, kennt kein wahres Brunch-Glück.",
        "Ein Gericht, das mich verfolgt: Khao Soi in einem Straßenrestaurant in Chiang Mai. Seitdem suche ich den Geschmack.",
        "Ramen-Tour durch Koblenz: ja, das gibt es. Drei Restaurants, drei Stile, ein glücklicher Magen.",
        "Märkte in Südfrankreich — der Duft von Lavendel, Käse und frischem Brot. Meine Nase reist immer mit.",
        "Essen ist Kultur. Ein Land verstehen heißt, sein Essen verstehen. Deshalb esse ich mich durch die Welt.",
        "Mein Lieblingsfrühstück: Shakshuka. Eier in Tomatensauce, frisches Brot, schwarzer Kaffee. Orientalisches Glück.",
        "Food-Festivals sind mein Urlaubsersatz. Letztes Wochenende: thailändisch, mexikanisch, äthiopisch — ohne den Rhein zu verlassen.",
        "Die beste Pizza meines Lebens: Neapel, ein kleiner Laden, Margherita für 4 Euro. Unerreicht.",
        "Tapas-Abende mit Freunden — jeder bringt etwas mit, keiner weiß was die anderen bringen. Das Chaos ist Teil des Genusses.",
        "Mein Traum: einen eigenen kleinen Food-Truck. Fusion-Küche, fairer Preis, happy People.",
        "Geschmacksexplosionen suche ich überall. Letztens: schwarzer Knoblauch auf Vanilleeis. Klingt verrückt, war genial.",
        "Ein guter Wein, ein reifer Käse, frisches Baguette — manchmal ist weniger einfach mehr.",
        "Sushi selber rollen: dauert Stunden, schmeckt mittelmäßig, macht trotzdem Riesenspaß. Der Weg ist das Ziel.",
        "Mein Lieblingsgericht meiner Mutter: Linsensuppe. Jedes Mal, wenn ich sie koche, bin ich wieder zu Hause.",
        "Die Markthalle in Koblenz — ein Paradies für Feinschmecker. Ich gehe jeden Samstag und komme nie mit leeren Händen."
      ],
      beach: [
        "Meeresrauschen, Sand zwischen den Zehen und ein gutes Buch — das ist mein Paradies.",
        "Ich träume schon wieder vom nächsten Strandurlaub. Kroatien? Griechenland? Hauptsache Sonne und Meer!",
        "Am Strand vergesse ich alles um mich herum. Da bin ich ganz bei mir — und das ist unbezahlbar.",
        "Muscheln sammeln am Nordseestrand — ein Kindheitshobby, das ich nie abgelegt habe. Jede Muschel erzählt eine Geschichte.",
        "Der beste Strand Europas? Für mich: Praia da Marinha an der Algarve. Goldene Felsen, türkises Wasser, paradiesisch.",
        "Strandvolleyball spielen bis die Sonne untergeht — Sport, Sonne und Lachen in perfekter Kombination.",
        "Mein Reiseführer ist simpel: wo ist das nächste Meer? Egal ob Ostsee oder Mittelmeer — Wasser macht mich glücklich.",
        "Frühmorgens allein am Strand — die Spuren im Sand sind nur meine. Diese Stille hat eine besondere Magie.",
        "Strandcafés sind meine Büros. Laptop, Latte, Meerblick — produktiver war ich nie.",
        "Schnorcheln hat mir eine neue Welt gezeigt. Unter Wasser ist alles bunt, still und wunderschön.",
        "Der Geruch von Salzwasser und Sonnencreme — mein persönlicher Duft des Glücks seit Kindertagen.",
        "Am Strand lese ich Bücher, die ich sonst nie lesen würde. Das Meer macht mich offener für Neues.",
        "Surfstunden auf Fuerteventura: dreimal reingefallen, einmal gestanden, hundertmal gelacht. Perfekter Tag.",
        "Ein Sonnenuntergang am Meer ist nie gleich. Ich habe Hunderte gesehen und staune jedes Mal neu.",
        "Mein Strandequipment: Hängematte, Bluetooth-Lautsprecher, Wassermelone. Alles andere ist optional.",
        "Die Ostsee im Winter — leer, kalt und wunderschön. Eingepackt in Schal und Mütze am Wasser entlang gehen.",
        "Sandburgen bauen mit Freundinnen. Wir sind über 20 und es macht immer noch Spaß. Wer baut mit?",
        "Kajakfahren an der Küste: Seehunde beobachten, Wellen reiten und sich frei fühlen wie ein Fisch.",
        "Mein liebstes Strandspiel: Steine übers Wasser hüpfen lassen. Mein Rekord: 7 Hüpfer. Herausforderung angenommen?",
        "Ein Lagerfeuer am Strand, Gitarrenklänge und Sterne — manche Abende möchte ich für immer festhalten."
      ],
      travel: [
        "Reisen ist die beste Bildung. Jede Reise hat mich als Mensch verändert und meinen Horizont erweitert.",
        "Mein Koffer ist halb gepackt und mein Reisepass liegt immer griffbereit. Spontane Trips sind die allerbesten!",
        "Von Lissabon bis Tokyo — jede Stadt hat ihre eigene Seele. Am liebsten erkunde ich Städte zu Fuß.",
        "Nachtzüge sind unterschätzt. Einschlafen in Berlin, aufwachen in Wien — die romantischste Art zu reisen.",
        "Couchsurfing hat mir gezeigt, dass Fremde die besten Geschichtenerzähler sind. Jeder Gastgeber ein Abenteuer.",
        "Meine Reiseregel Nummer 1: kein Plan ist der beste Plan. Die besten Erlebnisse passieren ungeplant.",
        "Drei Monate Südostasien — das hat meine Perspektive auf alles verändert. Weniger haben, mehr sein.",
        "Reisen ist auch das Gepäck reduzieren. Mittlerweile passt alles in einen Rucksack. Befreiend!",
        "Mein Lieblingsreisemoment: in einer fremden Stadt aufwachen und nicht wissen, was der Tag bringt.",
        "Lokale Märkte besuche ich in jedem Land zuerst. Dort lernt man mehr über eine Kultur als in jedem Museum.",
        "Porto im Regen ist genauso schön wie Porto in der Sonne. Vielleicht sogar schöner — weniger Touristen.",
        "Reisefotografie hat mir beigebracht, genau hinzusehen. Jetzt entdecke ich auch zu Hause täglich Neues.",
        "Alleine reisen war die beste Entscheidung meines Lebens. Man lernt, sich selbst zu vertrauen.",
        "Mein Reisetagebuch hat schon Band 7 erreicht. Jede Seite riecht nach einem anderen Land.",
        "Die Transsib von Moskau nach Wladiwostok — 9.000 Kilometer, 7 Tage Zugfahrt. Steht ganz oben auf meiner Liste.",
        "Einmal in Marrakesch verlaufen, eine Stunde lang die falschen Gassen genommen — und den besten Tee meines Lebens gefunden.",
        "Reisen mit dem Van: Freiheit auf vier Rädern. Aufwachen, Tür auf, neuer Ort. So einfach, so schön.",
        "Mein Lieblingssouvenir: lokale Gewürze. Meine Küche riecht nach allen Ländern, die ich besucht habe.",
        "Workation auf Madeira: morgens arbeiten, nachmittags wandern, abends Poncha trinken. Das perfekte Leben.",
        "Jede Reise lehrt mich Demut. Die Welt ist so groß und ich bin so klein — und genau das ist befreiend."
      ],
      coffee: [
        "Ohne meinen Morgenkaffee geht gar nichts. Aber bitte richtig — frisch gemahlen, nicht aus der Kapselmaschine.",
        "Mein Lieblingsplatz: ein kleines Café um die Ecke, wo die Barista meinen Namen kennt.",
        "Kaffee trinken ist ein Ritual, eine Pause, ein Moment nur für mich. Am liebsten mit einem guten Gespräch.",
        "Third Wave Coffee hat mein Leben verändert. Seitdem schmecke ich Blaubeeren und Karamell in meinem Espresso.",
        "Meine French Press und ich — eine Liebesgeschichte. Morgens vier Minuten warten macht den Unterschied.",
        "Das beste Café in Koblenz? Verrate ich nur persönlich. Man muss sich manche Geheimnisse schließlich verdienen.",
        "Kaffee und ein gutes Buch — eine Kombination, die mich durch jede Krise bringt.",
        "Ich habe in 20 Ländern Kaffee getrunken und kann sagen: türkischer Kaffee ist ein Erlebnis für sich.",
        "Latte Art fasziniert mich. Mein bestes Herz sieht noch aus wie ein Klecks, aber ich übe weiter.",
        "Kalter Kaffee im Sommer, heißer Kaffee im Winter — manche Gewohnheiten ändern sich nie.",
        "Mein Kaffeekonsum ist definitiv zu hoch. Aber solange die Tasse schön ist, zählt es als Selbstfürsorge.",
        "Äthiopischer Yirgacheffe — der Champagner unter den Kaffeebohnen. Einmal probiert, nie wieder vergessen.",
        "Sonntags mahle ich Bohnen von Hand. Das Geräusch der Mühle ist mein Wecker für die Seele.",
        "Kaffeedates sind die besten Dates. Kurz genug um zu flüchten, lang genug um sich zu verlieben.",
        "Meine Reisen plane ich um Cafés herum. Erst die besten Röstereien googeln, dann die Sehenswürdigkeiten.",
        "Der Geruch von frisch geröstetem Kaffee — wenn ich das in einer Straße rieche, muss ich rein.",
        "Espresso nach dem Essen ist nicht verhandelbar. So habe ich es in Italien gelernt, so mache ich es hier.",
        "Mein Home-Office wird vom Kaffeegeruch zusammengehalten. Ohne wäre es nur ein Schreibtisch mit WLAN.",
        "Flat White — der perfekte Kompromiss zwischen Cappuccino und Latte. Meine tägliche Entdeckung des letzten Jahres.",
        "In meiner Küche stehen vier verschiedene Kaffeezubereiter. Nennt mich besessen — ich nenne es Leidenschaft."
      ],
      books: [
        "Mein Nachttisch biegt sich unter dem Gewicht meiner Bücherstapel. Ich lese meistens drei Bücher gleichzeitig.",
        "Ein gutes Buch ist wie ein guter Freund — es versteht dich, auch wenn du kein Wort sagst.",
        "Buchladen statt Amazon — ich liebe es, in Regalen zu stöbern und Schätze zu entdecken.",
        "Haruki Murakami hat mein Lesen verändert. Seitdem akzeptiere ich, dass nicht alles einen Sinn haben muss.",
        "Mein Bücherregal ist nach Farben sortiert. Sieht schön aus, finden ist schwer — aber es macht mich glücklich.",
        "Hörbücher beim Spazierengehen — die perfekte Kombination aus Bewegung und Geschichte.",
        "Lesekreis am Donnerstag: Wir diskutieren, streiten und lachen. Die besten Gespräche meiner Woche.",
        "Ich habe mir vorgenommen, dieses Jahr 50 Bücher zu lesen. Stand jetzt: 23. Ich gebe nicht auf.",
        "Second-Hand-Bücher haben eine Seele. Manchmal finde ich Notizen darin — kleine Botschaften von Fremden.",
        "Mein Lieblingsbuch wechselt ständig. Gerade: Piranesi von Susanna Clarke. Magisch und rätselhaft.",
        "Vorlesen macht mich glücklich. Ob für Kinder oder für Erwachsene — Geschichten teilen ist das Schönste.",
        "Die Stadtbibliothek ist mein zweites Wohnzimmer. Leise, warm und voller Möglichkeiten.",
        "Sachbücher am Morgen, Romane am Abend — mein Leseplan hat System. Oder zumindest den Anschein davon.",
        "Bücher verschenken ist meine Sprache der Liebe. Wer von mir ein Buch bekommt, bekommt ein Stück von mir.",
        "Der Geruch neuer Bücher und alter Antiquariate — zwei verschiedene Welten, beide wunderbar.",
        "Mein Kindle und ich haben eine Hassliebe. Praktisch für unterwegs, aber nichts ersetzt echtes Papier.",
        "Literarische Spaziergänge durch Koblenz: Orte besuchen, die in Büchern vorkommen. Nischig, aber wunderbar.",
        "Ich kann kein Buch unfertig weglegen. Selbst wenn es schlecht ist, muss ich wissen, wie es endet.",
        "Mein Traum: ein eigenes Lesezimmer mit Kamin, Sessel und deckenhohen Regalen. Der Kamin ist verhandelbar, die Regale nicht.",
        "Büchertausch im Park — mein monatliches Highlight. Man gibt eins, bekommt eins, und trifft Gleichgesinnte."
      ],
      music: [
        "Musik begleitet mich überall. Ob auf dem Rad, beim Kochen oder unter der Dusche — ohne Playlist läuft nichts.",
        "Live-Konzerte sind das Beste. Diese Energie, wenn tausend Menschen den gleichen Song singen!",
        "Ich spiele seit meiner Kindheit Gitarre. Nichts ist entspannender als abends ein paar Akkorde zu klimpern.",
        "Vinyl sammeln ist mein teures Hobby. Aber wenn die Nadel aufsetzt und es knackt, ist alles vergessen.",
        "Open Mic Night — jeder kann auf die Bühne. Die Nervosität vorher und das Hochgefühl nachher sind unbezahlbar.",
        "Meine Playlist hat über 2000 Songs und wächst täglich. Von Jazz bis Punk, von Klassik bis Afrobeat.",
        "Musik verbindet Kulturen. Ein Song aus Mali, ein Beat aus Korea — plötzlich fühlt sich die Welt kleiner an.",
        "Festivalsommer ist die beste Jahreszeit. Zelte, Matsch und Livemusik — ich würde nichts tauschen.",
        "Mein erstes Konzert war mit 14: Tote Hosen in Düsseldorf. Seitdem bin ich süchtig nach Livemusik.",
        "Schlagzeug lernen mit 30 — meine Nachbarn hassen mich, aber mein Rhythmusgefühl dankt es mir.",
        "Die beste Musik entsteht nachts. Wenn die Stadt schläft, kommen die besten Melodien.",
        "Spotify Wrapped sagt: 40.000 Minuten gehört. Das sind 27 Tage Musik. Gut investierte Zeit.",
        "Jazz im Kerzenlicht — intim, roh und echt. Keine Technik, nur Können und Gefühl.",
        "Ich kann zu jedem Lebensereignis den passenden Song nennen. Mein Gedächtnis funktioniert über Musik.",
        "Straßenmusiker bekommen immer einen Euro von mir. Wer den Mut hat, verdient Unterstützung.",
        "Klavier und Regen passen zusammen wie Kaffee und Morgen. Meine liebste Hintergrundmusik zum Arbeiten.",
        "Alte Kassetten meiner Eltern durchhören — Beatles, Stones, Bowie. Die beste Musikerziehung der Welt.",
        "Musiktheorie ist Mathematik für die Seele. Seit ich Harmonielehre verstehe, höre ich Lieder ganz anders.",
        "Karaoke ist mein guilty pleasure. Ich singe schlecht, aber laut und mit vollem Herzen.",
        "Mein Traum: einmal im Jazzclub Blue Note in New York sitzen. Bis dahin übe ich in der Koblenzer Kellerbar."
      ],
      art: [
        "Kunst ist mein Ventil. Ob mit Pinsel, Kamera oder Stift — kreativ sein hält mich lebendig.",
        "Museen und Galerien sind meine Lieblingsorte. Ich kann stundenlang vor einem Bild stehen und mich darin verlieren.",
        "Kreativität braucht keine Perfektion. Die schönsten Dinge entstehen spontan und aus dem Herzen.",
        "Mein Skizzenbuch ist immer dabei. Im Café, in der Bahn, im Park — überall gibt es etwas zu zeichnen.",
        "Aquarelle malen am Rhein — das Licht, das Wasser, die Farben. Manchmal malt die Natur mit.",
        "Streetart-Tour durch Ehrenbreitstein — Kunst an Häuserwänden erzählt die Geschichten eines Viertels.",
        "Fotografie hat mir beigebracht, Momente festzuhalten. Nicht für Instagram, sondern für die Erinnerung.",
        "Töpferkurs am Wochenende: Meine Tasse ist schief, aber ich habe sie selbst gemacht. Das zählt!",
        "Kunst kaufen von lokalen Künstlern — besser als jeder IKEA-Druck und mit einer Geschichte dahinter.",
        "Abstrakte Kunst verstehen? Muss man nicht. Fühlen reicht. Und wenn nichts kommt, war es vielleicht einfach nicht dein Bild.",
        "Collagen aus alten Zeitschriften kleben — mein Ausgleich nach langen Arbeitstagen. Schere, Kleber, Chaos.",
        "Die Dokumenta in Kassel hat meine Sicht auf Kunst gesprengt. Seitdem finde ich Kunst überall.",
        "Kalligrafie üben: langsam, bedacht, meditativ. Jeder Strich ist eine kleine Übung in Geduld.",
        "Mein liebster Künstler: Gerhard Richter. Die Art, wie er zwischen Abstraktion und Realismus wechselt — faszinierend.",
        "Art Journaling — Tagebuch schreiben mit Bildern, Farben und Collagen. Meine Seiten sind bunt und ehrlich.",
        "Skulpturengärten besuchen: Kunst, die man anfassen und umrunden kann. Dreidimensionale Schönheit.",
        "Meine Wände sind voller selbstgemalter Bilder. Kein Meisterwerk darunter, aber jedes voller Erinnerung.",
        "Kunstworkshops geben und nehmen — beides bringt mir gleich viel. Kreativität wächst, wenn man sie teilt.",
        "Linoldruck wiederentdeckt: Old School, händisch und mit dem befriedigenden Moment des Abziehens.",
        "Museumssonntage mit Freunden — danach im Café diskutieren, was uns gefallen hat. Kultur als Gemeinschaftserlebnis."
      ],
      garden: [
        "Mein Garten ist mein kleines Paradies. Selbst angebaute Tomaten schmecken hundertmal besser als aus dem Supermarkt.",
        "Gartenarbeit erdet mich — im wahrsten Sinne des Wortes. Hände in der Erde, Sonne im Gesicht, das reicht mir.",
        "Dieses Jahr habe ich zum ersten Mal Chilis angebaut. 47 Pflanzen! Es ist etwas eskaliert.",
        "Mein Kräuterbeet ist mein ganzer Stolz: Rosmarin, Thymian, Salbei, Minze — alles frisch, alles bio.",
        "Hochbeete gebaut, Kompost angelegt, Regenwasser gesammelt — mein Garten ist ein kleines Ökosystem.",
        "Erdbeeren aus dem eigenen Garten, warm von der Sonne — das schmeckt nach Kindheit und Sommer.",
        "Mein Nachbar und ich tauschen Gemüse. Er baut Zucchini an, ich Bohnen. Nachbarschaftshilfe der besten Art.",
        "Im Herbst pflanze ich Tulpenzwiebeln und im Frühling freue ich mich wie ein Kind über die Blüten.",
        "Bienenfreundlich gärtnern ist mir wichtig. Lavendel, Sonnenhut und Klee — mein Garten summt und brummt.",
        "Mein Balkon ist 3 Quadratmeter groß und trotzdem wachsen dort 12 Sorten Kräuter. Platz ist eine Frage der Kreativität.",
        "Gartenplanung im Winter: Saatgutkataloge wälzen und von Sommer träumen. Meine liebste Beschäftigung im Januar.",
        "Kompost ist Gold für den Garten. Mein Komposthaufen ist mein stiller Held — aus Abfall wird Leben.",
        "Obstbäume pflanzen: Geduld ist Voraussetzung. Mein Apfelbaum trägt seit drei Jahren und jedes Jahr mehr.",
        "Gemeinschaftsgarten im Viertel: Zusammen säen, gießen, ernten. So entstehen echte Nachbarschaften.",
        "Mein Gewächshaus im Miniformat: ein alter Fensterrahmen über einem Beet. DIY und trotzdem funktioniert es!",
        "Schnecken sind mein Erzfeind. Aber Bierfallen statt Gift — auch im Garten hat man Prinzipien.",
        "Sonnenblumen am Zaun — die einfachste Art, jedem Passanten ein Lächeln zu schenken.",
        "Mein Wintergarten ist mein Rückzugsort. Pflanzen überall, warmes Licht und der Geruch von feuchter Erde.",
        "Samenbomben werfen: Guerilla Gardening für Anfänger. Mein Beitrag zur Verschönerung der Nachbarschaft.",
        "Die erste eigene Ernte — drei Radieschen, etwas schief, etwas klein, aber der Stolz war riesig."
      ],
      cycling: [
        "Auf dem Fahrrad bin ich frei. Die Moselradwege sind mein Wohnzimmer — nur mit besserer Aussicht.",
        "100 km am Wochenende sind mein Ziel. Nicht immer schaffe ich es, aber der Weg ist das Ziel!",
        "Fahrrad statt Auto — nicht nur für die Umwelt, sondern auch für mich. Die beste Art, den Tag zu starten.",
        "Mein Rennrad und ich — 8000 Kilometer im Jahr, eine unschlagbare Partnerschaft.",
        "Radfahren entlang der Mosel bei Sonnenaufgang: goldenes Licht auf dem Wasser und kein Auto weit und breit.",
        "Gravelbike entdeckt — zwischen Straße und Trail, zwischen Ordnung und Abenteuer. Perfekt für mich.",
        "Die Tour de Rhin — mein selbst organisiertes Radrennen mit Freunden. Kein Preisgeld, aber unendlich viel Spaß.",
        "Winterradeln ist Charakterbildung. Handschuhe, Stirnlampe und trotzdem ein Grinsen im Gesicht.",
        "Fahrradreise durch die Niederlande: flach, grün und mit einem Frikandel an jeder Ecke. Paradiesisch.",
        "Mein altes Stahlrad: 15 Kilo, null Federung, aber jeder Kilometer fühlt sich ehrlich an.",
        "Radfahren ist mein Meditationsersatz. Treten, atmen, schauen — der Kopf wird frei wie der Horizont.",
        "Mein Traum: eine Radtour von Koblenz nach Barcelona. 2000 Kilometer, vier Wochen, ein Zelt.",
        "Radwege in Deutschland sind besser als ihr Ruf. Man muss nur wissen, wo die Schätze liegen.",
        "Pannenhilfe am Straßenrand — mein Flickzeug hat schon drei Fremden geholfen. Karma auf zwei Rädern.",
        "Mountainbike im Hunsrück: Trails, Matsch und Adrenalinstöße. Danach ein Apfelschorle an der Hütte.",
        "Bike-to-Work: 15 Kilometer einfach, bei jedem Wetter. Meine Kollegen halten mich für verrückt.",
        "E-Bike? Noch nicht. Aber ich respektiere jeden, der damit fährt. Hauptsache auf dem Rad.",
        "Radfahren mit Podcast im Ohr — zwei Leidenschaften gleichzeitig. Multitasking der besten Sorte.",
        "Mein Lieblingshügel: die Straße nach Ehrenbreitstein. Hochtreten ist Qual, runter rollen ist Extase.",
        "Fahrradkette selbst wechseln lernen war ein Meilenstein. Unabhängigkeit hat einen öligen Preis."
      ],
      pets: [
        "Mein Hund ist mein bester Freund. Gemeinsam erkunden wir jeden Tag neue Wege — er bestimmt die Route.",
        "Katzenmensch durch und durch. Abends kuscheln, während sie mich souverän ignoriert — das ist wahre Liebe.",
        "Tiere verstehen dich ohne Worte. Deswegen ist mein Zuhause nie ohne vierbeinige Mitbewohner.",
        "Mein Hund Balu bringt mir jeden Tag einen Schuh. Nicht meinen, sondern irgendeinen. Sein Humor ist speziell.",
        "Katze adoptiert: Sie war scheu, jetzt liegt sie auf meinem Laptop. Fortschritt sieht bei jedem anders aus.",
        "Tierheim-Spaziergänge am Samstag — die Hunde gehen Gassi und ich bekomme mein Herz gebrochen. Jedes Mal.",
        "Meine Katzen heißen Kafka und Keats. Literarisch inspiriert und genauso eigenartig wie ihre Namensgeber.",
        "Hundetraining ist eigentlich Menschentraining. Ich habe mehr über Geduld gelernt als in jedem Seminar.",
        "Mein Aquarium ist mein Zen-Garten. 30 Minuten den Fischen zusehen ersetzt jede Meditation.",
        "Mit dem Hund am Rheinufer: er springt rein, ich seufze, er schüttelt sich, ich bin nass. Jeden Tag aufs Neue.",
        "Haustiere machen das Home Office erträglicher. Katze auf der Tastatur = Zwangspause. Gesund!",
        "Mein Hund ist der Grund, warum ich morgens um 6 Uhr draußen bin. Und ehrlich: ich bin ihm dankbar dafür.",
        "Vogelfüttern im Winter: Meisen, Rotkehlchen, Spatzen. Mein Balkon ist der beste Platz in der Nachbarschaft.",
        "Pfötchenabdruck als Tattoo — vielleicht übertrieben, aber mein Hund ist eben mein Seelenpartner.",
        "Hundecafé entdeckt: Kuchen für mich, Leckerli für ihn. Win-Win in Perfektion.",
        "Mein Hamster Elvis lebt nachts auf. Wenn ich nicht schlafen kann, beobachte ich sein Laufrad. Therapeutisch.",
        "Tiere aus dem Tierschutz haben oft die größten Herzen. Mein Kater war verängstigt, jetzt ist er der Boss.",
        "Haustierfotos auf dem Handy: 3000 Bilder von der Katze, 50 von mir. Ich kenne meine Prioritäten.",
        "Mein Hund und ich machen Mantrailing. Er sucht, ich renne hinterher. Er ist besser darin als ich.",
        "Tiere lehren uns, im Moment zu leben. Mein Hund plant nicht, sorgt sich nicht — er ist einfach glücklich."
      ],
      sunset: [
        "Sonnenuntergänge am Deutschen Eck in Koblenz — jedes Mal wie ein Gemälde, jedes Mal anders schön.",
        "Ich sammle Sonnenuntergänge. Nicht auf Fotos, sondern in Erinnerungen. Die schönsten waren auf Santorini.",
        "Abends am Rhein sitzen und zusehen, wie die Sonne hinter der Festung verschwindet — mein liebstes Ritual.",
        "Golden Hour am Rheinufer: Wenn das Licht so warm wird, dass alles wie ein Traum aussieht.",
        "Der schönste Sonnenuntergang meines Lebens? Bali, Uluwatu-Tempel. Aber der am Deutschen Eck kommt nah dran.",
        "Sonnenuntergänge fotografieren: Ich habe 500 Fotos und keins wird dem Original gerecht. Trotzdem: weiter knipsen.",
        "Am liebsten beobachte ich Sonnenuntergänge allein. Dann kann ich still sein und den Moment ganz aufsaugen.",
        "Mein Lieblingsplatz für Sonnenuntergänge: die Festung Ehrenbreitstein. Von dort sieht man zwei Flüsse golden werden.",
        "Jeder Sonnenuntergang ist ein Ende und ein Versprechen zugleich. Morgen kommt ein neuer Tag — und ein neues Farbspektakel.",
        "Sonnenuntergänge mit Wolken sind die besten. Dann malt der Himmel Bilder, die kein Künstler kopieren kann.",
        "Auf meinen Reisen plane ich Abende nach Sonnenuntergängen. Erst den besten Spot finden, dann essen gehen.",
        "Weinschorle in der Hand, Sonnenuntergang vor Augen — mein Feierabend-Ritual von April bis Oktober.",
        "Mein Zeitraffer-Video vom Sonnenuntergang am Rhein hat 20 Likes bekommen. Nicht viral, aber mir reicht's.",
        "Der Moment, kurz bevor die Sonne untergeht — wenn alles rosa wird — das ist meine liebste Sekunde des Tages.",
        "Sonnenuntergänge am Meer oder am Fluss? Beides hat seinen Zauber. Aber das Rauschen des Meeres gewinnt knapp.",
        "Im Winter vermisse ich die langen Sommerabende. Dafür ist die Winterabendsonne intensiver und wärmer.",
        "Mein Balkon zeigt nach Westen. Die beste Entscheidung meines Lebens — zumindest in der Wohnungswahl.",
        "Sundowner-Picknick am Rheinkiesstrand: Käse, Brot, Wein und ein Himmel in Flammen.",
        "Sonnenuntergänge sind gratis und trotzdem das Schönste, was der Tag zu bieten hat.",
        "Letzte Woche: grüner Blitz beim Sonnenuntergang über dem Rhein. Ob ich es wirklich gesehen habe? Ich sage ja."
      ],
      mountains: [
        "Die Berge rufen — und ich muss gehen! Ob Alpen, Eifel oder Hunsrück, Gipfelerlebnisse sind meine Belohnung.",
        "Es gibt kein besseres Gefühl als die Aussicht vom Gipfel. Die ganze Anstrengung lohnt sich in dem Moment.",
        "Bergluft ist die beste Medizin. Jedes Wochenende zieht es mich in die Höhe — je höher, desto besser.",
        "Klettersteig in den Dolomiten: Die Hände zittern, das Herz klopft, und oben angekommen fließen die Tränen.",
        "Berghütten-Romantik: Hüttenschlafsack, Kaiserschmarrn und Sonnenaufgang über den Gipfeln. Unbezahlbar.",
        "Die Eifel unterschätzt jeder. Kleine Berge, große Wirkung. Meine Hausberg-Liebe seit der Kindheit.",
        "Bergsteigen hat mir Demut gelehrt. Der Berg ist immer stärker — man kann nur mit ihm arbeiten, nie gegen ihn.",
        "Schneeschuhwandern im Allgäu: Stille, Weite und der Knirschen des Schnees unter jedem Schritt.",
        "Mein erster 4000er war das Breithorn. Nicht der schwierigste, aber der emotionalste Gipfel meines Lebens.",
        "Bergrettung unterstützen: Ich spende monatlich und habe großen Respekt vor diesen ehrenamtlichen Helden.",
        "Sonnenaufgang auf der Zugspitze: Um 3 Uhr losgelaufen, um 6 oben, um 6:01 Uhr sprachlos.",
        "Bergseen: glasklares Wasser, schneebedeckte Gipfel als Rahmen. Baden gehen ist optional, staunen nicht.",
        "Hütte zu Hütte wandern — jeden Tag ein neues Ziel, jede Nacht ein neuer Schlafplatz. Freiheit in den Bergen.",
        "Die Hunsrückhöhenstraße an einem Herbsttag: Nebel in den Tälern, Sonne auf den Kuppen. Magisch.",
        "Klettern als Meditation: Griff für Griff, Tritt für Tritt. Der Kopf hat keine Zeit für Sorgen.",
        "Bergwetter respektieren: Was als Sonnentag beginnt, kann in einer Stunde umschlagen. Ich habe es gelernt.",
        "Mein Lieblingsberg: der Loreley-Felsen. Nicht hoch, aber mit einer Geschichte, die größer ist als jeder Alpen-Gipfel.",
        "Via Ferrata in Österreich: Stahlseile, Leitern, Adrenalinstöße. Danach ein Radler auf der Terrasse.",
        "Berge im Herbst: goldene Lärchen, klare Luft, leere Wege. Die schönste Jahreszeit zum Wandern.",
        "Mein Kompass zeigt immer nach oben. Egal ob Hügel oder Gipfel — Aufsteigen ist meine Lieblingsbewegung."
      ]
    }
  end

  # ==========================================================================
  # LONG STORIES (20 reflective pieces, used occasionally in moodboards)
  # ==========================================================================
  def long_stories do
    [
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
      """,
      """
      **Mein Sonntagsritual**

      Ausschlafen, langsam Kaffee kochen, etwas Gutes frühstücken. Dann raus — egal wohin. Hauptsache frische Luft und keine Bildschirme.

      Abends dann müde auf der Couch und zufrieden einschlafen. Einfach, aber erfüllend.
      """,
      """
      **Was ich gelernt habe**

      Dass Verletzlichkeit keine Schwäche ist. Dass allein sein und einsam sein zwei verschiedene Dinge sind. Dass die besten Dinge im Leben nicht geplant sind.

      Und dass es nie zu spät ist, jemanden zu finden, der einen versteht.
      """,
      """
      **Mein größtes Abenteuer**

      Ein Monat alleine reisen. Kein Plan, kein festes Ziel. Nur ein Rucksack und die Neugier. Ich habe gelernt, mir selbst zu vertrauen und Fremde als Freunde zu sehen.

      Seitdem habe ich keine Angst mehr vor dem Unbekannten.
      """,
      """
      **Was Freundschaft für mich bedeutet**

      Die Menschen, die um 3 Uhr nachts ans Telefon gehen. Die, die ehrlich sind, auch wenn es wehtut. Die, die bleiben, wenn es unbequem wird.

      In einer Beziehung suche ich genau das Gleiche — nur mit Schmetterlingen.
      """,
      """
      **Kleine Freuden, die ich sammle**

      Den ersten Kaffee am offenen Fenster. Wenn ein Lied perfekt zur Stimmung passt. Briefe schreiben und welche bekommen. Regen auf dem Dachfenster.

      Das Leben besteht aus diesen Momenten — man muss sie nur bemerken.
      """,
      """
      **Mein Lebensmotto**

      Lieber authentisch merkwürdig als angepasst langweilig. Ich stehe zu meinen Ecken und Kanten — denn genau die machen mich aus.

      Perfektion ist langweilig. Ich suche jemanden, der genauso unperfekt und wunderbar ist wie ich.
      """,
      """
      **Was ich an Koblenz liebe**

      Zwei Flüsse, eine Festung und Sonnenuntergänge, die man sich nicht ausdenken könnte. Hier ist alles nah genug und weit genug — die perfekte Balance.

      Manchmal braucht man keine große Stadt, um ein großes Leben zu führen.
      """,
      """
      **Über Ehrlichkeit**

      Ich sage, was ich denke — freundlich, aber direkt. Spielchen und versteckte Botschaften sind nicht mein Ding. Was du siehst, ist was du bekommst.

      Ich suche jemanden, der genauso offen ist. Dann können wir uns die ganze Rätselraterei sparen.
      """,
      """
      **Mein Glücksrezept**

      Genug Schlaf, gutes Essen, Bewegung an der frischen Luft und Menschen, die ich mag. Klingt einfach, braucht aber erstaunlich viel Achtsamkeit.

      Was fehlt? Jemand, der das alles mit mir teilt — und seine eigene Zutat dazugibt.
      """,
      """
      **Was andere über mich sagen**

      Meine Freunde sagen, ich bin loyal bis in die Knochen. Meine Mutter sagt, ich bin zu wählerisch. Mein Hund sagt gar nichts, ist aber immer auf meiner Seite.

      Was ich sage: Ich bin bereit für jemanden, der bleibt.
      """,
      """
      **Über das Alleinsein**

      Ich bin gerne allein. Wirklich. Aber ich möchte nicht einsam sein. Der Unterschied? Allein ist freiwillig. Einsam ist, wenn du was Schönes erlebst und niemanden hast, dem du davon erzählen kannst.

      Ich suche genau diesen Menschen.
      """,
      """
      **Mein Vorsatz**

      Weniger scrollen, mehr erleben. Weniger reden, mehr zuhören. Weniger planen, mehr machen. Und: endlich den Mut haben, den ersten Schritt zu machen.

      Das hier ist mein erster Schritt. Danke fürs Lesen.
      """
    ]
  end

  # ==========================================================================
  # TOPIC PHOTOS (lifestyle photos mapped to topics)
  # ==========================================================================
  def topic_photos do
    %{
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
  end
end
