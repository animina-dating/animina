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
    {:ok, assign(socket, page_title: gettext("Welcome to ANIMINA"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <!-- Hero Section -->
      <section class="relative overflow-hidden">
        <div class="absolute inset-0 bg-gradient-to-b from-accent/10 via-transparent to-transparent" />

        <div class="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8 sm:py-16 lg:py-20">
          <div class="text-center max-w-5xl mx-auto">
            <!-- Hero Images -->
            <div class="flex justify-center items-end gap-3 sm:gap-4 mb-10">
              <div class="relative">
                <img
                  src="/images/faces/freundlicher-mann-hero.jpg"
                  alt="Freundlicher Mann"
                  class="w-20 sm:w-28 h-24 sm:h-36 object-cover rounded-2xl shadow-lg -rotate-6 hover:rotate-0 transition-transform duration-300"
                />
              </div>
              <div class="relative">
                <img
                  src="/images/hero-streichholz.jpeg"
                  alt="Mann mit Streichholz"
                  class="w-28 sm:w-36 h-36 sm:h-44 object-cover rounded-2xl shadow-lg -rotate-2 hover:rotate-0 transition-transform duration-300"
                />
                <div class="absolute -bottom-2 -end-2 w-8 h-8 bg-success rounded-full flex items-center justify-center shadow-md">
                  <.icon name="hero-heart-solid" class="size-4 text-white" />
                </div>
              </div>
              <div class="relative mt-4">
                <img
                  src="/images/faces/froehliche-junge-frau.jpg"
                  alt="Fröhliche junge Frau"
                  class="w-28 sm:w-36 h-36 sm:h-44 object-cover rounded-2xl shadow-lg rotate-2 hover:rotate-0 transition-transform duration-300"
                />
                <div class="absolute -bottom-2 -start-2 w-8 h-8 bg-primary rounded-full flex items-center justify-center shadow-md">
                  <.icon name="hero-sparkles-solid" class="size-4 text-white" />
                </div>
              </div>
              <div class="relative">
                <img
                  src="/images/faces/strahlende-frau-hero.jpg"
                  alt="Strahlende Frau"
                  class="w-20 sm:w-28 h-24 sm:h-36 object-cover rounded-2xl shadow-lg rotate-6 hover:rotate-0 transition-transform duration-300"
                />
              </div>
            </div>

            <div class="grid grid-cols-2 md:grid-cols-3 gap-4 sm:gap-6">
              <.mission_card
                icon="hero-currency-euro"
                title={gettext("100% Free")}
                description={gettext("Ad-supported – no premium traps, no secret algorithms.")}
              />
              <.mission_card
                icon="hero-arrows-right-left"
                title={gettext("Without labels")}
                description={gettext("Partnership, affair or a good conversation – we don't judge.")}
              />
              <.mission_card
                icon="hero-flag"
                title={gettext("Flag system")}
                description={
                  gettext(
                    "Show who you are, define what you're looking for and where your boundaries are."
                  )
                }
              />
              <.mission_card
                icon="hero-shield-check"
                title={gettext("Respect first")}
                description={
                  gettext(
                    "Blacklist for unwanted contacts. Those who cross boundaries will be excluded."
                  )
                }
              />
              <.mission_card
                icon="hero-face-smile"
                title={gettext("Joy instead of addiction")}
                description={
                  gettext("Dating should be joyful, not addictive – quality over sensory overload.")
                }
              />
              <.mission_card
                icon="hero-server-stack"
                title={gettext("Self-hosted in Germany")}
                description={
                  gettext(
                    "Our servers are not in the cloud – they run on our own physical hardware in Germany."
                  )
                }
              />
            </div>

            <div class="mt-8 flex flex-col sm:flex-row gap-4 justify-center">
              <a
                href="/users/register"
                class="inline-flex items-center justify-center px-8 py-3.5 text-lg font-medium text-white bg-primary rounded-xl hover:bg-primary/90 transition-all duration-200 shadow-md hover:shadow-lg hover:-translate-y-0.5"
              >
                {gettext("Register now – free")}
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
              {gettext("People looking for real connections")}
            </h2>
          </div>

          <div class="grid grid-cols-2 md:grid-cols-4 gap-4 lg:gap-6">
            <%!-- Row 1: European portraits --%>
            <.happy_face
              image_url="/images/faces/geschaeftsmann.jpg"
              alt="Geschäftsmann lächelnd"
            />
            <.happy_face
              image_url="/images/faces/laechelnde-frau.jpg"
              alt="Lächelnde Frau"
            />
            <.happy_face
              image_url="/images/faces/junger-mann.jpg"
              alt="Junger Mann"
            />
            <.happy_face
              image_url="/images/faces/freundliche-frau.jpg"
              alt="Freundliche Frau"
            />
            <%!-- Row 2: More diverse portraits --%>
            <.happy_face
              image_url="/images/faces/laechelnder-mann.jpg"
              alt="Lächelnder Mann"
            />
            <.happy_face
              image_url="/images/faces/frau-mit-laecheln.jpg"
              alt="Frau mit Lächeln"
            />
            <.happy_face
              image_url="/images/faces/frau-mit-kopftuch.jpg"
              alt="Frau mit Kopftuch"
            />
            <.happy_face
              image_url="/images/faces/junge-frau.jpg"
              alt="Junge Frau"
            />
          </div>
        </div>
      </section>
      
    <!-- Flag System Explanation -->
      <section class="py-16 sm:py-24">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12">
            <h2 class="text-2xl sm:text-3xl font-light text-base-content">
              {gettext("Find people who match you")}
            </h2>
            <p class="mt-3 text-lg text-base-content/70 max-w-2xl mx-auto">
              {gettext("Our three-color system makes matching personal and honest")}
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
            <.flag_card
              color="white"
              title={gettext("White Flags")}
              subtitle={gettext("This is me")}
              description={
                gettext(
                  "Describe yourself: Your traits, hobbies, values and lifestyle. From humor to creativity to your favorite cuisines."
                )
              }
              examples={["☀️ Optimismus", "🍳 Kochen", "🎸 Rock-Musik", "🐶 Hundeliebhaber"]}
            />

            <.flag_card
              color="green"
              title={gettext("Green Flags")}
              subtitle={gettext("This is what I'm looking for")}
              description={
                gettext(
                  "What do you want in a partner? Which traits do you find attractive? The order shows what matters most to you."
                )
              }
              examples={["🤝 Ehrlichkeit", "😄 Humor", "👨‍👩‍👧‍👦 Familienorientiert", "🌍 Reiselust"]}
            />

            <.flag_card
              color="red"
              title={gettext("Red Flags")}
              subtitle={gettext("That's a no-go")}
              description={
                gettext(
                  "Everyone has deal-breakers. Be honest about what doesn't work for you. It saves time and disappointment on both sides."
                )
              }
              examples={["🚬 Rauchen", "🍻 Übermäßiger Alkohol", "📵 Nie offline"]}
            />
          </div>
        </div>
      </section>
      
    <!-- Key Differentiators Section -->
      <section class="py-16 sm:py-24">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12 sm:mb-16">
            <h2 class="text-2xl sm:text-3xl font-light text-base-content">
              {gettext("What makes ANIMINA different")}
            </h2>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 lg:gap-10">
            <.differentiator_card
              icon="hero-currency-euro"
              title={gettext("100% Free")}
              description={
                gettext(
                  "All features are free for everyone. No premium subscriptions, no hidden costs, no pay-to-win mechanics. We are financed through advertising."
                )
              }
            />

            <.differentiator_card
              icon="hero-hand-raised"
              title={gettext("Not unlimited requests")}
              description={
                gettext(
                  "On traditional platforms both sides struggle: Attractive people drown in requests, less popular ones barely get any. With us, the number of requests per day is limited. In real life, you can't talk to 10 potential partners at the same time either. This makes dating fairer for everyone."
                )
              }
            />

            <.differentiator_card
              icon="hero-puzzle-piece"
              title={gettext("Personality counts")}
              description={
                gettext(
                  "Our unique three-color system: White flags show who you are. Green ones what you're looking for. Red ones what's a no-go. This helps you find people who truly match you."
                )
              }
            />

            <.differentiator_card
              icon="hero-document-text"
              title={gettext("Stories instead of swipes")}
              description={
                gettext(
                  "Profiles with depth: Present yourself however you want – with photos only, text only, or both. Get to know people before contacting them – instead of just swiping pictures left or right."
                )
              }
            />

            <.differentiator_card
              icon="hero-shield-check"
              title={gettext("Real people")}
              description={
                gettext(
                  "Verified profiles and active moderation ensure a safe community. Fake profiles and bots barely stand a chance with us."
                )
              }
            />

            <.differentiator_card
              icon="hero-face-smile"
              title={gettext("Fun without addiction")}
              description={
                gettext(
                  "Dating should be fun – but not addictive. We deliberately avoid manipulative designs like endless swiping or push notifications that keep pulling you back."
                )
              }
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
              {gettext("Transparency through Open Source")}
            </h2>
            <p class="text-lg text-base-content/70 leading-relaxed max-w-2xl mx-auto mb-8">
              {gettext(
                "With other dating platforms you never know why certain people are shown to you. Does the algorithm favor paying customers? Are profiles hidden to force you to upgrade?"
              )}
            </p>
            <p class="text-lg text-base-content/70 leading-relaxed max-w-2xl mx-auto mb-8">
              <span class="font-medium text-base-content">
                {gettext("At ANIMINA everything is different.")}
              </span>
              {gettext(
                "Our code is fully available on GitHub. Anyone can verify how our matching works. The algorithm treats everyone equally – no exceptions."
              )}
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
              {gettext("View code on GitHub")}
            </a>
          </div>
        </div>
      </section>
      
    <!-- Final CTA Section -->
      <section class="py-16 sm:py-24 bg-base-200/50">
        <div class="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8 text-center">
          <h2 class="text-2xl sm:text-3xl font-light text-base-content">
            {gettext("Ready for real dating?")}
          </h2>
          <p class="mt-4 text-lg text-base-content/70">
            {gettext("No tricks, no hidden costs. Simply meet people who match you.")}
          </p>
          <div class="mt-8">
            <a
              href="/users/register"
              class="inline-flex items-center justify-center px-10 py-4 text-lg font-medium text-white bg-primary rounded-xl hover:bg-primary/90 transition-all duration-200 shadow-md hover:shadow-lg hover:-translate-y-0.5"
            >
              {gettext("Register now")}
              <.icon name="hero-arrow-right" class="ms-2 size-5 rtl:rotate-180" />
            </a>
          </div>
          <p class="mt-4 text-base text-base-content/70">
            {gettext("Free. Forever. For everyone.")}
          </p>
        </div>
      </section>
    </Layouts.app>
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
    {border_color, bg_color} =
      case assigns.color do
        "white" -> {"border-base-300", "bg-base-200"}
        "green" -> {"border-success/50", "bg-success/10"}
        "red" -> {"border-error/50", "bg-error/10"}
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
