defmodule AniminaWeb.ImpressumLive do
  @moduledoc """
  Impressum (legal notice / imprint) page for ANIMINA.
  """
  use AniminaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Impressum – ANIMINA")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <article class="space-y-10">
          <%!-- ===== HEADER ===== --%>
          <header class="text-center space-y-2">
            <h1 class="text-3xl sm:text-4xl font-light tracking-tight text-base-content">
              Impressum
            </h1>
          </header>

          <%!-- ===== ANGABEN GEMÄSS § 5 TMG ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Angaben gemäß § 5 TMG
            </h2>
            <address class="text-base-content/80 leading-relaxed not-italic">
              Wintermeyer Consulting<br /> Johannes-Müller-Str. 10<br /> 56068 Koblenz
            </address>
          </section>

          <%!-- ===== KONTAKT ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Kontakt
            </h2>
            <div class="text-base-content/80 leading-relaxed space-y-1">
              <p>
                Telefon:
                <a href="tel:+49261-9886803" class="text-primary hover:underline">+49-261-9886803</a>
              </p>
              <p>
                E-Mail:
                <a href="mailto:sw@wintermeyer-consulting.de" class="text-primary hover:underline">
                  sw@wintermeyer-consulting.de
                </a>
              </p>
            </div>
          </section>

          <%!-- ===== VERANTWORTLICH ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Verantwortlich für den Inhalt nach § 55 Abs. 2 RStV
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Stefan Wintermeyer<br /> Johannes-Müller-Str. 10<br /> 56068 Koblenz
            </p>
          </section>

          <%!-- ===== HAFTUNG FÜR INHALTE ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Haftung für Inhalte
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Als Diensteanbieter sind wir gemäß § 7 Abs.1 TMG für eigene Inhalte auf
              diesen Seiten nach den allgemeinen Gesetzen verantwortlich. Nach §§ 8 bis 10
              TMG sind wir als Diensteanbieter jedoch nicht verpflichtet, übermittelte oder
              gespeicherte fremde Informationen zu überwachen oder nach Umständen zu
              forschen, die auf eine rechtswidrige Tätigkeit hinweisen.
            </p>
            <p class="text-base-content/80 leading-relaxed">
              Verpflichtungen zur Entfernung oder Sperrung der Nutzung von Informationen
              nach den allgemeinen Gesetzen bleiben hiervon unberührt. Eine diesbezügliche
              Haftung ist jedoch erst ab dem Zeitpunkt der Kenntnis einer konkreten
              Rechtsverletzung möglich. Bei Bekanntwerden von entsprechenden
              Rechtsverletzungen werden wir diese Inhalte umgehend entfernen.
            </p>
          </section>

          <%!-- ===== HAFTUNG FÜR LINKS ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Haftung für Links
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Unser Angebot enthält Links zu externen Webseiten Dritter, auf deren Inhalte
              wir keinen Einfluss haben. Deshalb können wir für diese fremden Inhalte auch
              keine Gewähr übernehmen. Für die Inhalte der verlinkten Seiten ist stets der
              jeweilige Anbieter oder Betreiber der Seiten verantwortlich. Die verlinkten
              Seiten wurden zum Zeitpunkt der Verlinkung auf mögliche Rechtsverstöße
              überprüft. Rechtswidrige Inhalte waren zum Zeitpunkt der Verlinkung nicht
              erkennbar.
            </p>
            <p class="text-base-content/80 leading-relaxed">
              Eine permanente inhaltliche Kontrolle der verlinkten Seiten ist jedoch ohne
              konkrete Anhaltspunkte einer Rechtsverletzung nicht zumutbar. Bei
              Bekanntwerden von Rechtsverletzungen werden wir derartige Links umgehend
              entfernen.
            </p>
          </section>

          <%!-- ===== URHEBERRECHT ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Urheberrecht
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Die durch die Seitenbetreiber erstellten Inhalte und Werke auf diesen Seiten
              unterliegen dem deutschen Urheberrecht. Die Vervielfältigung, Bearbeitung,
              Verbreitung und jede Art der Verwertung außerhalb der Grenzen des
              Urheberrechtes bedürfen der schriftlichen Zustimmung des jeweiligen Autors
              bzw. Erstellers. Downloads und Kopien dieser Seite sind nur für den privaten,
              nicht kommerziellen Gebrauch gestattet.
            </p>
            <p class="text-base-content/80 leading-relaxed">
              Soweit die Inhalte auf dieser Seite nicht vom Betreiber erstellt wurden,
              werden die Urheberrechte Dritter beachtet. Insbesondere werden Inhalte Dritter
              als solche gekennzeichnet. Sollten Sie trotzdem auf eine
              Urheberrechtsverletzung aufmerksam werden, bitten wir um einen entsprechenden
              Hinweis. Bei Bekanntwerden von Rechtsverletzungen werden wir derartige Inhalte
              umgehend entfernen.
            </p>
          </section>
        </article>
      </div>
    </Layouts.app>
    """
  end
end
