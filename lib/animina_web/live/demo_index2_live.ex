defmodule AniminaWeb.DemoIndex2Live do
  @moduledoc """
  German landing page for ANIMINA - showcasing what makes the platform different.

  Key differentiators highlighted:
  - 100% free (ad-supported)
  - Open source & transparent algorithms
  - Personality-based matching (flags system)
  - Story-based profiles
  - Fair for everyone
  """
  use AniminaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Willkommen bei ANIMINA")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col bg-base-100">
      <!-- Navigation -->
      <header class="fixed top-0 left-0 right-0 z-50 bg-base-200/95 backdrop-blur-sm border-b border-base-300">
        <nav aria-label="Main" class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex h-16 items-center justify-between">
            <a href="/demo/index2" class="flex items-center gap-2 group">
              <span class="text-2xl font-light tracking-tight text-primary transition-colors group-hover:text-primary/80">
                ANIMINA
              </span>
            </a>

            <div class="flex items-center gap-4">
              <a
                href="/sign-in"
                class="text-base font-medium text-base-content/70 hover:text-primary transition-colors"
              >
                Anmelden
              </a>
              <a
                href="/register"
                class="inline-flex items-center justify-center px-5 py-2 text-base font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
              >
                Registrieren
              </a>
            </div>
          </div>
        </nav>
      </header>
      
    <!-- Flash Messages -->
      <div class="fixed top-16 left-0 right-0 z-40">
        <Layouts.flash_group flash={@flash} />
      </div>
      
    <!-- Main Content -->
      <main class="flex-1 pt-16">
        <!-- Hero Section -->
        <section class="relative overflow-hidden">
          <div class="absolute inset-0 bg-gradient-to-b from-accent/10 via-transparent to-transparent" />

          <div class="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-16 sm:py-24 lg:py-32">
            <div class="text-center max-w-5xl mx-auto">
              <!-- Hero Images -->
              <div class="flex justify-center gap-4 mb-10">
                <div class="relative">
                  <img
                    src="https://images.unsplash.com/photo-1522529599102-193c0d76b5b6?w=200&h=260&fit=crop&crop=face"
                    alt="Lächelnder Mann"
                    class="w-28 sm:w-36 h-36 sm:h-44 object-cover rounded-2xl shadow-lg -rotate-3 hover:rotate-0 transition-transform duration-300"
                  />
                  <div class="absolute -bottom-2 -right-2 w-8 h-8 bg-success rounded-full flex items-center justify-center shadow-md">
                    <.icon name="hero-heart-solid" class="size-4 text-white" />
                  </div>
                </div>
                <div class="relative mt-6">
                  <img
                    src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&h=260&fit=crop&crop=face"
                    alt="Fröhliche Frau"
                    class="w-28 sm:w-36 h-36 sm:h-44 object-cover rounded-2xl shadow-lg rotate-3 hover:rotate-0 transition-transform duration-300"
                  />
                  <div class="absolute -bottom-2 -left-2 w-8 h-8 bg-primary rounded-full flex items-center justify-center shadow-md">
                    <.icon name="hero-sparkles-solid" class="size-4 text-white" />
                  </div>
                </div>
              </div>

              <div class="grid grid-cols-2 md:grid-cols-3 gap-4 sm:gap-6">
                <.mission_card
                  icon="hero-currency-euro"
                  title="100% Kostenlos"
                  description="Werbefinanziert – keine Premium-Fallen, keine geheimen Algorithmen."
                />
                <.mission_card
                  icon="hero-arrows-right-left"
                  title="Ohne Schubladen"
                  description="Partnerschaft, Affaire oder ein gutes Gespräch – wir urteilen nicht."
                />
                <.mission_card
                  icon="hero-flag"
                  title="Flaggen-System"
                  description="Zeig wer du bist, definiere was du suchst und wo deine Grenzen liegen."
                />
                <.mission_card
                  icon="hero-shield-check"
                  title="Respekt zuerst"
                  description="Blacklist für unerwünschte Kontakte. Grenzüberschreiter werden ausgeschlossen."
                />
                <.mission_card
                  icon="hero-face-smile"
                  title="Freude statt Sucht"
                  description="Dating soll Freude machen, nicht süchtig – Qualität statt Reizüberflutung."
                />
                <.mission_card_link
                  icon="hero-document-text"
                  title="Unser Mission Statement"
                  description="Erfahre mehr über unsere Vision und Werte."
                  href="/demo/mission_statement"
                />
              </div>

              <div class="mt-8 flex flex-col sm:flex-row gap-4 justify-center">
                <a
                  href="/register"
                  class="inline-flex items-center justify-center px-8 py-3.5 text-lg font-medium text-white bg-primary rounded-xl hover:bg-primary/90 transition-all duration-200 shadow-md hover:shadow-lg hover:-translate-y-0.5"
                >
                  Jetzt registrieren – kostenlos
                </a>
              </div>
            </div>
          </div>
        </section>
        
    <!-- Happy Singles Section -->
        <section class="py-16 sm:py-20 bg-base-200/50">
          <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
            <div class="text-center mb-12">
              <h2 class="text-2xl sm:text-3xl font-light text-base-content">
                Menschen, die echte Verbindungen suchen
              </h2>
            </div>

            <div class="grid grid-cols-2 md:grid-cols-4 gap-4 lg:gap-6">
              <%!-- Row 1: European portraits --%>
              <.happy_face
                image_url="https://images.unsplash.com/photo-1560250097-0b93528c311a?w=300&h=300&fit=crop&crop=face"
                alt="Geschäftsmann lächelnd"
              />
              <.happy_face
                image_url="https://images.unsplash.com/photo-1573496799652-408c2ac9fe98?w=300&h=300&fit=crop&crop=face"
                alt="Lächelnde Frau"
              />
              <.happy_face
                image_url="https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&h=300&fit=crop&crop=face"
                alt="Junger Mann"
              />
              <.happy_face
                image_url="https://images.unsplash.com/photo-1580489944761-15a19d654956?w=300&h=300&fit=crop&crop=face"
                alt="Fröhliche junge Frau"
              />
              <%!-- Row 2: More diverse portraits --%>
              <.happy_face
                image_url="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&h=300&fit=crop&crop=face"
                alt="Freundlicher Mann"
              />
              <.happy_face
                image_url="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&h=300&fit=crop&crop=face"
                alt="Frau mit Lächeln"
              />
              <.happy_face
                image_url="https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&h=300&fit=crop&crop=face"
                alt="Älterer Herr"
              />
              <.happy_face
                image_url="https://images.unsplash.com/photo-1589156280159-27698a70f29e?w=300&h=300&fit=crop&crop=face"
                alt="Strahlende Frau"
              />
            </div>
          </div>
        </section>
        
    <!-- Key Differentiators Section -->
        <section class="py-16 sm:py-24">
          <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
            <div class="text-center mb-12 sm:mb-16">
              <h2 class="text-2xl sm:text-3xl font-light text-base-content">
                Was ANIMINA anders macht
              </h2>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 lg:gap-10">
              <.differentiator_card
                icon="hero-currency-euro"
                title="100% Kostenlos"
                description="Alle Funktionen sind für jeden kostenlos. Keine Premium-Abos, keine versteckten Kosten, keine Pay-to-Win-Mechanismen. Wir finanzieren uns durch Werbung."
              />

              <.differentiator_card
                icon="hero-code-bracket"
                title="Open Source"
                description="Unser gesamter Code ist öffentlich einsehbar. Jeder kann unseren Algorithmus prüfen. Keine Geheimnisse, keine Manipulationen – alles transparent und fair."
              />

              <.differentiator_card
                icon="hero-heart"
                title="Für alle da"
                description="Wir kümmern uns um jeden. Egal wer du bist – bei ANIMINA bist du willkommen. Keine Diskriminierung durch Algorithmen, die nur bestimmte Menschen bevorzugen."
              />

              <.differentiator_card
                icon="hero-hand-raised"
                title="Maximal 5 Anfragen pro Tag"
                description="Auf klassischen Plattformen haben es beide schwer: Attraktive Menschen ertrinken in Anfragen, weniger gefragte bekommen kaum welche. Bei uns kann jeder nur 5 Anfragen pro Tag senden – wie im echten Leben. Das macht Dating fairer für alle."
              />

              <.differentiator_card
                icon="hero-puzzle-piece"
                title="Persönlichkeit zählt"
                description="Unser einzigartiges Drei-Farben-System: Weiße Flaggen zeigen, wer du bist. Grüne, was du suchst. Rote, was nicht geht. So findest du Menschen, die wirklich zu dir passen."
              />

              <.differentiator_card
                icon="hero-document-text"
                title="Geschichten statt Swipes"
                description="Profile mit Tiefgang: Präsentiere dich so, wie du willst – nur mit Fotos, nur mit Texten oder mit beidem. Lerne Menschen wirklich kennen, bevor du sie kontaktierst – statt nur Bilder nach links oder rechts zu wischen."
              />

              <.differentiator_card
                icon="hero-shield-check"
                title="Echte Menschen"
                description="Verifizierte Profile und aktive Moderation sorgen für eine sichere Community. Fake-Profile und Bots haben bei uns keine Chance."
              />

              <.differentiator_card
                icon="hero-face-smile"
                title="Spaß ohne Suchtfaktor"
                description="Dating soll Spaß machen – aber nicht abhängig. Wir verzichten bewusst auf manipulative Designs wie endloses Swipen oder Push-Benachrichtigungen, die dich ständig zurückholen wollen."
              />
            </div>
          </div>
        </section>
        
    <!-- Open Source Highlight Section -->
        <section class="py-16 sm:py-24 bg-primary/5">
          <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
            <div class="text-center">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-accent/30 mb-6">
                <.icon name="hero-code-bracket-square" class="size-8 text-primary" />
              </div>
              <h2 class="text-2xl sm:text-3xl font-light text-base-content mb-4">
                Transparenz durch Open Source
              </h2>
              <p class="text-lg text-base-content/70 leading-relaxed max-w-2xl mx-auto mb-8">
                Bei anderen Dating-Plattformen weißt du nie, warum dir bestimmte Menschen gezeigt werden.
                Bevorzugt der Algorithmus zahlende Kunden? Werden Profile versteckt, um dich zum Upgrade zu zwingen?
              </p>
              <p class="text-lg text-base-content/70 leading-relaxed max-w-2xl mx-auto mb-8">
                <span class="font-medium text-base-content">Bei ANIMINA ist alles anders.</span>
                Unser Code ist vollständig öffentlich auf GitHub verfügbar. Jeder kann nachprüfen,
                wie unser Matching funktioniert. Der Algorithmus behandelt alle gleich – ohne Ausnahme.
              </p>
              <a
                href="https://github.com/animina-dating/animina"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-2 text-primary hover:text-primary/80 font-medium transition-colors"
              >
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path
                    fill-rule="evenodd"
                    d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
                    clip-rule="evenodd"
                  />
                </svg>
                Code auf GitHub ansehen
              </a>
            </div>
          </div>
        </section>
        
    <!-- Flag System Explanation -->
        <section class="py-16 sm:py-24">
          <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
            <div class="text-center mb-12">
              <h2 class="text-2xl sm:text-3xl font-light text-base-content">
                Finde Menschen, die zu dir passen
              </h2>
              <p class="mt-3 text-lg text-base-content/70 max-w-2xl mx-auto">
                Unser Drei-Farben-System macht Matching persönlich und ehrlich
              </p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
              <.flag_card
                color="white"
                title="Weiße Flaggen"
                subtitle="Das bin ich"
                description="Beschreibe dich selbst: Deine Eigenschaften, Hobbys, Werte und Lebensstil. Von Humor über Kreativität bis hin zu deinen Lieblingsküchen."
                examples={["☀️ Optimismus", "🍳 Kochen", "🎸 Rock-Musik", "🐶 Hundeliebhaber"]}
              />

              <.flag_card
                color="green"
                title="Grüne Flaggen"
                subtitle="Das suche ich"
                description="Was wünschst du dir bei einem Partner? Welche Eigenschaften findest du attraktiv? Die Reihenfolge zeigt, was dir am wichtigsten ist."
                examples={["🤝 Ehrlichkeit", "😄 Humor", "👨‍👩‍👧‍👦 Familienorientiert", "🌍 Reiselust"]}
              />

              <.flag_card
                color="red"
                title="Rote Flaggen"
                subtitle="Das geht nicht"
                description="Jeder hat Deal-Breaker. Sei ehrlich darüber, was für dich nicht funktioniert. Das spart Zeit und Enttäuschungen auf beiden Seiten."
                examples={["🚬 Rauchen", "🍻 Übermäßiger Alkohol", "📵 Nie offline"]}
              />
            </div>
          </div>
        </section>
        
    <!-- Final CTA Section -->
        <section class="py-16 sm:py-24 bg-base-200/50">
          <div class="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8 text-center">
            <h2 class="text-2xl sm:text-3xl font-light text-base-content">
              Bereit für echtes Dating?
            </h2>
            <p class="mt-4 text-lg text-base-content/70">
              Keine Tricks, keine versteckten Kosten. Einfach Menschen kennenlernen, die zu dir passen.
            </p>
            <div class="mt-8">
              <a
                href="/register"
                class="inline-flex items-center justify-center px-10 py-4 text-lg font-medium text-white bg-primary rounded-xl hover:bg-primary/90 transition-all duration-200 shadow-md hover:shadow-lg hover:-translate-y-0.5"
              >
                Jetzt registrieren <.icon name="hero-arrow-right" class="ml-2 size-5" />
              </a>
            </div>
            <p class="mt-4 text-base text-base-content/70">
              Kostenlos. Für immer. Für alle.
            </p>
          </div>
        </section>
      </main>
      
    <!-- Footer -->
      <footer class="border-t border-base-300 bg-base-200/50">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8 sm:py-12">
          <div class="flex flex-col sm:flex-row items-center justify-between gap-4">
            <div class="flex items-center gap-2">
              <span class="text-xl font-light tracking-tight text-primary">ANIMINA</span>
            </div>
            <nav
              aria-label="Footer"
              class="flex flex-wrap justify-center gap-6 text-base text-base-content/70"
            >
              <a href="#" class="hover:text-primary transition-colors">Über uns</a>
              <a href="#" class="hover:text-primary transition-colors">Datenschutz</a>
              <a href="#" class="hover:text-primary transition-colors">AGB</a>
              <a href="#" class="hover:text-primary transition-colors">Impressum</a>
              <a
                href="https://github.com/animina-dating/animina"
                target="_blank"
                rel="noopener noreferrer"
                class="hover:text-primary transition-colors"
              >
                GitHub
              </a>
            </nav>
            <p class="text-base text-base-content/70">
              &copy; {DateTime.utc_now().year} ANIMINA. Open Source mit ❤️
            </p>
          </div>
        </div>
      </footer>
    </div>
    """
  end

  # Mission card component for hero section
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp mission_card(assigns) do
    ~H"""
    <div class="flex flex-col items-center text-center p-5 rounded-2xl bg-base-200/60 hover:bg-base-200 transition-colors">
      <div class="hidden sm:inline-flex items-center justify-center w-12 h-12 rounded-xl bg-accent/30 mb-4">
        <.icon name={@icon} class="size-6 text-primary" />
      </div>
      <h3 class="text-lg font-medium text-base-content mb-2">
        {@title}
      </h3>
      <p class="text-sm text-base-content/70 leading-relaxed">
        {@description}
      </p>
    </div>
    """
  end

  # Mission card with link component for hero section
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :href, :string, required: true

  defp mission_card_link(assigns) do
    ~H"""
    <a
      href={@href}
      class="flex flex-col items-center text-center p-5 rounded-2xl bg-primary/10 hover:bg-primary/20 transition-colors group"
    >
      <div class="hidden sm:inline-flex items-center justify-center w-12 h-12 rounded-xl bg-primary/20 mb-4">
        <.icon name={@icon} class="size-6 text-primary" />
      </div>
      <h3 class="text-lg font-medium text-primary mb-2 group-hover:underline">
        {@title}
      </h3>
      <p class="text-sm text-base-content/70 leading-relaxed">
        {@description}
      </p>
      <.icon
        name="hero-arrow-right"
        class="size-5 text-primary mt-3 group-hover:translate-x-1 transition-transform"
      />
    </a>
    """
  end

  # Happy face image component
  attr :image_url, :string, required: true
  attr :alt, :string, required: true

  defp happy_face(assigns) do
    ~H"""
    <div class="aspect-square rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-shadow duration-300">
      <img
        src={@image_url}
        alt={@alt}
        class="w-full h-full object-cover"
        loading="lazy"
      />
    </div>
    """
  end

  # Differentiator card component
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp differentiator_card(assigns) do
    ~H"""
    <div class="text-center p-6 rounded-2xl bg-base-200/50 hover:bg-base-200 transition-colors">
      <div class="inline-flex items-center justify-center w-14 h-14 rounded-xl bg-accent/30 mb-5">
        <.icon name={@icon} class="size-7 text-primary" />
      </div>
      <h3 class="text-xl font-medium text-base-content mb-3">
        {@title}
      </h3>
      <p class="text-base text-base-content/70 leading-relaxed">
        {@description}
      </p>
    </div>
    """
  end

  # Flag explanation card component
  attr :color, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :description, :string, required: true
  attr :examples, :list, required: true

  defp flag_card(assigns) do
    border_color =
      case assigns.color do
        "white" -> "border-base-300"
        "green" -> "border-success/50"
        "red" -> "border-error/50"
      end

    bg_color =
      case assigns.color do
        "white" -> "bg-base-200"
        "green" -> "bg-success/10"
        "red" -> "bg-error/10"
      end

    assigns = assign(assigns, border_color: border_color, bg_color: bg_color)

    ~H"""
    <div class={"rounded-2xl border-2 #{@border_color} #{@bg_color} p-6"}>
      <h3 class="text-xl font-medium text-base-content mb-1">
        {@title}
      </h3>
      <p class="text-base font-medium text-primary mb-4">
        {@subtitle}
      </p>
      <p class="text-base text-base-content/70 leading-relaxed mb-4">
        {@description}
      </p>
      <div class="flex flex-wrap gap-2">
        <span
          :for={example <- @examples}
          class="inline-flex items-center px-3 py-1.5 rounded-full text-sm bg-base-100 text-base-content/80"
        >
          {example}
        </span>
      </div>
    </div>
    """
  end
end
