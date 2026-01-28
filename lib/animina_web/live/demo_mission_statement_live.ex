defmodule AniminaWeb.DemoMissionStatementLive do
  @moduledoc """
  Mission Statement page for ANIMINA - our core values and vision.
  """
  use AniminaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Mission Statement – ANIMINA")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <!-- Hero Section with Mission Statement -->
      <section class="relative overflow-hidden">
        <div class="absolute inset-0 bg-gradient-to-b from-accent/10 via-transparent to-transparent" />

        <div class="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-16 sm:py-24 lg:py-32">
          <div class="text-center max-w-4xl mx-auto">
            <a
              href="/"
              class="inline-flex items-center gap-2 text-base text-primary hover:text-primary/80 mb-8 transition-colors"
            >
              <.icon name="hero-arrow-left" class="size-5" />
              Zurück zur Startseite
            </a>

            <h1 class="text-3xl sm:text-4xl md:text-5xl lg:text-6xl font-light tracking-tight text-base-content leading-tight">
              Dating, das
              <span class="text-primary font-normal">fair</span>
              und
              <span class="text-primary font-normal">transparent</span>
              ist
            </h1>
            <p class="mt-8 text-lg sm:text-xl text-base-content/70 leading-relaxed max-w-3xl mx-auto">
              Keine versteckten Kosten, keine geheimen Algorithmen, keine Premium-Fallen.
              Echte Menschen, echte Verbindungen – für alle.
            </p>
          </div>
        </div>
      </section>

      <!-- Mission Details -->
      <section class="py-16 sm:py-24 bg-base-200/50">
        <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
          <div class="prose prose-lg max-w-none">
            <.mission_block
              title="Respekt als Grundlage"
              icon="hero-shield-check"
            >
              Jeder Nutzer definiert seine eigenen Grenzen – wer diese wiederholt überschreitet, wird gesperrt.
              Und jeder kann unangemessenes Verhalten melden. Bei uns steht der respektvolle Umgang miteinander
              an erster Stelle.
            </.mission_block>

            <.mission_block
              title="Spaß ohne Suchtfaktor"
              icon="hero-face-smile"
            >
              Dating soll Spaß machen, aber nicht süchtig – im echten Leben lernt man ja auch nicht jeden Tag
              50 neue Menschen kennen. Deshalb verzichten wir bewusst auf manipulative Designs wie endloses
              Swipen oder Push-Benachrichtigungen, die dich ständig zurückholen wollen.
            </.mission_block>

            <.mission_block
              title="Für alle da"
              icon="hero-heart"
            >
              Wir kümmern uns um jeden. Egal wer du bist – bei ANIMINA bist du willkommen.
              Keine Diskriminierung durch Algorithmen, die nur bestimmte Menschen bevorzugen.
              Unser Code ist Open Source – jeder kann nachprüfen, dass wir alle gleich behandeln.
            </.mission_block>

            <.mission_block
              title="Fairness durch Limitierung"
              icon="hero-hand-raised"
            >
              Auf klassischen Plattformen haben es beide schwer: Attraktive Menschen ertrinken in Anfragen,
              weniger gefragte bekommen kaum welche. Bei uns kann jeder nur 5 Anfragen pro Tag senden –
              wie im echten Leben. Das macht Dating fairer für alle.
            </.mission_block>

            <.mission_block
              title="Persönlichkeit statt Oberflächlichkeit"
              icon="hero-puzzle-piece"
            >
              Unser einzigartiges Drei-Farben-System hilft dir, Menschen zu finden, die wirklich zu dir passen.
              Weiße Flaggen zeigen, wer du bist. Grüne, was du suchst. Rote, was nicht geht.
              Profile mit Tiefgang statt oberflächlichem Swipen.
            </.mission_block>
          </div>
        </div>
      </section>

      <!-- CTA Section -->
      <section class="py-16 sm:py-24">
        <div class="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8 text-center">
          <h2 class="text-2xl sm:text-3xl font-light text-base-content">
            Bereit für echtes Dating?
          </h2>
          <p class="mt-4 text-lg text-base-content/70">
            Keine Tricks, keine versteckten Kosten. Einfach Menschen kennenlernen, die zu dir passen.
          </p>
          <div class="mt-8">
            <a
              href="/users/register"
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
    </Layouts.app>
    """
  end

  # Mission block component
  attr :title, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp mission_block(assigns) do
    ~H"""
    <div class="flex gap-6 mb-10 p-6 rounded-2xl bg-base-100 shadow-sm">
      <div class="flex-shrink-0">
        <div class="inline-flex items-center justify-center w-14 h-14 rounded-xl bg-accent/30">
          <.icon name={@icon} class="size-7 text-primary" />
        </div>
      </div>
      <div>
        <h3 class="text-xl font-medium text-base-content mb-3">
          {@title}
        </h3>
        <p class="text-base text-base-content/70 leading-relaxed">
          {render_slot(@inner_block)}
        </p>
      </div>
    </div>
    """
  end
end
