defmodule AniminaWeb.TermsOfServiceLive do
  @moduledoc """
  Allgemeine Geschäftsbedingungen (AGB / Terms of Service) page for ANIMINA.
  """
  use AniminaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "AGB")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <article class="space-y-10">
          <%!-- ===== HEADER ===== --%>
          <header class="text-center space-y-2">
            <h1 class="text-3xl sm:text-4xl font-light tracking-tight text-base-content">
              Allgemeine Geschäftsbedingungen (AGB)
            </h1>
            <p class="text-base-content/50 text-sm">Stand: 6. Februar 2026</p>
          </header>

          <%!-- ===== § 1 GELTUNGSBEREICH ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              § 1 Geltungsbereich
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Diese Allgemeinen Geschäftsbedingungen (nachfolgend „AGB") gelten für die Nutzung
              der Online-Dating-Plattform ANIMINA (nachfolgend „Plattform"), betrieben von
              Wintermeyer Consulting, Johannes-Müller-Str. 10, 56068 Koblenz (nachfolgend
              „Betreiber").
            </p>
            <p class="text-base-content/80 leading-relaxed">
              Mit der Registrierung akzeptiert der Nutzer diese AGB. Die Nutzung der Plattform
              ist nur bei Einverständnis mit diesen Bedingungen gestattet.
            </p>
          </section>

          <%!-- ===== § 2 VERTRAGSGEGENSTAND ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              § 2 Vertragsgegenstand
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              ANIMINA stellt eine Plattform bereit, auf der volljährige Personen ein Profil
              erstellen, andere Nutzerprofile einsehen und über ein internes
              Nachrichtensystem miteinander kommunizieren können, mit dem Ziel, einen Partner
              zu finden.
            </p>
            <p class="text-base-content/80 leading-relaxed">
              Die Plattform bietet keine Garantie für den Erfolg der Partnersuche. Der
              Betreiber vermittelt keine Kontakte im Sinne des Partnervermittlungsvertrags
              (§ 656 BGB).
            </p>
          </section>

          <%!-- ===== § 3 REGISTRIERUNG ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              § 3 Registrierung und Nutzerkonto
            </h2>
            <ol class="list-decimal list-inside space-y-2 text-base-content/80 leading-relaxed">
              <li>
                Die Nutzung der Plattform setzt eine Registrierung voraus. Nur natürliche
                Personen ab 18 Jahren dürfen sich registrieren.
              </li>
              <li>
                Bei der Registrierung sind wahrheitsgemäße Angaben zu machen. Insbesondere
                müssen Geburtsdatum, Geschlecht und Wohnort korrekt angegeben werden.
              </li>
              <li>
                Jede Person darf nur ein Nutzerkonto führen. Mehrfachregistrierungen sind
                unzulässig.
              </li>
              <li>
                Der Nutzer ist verpflichtet, seine Zugangsdaten vertraulich zu behandeln und
                nicht an Dritte weiterzugeben.
              </li>
            </ol>
          </section>

          <%!-- ===== § 4 PFLICHTEN DER NUTZER ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              § 4 Pflichten der Nutzer
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Nutzer verpflichten sich insbesondere:
            </p>
            <ul class="list-disc list-inside space-y-1 text-base-content/80 leading-relaxed">
              <li>keine belästigenden, bedrohenden oder beleidigenden Inhalte zu verbreiten;</li>
              <li>
                keine rechtswidrigen, gewaltverherrlichenden oder pornografischen Inhalte hochzuladen;
              </li>
              <li>keine Minderjährigen zu kontaktieren oder deren Kontaktaufnahme zu ermöglichen;</li>
              <li>
                keine kommerziellen Angebote, Spam oder Werbung über die Plattform zu
                verbreiten;
              </li>
              <li>
                keine automatisierten Zugriffe (Bots, Scraping) auf die Plattform durchzuführen;
              </li>
              <li>das Urheberrecht und Persönlichkeitsrechte Dritter zu beachten.</li>
            </ul>
          </section>

          <%!-- ===== § 5 INHALTE UND MODERATION ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              § 5 Inhalte und Moderation
            </h2>
            <ol class="list-decimal list-inside space-y-2 text-base-content/80 leading-relaxed">
              <li>
                Nutzer sind für die von ihnen eingestellten Inhalte (Profilfotos, Texte,
                Nachrichten) selbst verantwortlich.
              </li>
              <li>
                Der Betreiber behält sich vor, Inhalte zu überprüfen, die gegen diese AGB,
                geltendes Recht oder die guten Sitten verstoßen. Hierzu können autorisierte
                Administratoren und Moderatoren Einsicht in Profilfotos, Profiltexte,
                Moodboard-Inhalte und Nachrichten nehmen.
              </li>
              <li>
                Diese Einsichtnahme erfolgt ausschließlich zum Zwecke der Moderation,
                Sicherheit der Nutzer, Betrugsbekämpfung, Bearbeitung von Supportanfragen
                sowie der Erfüllung gesetzlicher Pflichten.
              </li>
              <li>
                Der Betreiber ist berechtigt, rechtswidrige oder regelwidrige Inhalte ohne
                vorherige Ankündigung zu entfernen.
              </li>
            </ol>
          </section>

          <%!-- ===== § 6 NACHRICHTEN UND KOMMUNIKATION ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              § 6 Nachrichten und Kommunikation
            </h2>
            <ol class="list-decimal list-inside space-y-2 text-base-content/80 leading-relaxed">
              <li>
                Die Plattform stellt ein internes Nachrichtensystem zur Verfügung. Nachrichten
                zwischen Nutzern unterliegen den in § 5 genannten Moderationsregeln.
              </li>
              <li>
                Administratoren und Moderatoren können im Rahmen von Supportanfragen,
                gemeldeten Verstößen, Betrugsverdacht oder behördlichen Anfragen auf
                Nachrichtenverläufe zugreifen.
              </li>
              <li>
                Der Zugriff auf Nachrichten durch Administratoren wird protokolliert
                (Audit-Log).
              </li>
            </ol>
          </section>

          <%!-- ===== § 7 KONTOSPERRUNG UND -LÖSCHUNG DURCH BETREIBER ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              § 7 Kontosperrung und -löschung durch den Betreiber
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Der Betreiber ist berechtigt, Nutzerkonten vorübergehend zu sperren oder
              endgültig zu löschen, wenn:
            </p>
            <ul class="list-disc list-inside space-y-1 text-base-content/80 leading-relaxed">
              <li>ein Verstoß gegen diese AGB vorliegt;</li>
              <li>ein begründeter Betrugsverdacht besteht;</li>
              <li>eine behördliche oder gerichtliche Anordnung vorliegt;</li>
              <li>das Nutzerkonto offensichtlich missbräuchlich verwendet wird.</li>
            </ul>
            <p class="text-base-content/80 leading-relaxed">
              Im Falle einer Sperrung oder Löschung wird der Nutzer über die bei der
              Registrierung angegebene E-Mail-Adresse informiert, sofern dies nicht
              behördlichen Auflagen widerspricht.
            </p>
          </section>

          <%!-- ===== § 8 RECHT AUF KONTOLÖSCHUNG ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              § 8 Recht auf Kontolöschung
            </h2>
            <ol class="list-decimal list-inside space-y-2 text-base-content/80 leading-relaxed">
              <li>
                Nutzer können ihr Konto jederzeit selbstständig über die Kontoeinstellungen
                löschen (<a
                  href="/my/settings/account"
                  class="text-primary hover:underline"
                >/my/settings/account</a>).
              </li>
              <li>
                Nach Beantragung der Löschung besteht eine 30-tägige Nachfrist, in der das
                Konto reaktiviert werden kann (Soft-Delete). Nach Ablauf dieser Frist werden
                sämtliche personenbezogene Daten endgültig gelöscht (Art. 17 DSGVO).
              </li>
              <li>
                Eine sofortige endgültige Löschung ohne Nachfrist kann per E-Mail an
                <a
                  href="mailto:sw@wintermeyer-consulting.de"
                  class="text-primary hover:underline"
                >
                  sw@wintermeyer-consulting.de
                </a>
                beantragt werden.
              </li>
            </ol>
          </section>

          <%!-- ===== § 9 DATENSCHUTZ ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              § 9 Datenschutz
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Der Umgang mit personenbezogenen Daten richtet sich nach unserer <a
                href="/datenschutz"
                class="text-primary hover:underline"
              >Datenschutzerklärung</a>,
              die Bestandteil dieser AGB ist.
            </p>
          </section>

          <%!-- ===== § 10 HAFTUNGSBESCHRÄNKUNG ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              § 10 Haftungsbeschränkung
            </h2>
            <ol class="list-decimal list-inside space-y-2 text-base-content/80 leading-relaxed">
              <li>
                Der Betreiber haftet unbeschränkt bei Vorsatz und grober Fahrlässigkeit sowie
                bei Verletzung von Leben, Körper und Gesundheit.
              </li>
              <li>
                Bei leichter Fahrlässigkeit haftet der Betreiber nur bei Verletzung
                wesentlicher Vertragspflichten (Kardinalpflichten), begrenzt auf den
                vorhersehbaren, vertragstypischen Schaden.
              </li>
              <li>
                Der Betreiber haftet nicht für die Richtigkeit der von Nutzern eingestellten
                Angaben und Inhalte.
              </li>
              <li>
                Der Betreiber übernimmt keine Haftung für die Erreichbarkeit oder
                Verfügbarkeit der Plattform. Kurzfristige Unterbrechungen für
                Wartungsarbeiten bleiben vorbehalten.
              </li>
            </ol>
          </section>

          <%!-- ===== § 11 ÄNDERUNG DER AGB ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              § 11 Änderung der AGB
            </h2>
            <ol class="list-decimal list-inside space-y-2 text-base-content/80 leading-relaxed">
              <li>
                Der Betreiber behält sich vor, diese AGB jederzeit zu ändern. Nutzer werden
                über Änderungen bei der nächsten Anmeldung informiert und müssen den
                geänderten AGB zustimmen, um die Plattform weiterhin nutzen zu können.
              </li>
              <li>
                Stimmt ein Nutzer den geänderten AGB nicht zu, wird das Nutzerkonto
                deaktiviert. Die gespeicherten Daten werden nach den gesetzlichen
                Aufbewahrungsfristen gelöscht.
              </li>
            </ol>
          </section>

          <%!-- ===== § 12 SCHLUSSBESTIMMUNGEN ===== --%>
          <section class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              § 12 Schlussbestimmungen
            </h2>
            <ol class="list-decimal list-inside space-y-2 text-base-content/80 leading-relaxed">
              <li>
                Es gilt das Recht der Bundesrepublik Deutschland unter Ausschluss des
                UN-Kaufrechts.
              </li>
              <li>
                Sollten einzelne Bestimmungen dieser AGB unwirksam sein oder werden, bleibt
                die Wirksamkeit der übrigen Bestimmungen davon unberührt.
              </li>
              <li>
                Gerichtsstand für alle Streitigkeiten ist Koblenz, sofern der Nutzer Kaufmann
                ist, eine juristische Person des öffentlichen Rechts oder ein
                öffentlich-rechtliches Sondervermögen.
              </li>
            </ol>
          </section>
        </article>
      </div>
    </Layouts.app>
    """
  end
end
