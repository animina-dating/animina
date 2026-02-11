defmodule AniminaWeb.PrivacyPolicyLive do
  @moduledoc """
  Privacy policy (Datenschutzerklärung) page for ANIMINA.
  """
  use AniminaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Datenschutzerklärung")}
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
              Datenschutzerklärung
            </h1>
            <p class="text-base-content/50 text-sm">Stand: 6. Februar 2026</p>
          </header>

          <%!-- ===== PRÄAMBEL ===== --%>
          <section id="m716" class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Präambel
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Mit der folgenden Datenschutzerklärung möchten wir Sie darüber aufklären,
              welche Arten Ihrer personenbezogenen Daten (nachfolgend auch kurz als
              "Daten" bezeichnet) wir zu welchen Zwecken und in welchem Umfang
              verarbeiten. Die Datenschutzerklärung gilt für alle von uns durchgeführten
              Verarbeitungen personenbezogener Daten, sowohl im Rahmen der Erbringung
              unserer Leistungen als auch insbesondere auf unseren Webseiten, in mobilen
              Applikationen sowie innerhalb externer Onlinepräsenzen, wie z.&nbsp;B. unserer
              Social-Media-Profile (nachfolgend zusammenfassend bezeichnet als
              "Onlineangebot").
            </p>
            <p class="text-base-content/80">
              Die verwendeten Begriffe sind nicht geschlechtsspezifisch.
            </p>

            <div class="bg-primary/5 border border-primary/20 rounded-lg p-4">
              <p class="text-base-content/90 leading-relaxed">
                <strong>Ein ehrliches Wort vorab:</strong>
                Eine Dating-Plattform funktioniert nur, wenn Menschen etwas von sich
                preisgeben — z.B. Alter, Wohnort, Interessen, Fotos, was sie sich von einem
                Partner wünschen. Das liegt in der Natur der Sache. Wir gehen mit diesen
                Daten so verantwortungsvoll um, wie wir können: eigene Server in Deutschland,
                keine Weitergabe an Dritte. Aber wenn du grundsätzlich ein ungutes Gefühl
                dabei hast, persönliche Informationen auf einer Online-Plattform zu teilen,
                dann ist eine Dating-App — egal welche — wahrscheinlich nicht das Richtige
                für dich. Und das ist völlig in Ordnung.
              </p>
            </div>
          </section>

          <%!-- ===== INHALTSÜBERSICHT ===== --%>
          <section class="bg-base-200/50 rounded-xl p-6 space-y-4">
            <h2 class="text-xl font-medium text-base-content">Inhaltsübersicht</h2>

            <div class="grid sm:grid-cols-2 gap-x-8 gap-y-1 text-sm">
              <div class="space-y-1">
                <p class="font-semibold text-base-content/60 uppercase text-xs tracking-wider pt-2">
                  Allgemein
                </p>
                <a href="#m3" class="block text-primary hover:underline">Verantwortlicher</a>
                <a href="#mOverview" class="block text-primary hover:underline">
                  Übersicht der Verarbeitungen
                </a>
                <a href="#m2427" class="block text-primary hover:underline">
                  Maßgebliche Rechtsgrundlagen
                </a>
                <a href="#m27" class="block text-primary hover:underline">Sicherheitsmaßnahmen</a>
                <a href="#m25" class="block text-primary hover:underline">
                  Übermittlung personenbezogener Daten
                </a>
                <a href="#m24" class="block text-primary hover:underline">
                  Internationale Datentransfers
                </a>
                <a href="#m12" class="block text-primary hover:underline">
                  Datenspeicherung und Löschung
                </a>
                <a href="#m10" class="block text-primary hover:underline">
                  Rechte der betroffenen Personen
                </a>

                <p class="font-semibold text-base-content/60 uppercase text-xs tracking-wider pt-4">
                  ANIMINA-Plattform
                </p>
                <a href="#mArt9" class="block text-primary hover:underline">
                  Besondere Datenkategorien (Art.&nbsp;9)
                </a>
                <a href="#mPhone" class="block text-primary hover:underline">Telefonnummer</a>
                <a href="#mLocation" class="block text-primary hover:underline">Standortdaten</a>
                <a href="#mBirthday" class="block text-primary hover:underline">
                  Geburtsdatum und Alter
                </a>
                <a href="#mHeight" class="block text-primary hover:underline">Körpergröße</a>
                <a href="#mMatching" class="block text-primary hover:underline">
                  Matching und Profiling
                </a>
                <a href="#mReferral" class="block text-primary hover:underline">Empfehlungssystem</a>
              </div>

              <div class="space-y-1">
                <p class="font-semibold text-base-content/60 uppercase text-xs tracking-wider pt-2">
                  Fotos &amp; Konto
                </p>
                <a href="#mPhotos" class="block text-primary hover:underline">Profilfotos</a>
                <a href="#mPhotoAI" class="block text-primary hover:underline">
                  Automatisierte Fotomoderation
                </a>
                <a href="#mAccountStates" class="block text-primary hover:underline">
                  Kontostatus und Soft-Delete
                </a>
                <a href="#mPortability" class="block text-primary hover:underline">Datenexport</a>
                <a href="#mAdminAccess" class="block text-primary hover:underline">
                  Admin- und Moderatorzugriff
                </a>

                <p class="font-semibold text-base-content/60 uppercase text-xs tracking-wider pt-4">
                  Infrastruktur &amp; Kommunikation
                </p>
                <a href="#mHosting" class="block text-primary hover:underline">Hosting</a>
                <a href="#mEmail" class="block text-primary hover:underline">E-Mail-Versand</a>
                <a href="#mTransactional" class="block text-primary hover:underline">
                  Transaktionale E-Mails
                </a>

                <p class="font-semibold text-base-content/60 uppercase text-xs tracking-wider pt-4">
                  Weitere Bestimmungen
                </p>
                <a href="#m317" class="block text-primary hover:underline">
                  Geschäftliche Leistungen
                </a>
                <a href="#m225" class="block text-primary hover:underline">Webhosting</a>
                <a href="#m134" class="block text-primary hover:underline">Cookies</a>
                <a href="#m367" class="block text-primary hover:underline">
                  Registrierung &amp; Nutzerkonto
                </a>
                <a href="#m432" class="block text-primary hover:underline">Community Funktionen</a>
                <a href="#m104" class="block text-primary hover:underline">Blogs</a>
                <a href="#m182" class="block text-primary hover:underline">
                  Kontakt- und Anfrageverwaltung
                </a>
                <a href="#m17" class="block text-primary hover:underline">Newsletter</a>
                <a href="#m15" class="block text-primary hover:underline">
                  Änderung und Aktualisierung
                </a>
                <a href="#m42" class="block text-primary hover:underline">Begriffsdefinitionen</a>
              </div>
            </div>
          </section>

          <%!-- ===== VERANTWORTLICHER ===== --%>
          <section id="m3" class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Verantwortlicher
            </h2>
            <div class="bg-base-200/50 rounded-lg p-4">
              <p class="text-base-content/80">
                Stefan Wintermeyer<br />Johannes-Müller-Str. 10<br />56068 Koblenz
              </p>
              <p class="text-base-content/80 mt-2">
                E-Mail:
                <a href="mailto:sw@wintermeyer-consulting.de" class="text-primary hover:underline">
                  sw@wintermeyer-consulting.de
                </a>
              </p>
            </div>
          </section>

          <%!-- ===== ÜBERSICHT ===== --%>
          <section id="mOverview" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Übersicht der Verarbeitungen
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Die nachfolgende Übersicht fasst die Arten der verarbeiteten Daten und die
              Zwecke ihrer Verarbeitung zusammen und verweist auf die betroffenen Personen.
            </p>

            <div class="grid sm:grid-cols-3 gap-4">
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="text-sm font-semibold text-base-content mb-2">
                  Arten der verarbeiteten Daten
                </h3>
                <ul class="text-sm text-base-content/70 space-y-1 list-disc list-inside">
                  <li>Bestandsdaten</li>
                  <li>Zahlungsdaten</li>
                  <li>Kontaktdaten</li>
                  <li>Inhaltsdaten</li>
                  <li>Vertragsdaten</li>
                  <li>Nutzungsdaten</li>
                  <li>Meta-/Kommunikationsdaten</li>
                  <li>Protokolldaten</li>
                  <li>Besondere Kategorien (Geschlecht, sexuelle Orientierung)</li>
                </ul>
              </div>

              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="text-sm font-semibold text-base-content mb-2">Betroffene Personen</h3>
                <ul class="text-sm text-base-content/70 space-y-1 list-disc list-inside">
                  <li>Leistungsempfänger</li>
                  <li>Interessenten</li>
                  <li>Kommunikationspartner</li>
                  <li>Nutzer</li>
                  <li>Geschäftspartner</li>
                </ul>
              </div>

              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="text-sm font-semibold text-base-content mb-2">Zwecke der Verarbeitung</h3>
                <ul class="text-sm text-base-content/70 space-y-1 list-disc list-inside">
                  <li>Vertragliche Leistungen</li>
                  <li>Kommunikation</li>
                  <li>Sicherheitsmaßnahmen</li>
                  <li>Direktmarketing</li>
                  <li>Organisationsverfahren</li>
                  <li>Feedback</li>
                  <li>Onlineangebot</li>
                  <li>IT-Infrastruktur</li>
                  <li>Geschäftsprozesse</li>
                  <li>Partnervorschläge/Matching</li>
                </ul>
              </div>
            </div>
          </section>

          <%!-- ===== RECHTSGRUNDLAGEN ===== --%>
          <section id="m2427" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Maßgebliche Rechtsgrundlagen
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              <strong>Maßgebliche Rechtsgrundlagen nach der DSGVO:</strong> Im Folgenden
              erhalten Sie eine Übersicht der Rechtsgrundlagen der DSGVO, auf deren Basis
              wir personenbezogene Daten verarbeiten. Bitte nehmen Sie zur Kenntnis, dass
              neben den Regelungen der DSGVO nationale Datenschutzvorgaben in Ihrem bzw.
              unserem Wohn- oder Sitzland gelten können. Sollten ferner im Einzelfall
              speziellere Rechtsgrundlagen maßgeblich sein, teilen wir Ihnen diese in der
              Datenschutzerklärung mit.
            </p>

            <dl class="space-y-4">
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">
                  Einwilligung (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;a DSGVO)
                </dt>
                <dd class="text-base-content/70 mt-1">
                  Die betroffene Person hat ihre Einwilligung in die Verarbeitung der sie
                  betreffenden personenbezogenen Daten für einen spezifischen Zweck oder
                  mehrere bestimmte Zwecke gegeben.
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">
                  Ausdrückliche Einwilligung (Art.&nbsp;9 Abs.&nbsp;2 lit.&nbsp;a DSGVO)
                </dt>
                <dd class="text-base-content/70 mt-1">
                  Für die Verarbeitung besonderer Kategorien personenbezogener Daten (z.&nbsp;B.
                  Geschlecht, sexuelle Orientierung) holen wir Ihre ausdrückliche
                  Einwilligung ein.
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">
                  Vertragserfüllung (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;b DSGVO)
                </dt>
                <dd class="text-base-content/70 mt-1">
                  Die Verarbeitung ist für die Erfüllung eines Vertrags, dessen
                  Vertragspartei die betroffene Person ist, oder zur Durchführung
                  vorvertraglicher Maßnahmen erforderlich.
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">
                  Rechtliche Verpflichtung (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;c DSGVO)
                </dt>
                <dd class="text-base-content/70 mt-1">
                  Die Verarbeitung ist zur Erfüllung einer rechtlichen Verpflichtung
                  erforderlich, der der Verantwortliche unterliegt.
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">
                  Berechtigte Interessen (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;f DSGVO)
                </dt>
                <dd class="text-base-content/70 mt-1">
                  Die Verarbeitung ist zur Wahrung der berechtigten Interessen des
                  Verantwortlichen oder eines Dritten notwendig, vorausgesetzt, dass die
                  Interessen, Grundrechte und Grundfreiheiten der betroffenen Person nicht
                  überwiegen.
                </dd>
              </div>
            </dl>

            <p class="text-base-content/80 leading-relaxed">
              <strong>Nationale Datenschutzregelungen in Deutschland:</strong> Zusätzlich
              zu den Datenschutzregelungen der DSGVO gelten nationale Regelungen zum
              Datenschutz in Deutschland. Hierzu gehört insbesondere das Gesetz zum Schutz
              vor Missbrauch personenbezogener Daten bei der Datenverarbeitung
              (Bundesdatenschutzgesetz – BDSG). Das BDSG enthält insbesondere
              Spezialregelungen zum Recht auf Auskunft, zum Recht auf Löschung, zum
              Widerspruchsrecht, zur Verarbeitung besonderer Kategorien personenbezogener
              Daten, zur Verarbeitung für andere Zwecke und zur Übermittlung sowie
              automatisierten Entscheidungsfindung im Einzelfall einschließlich Profiling.
              Ferner können Landesdatenschutzgesetze der einzelnen Bundesländer zur
              Anwendung gelangen.
            </p>
          </section>

          <%!-- ===== SICHERHEITSMASSNAHMEN ===== --%>
          <section id="m27" class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Sicherheitsmaßnahmen
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Wir treffen nach Maßgabe der gesetzlichen Vorgaben unter Berücksichtigung
              des Stands der Technik, der Implementierungskosten und der Art, des Umfangs,
              der Umstände und der Zwecke der Verarbeitung sowie der unterschiedlichen
              Eintrittswahrscheinlichkeiten und des Ausmaßes der Bedrohung der Rechte und
              Freiheiten natürlicher Personen geeignete technische und organisatorische
              Maßnahmen, um ein dem Risiko angemessenes Schutzniveau zu gewährleisten.
            </p>
            <p class="text-base-content/80 leading-relaxed">
              Zu den Maßnahmen gehören insbesondere die Sicherung der Vertraulichkeit,
              Integrität und Verfügbarkeit von Daten durch Kontrolle des physischen und
              elektronischen Zugangs zu den Daten als auch des sie betreffenden Zugriffs,
              der Eingabe, der Weitergabe, der Sicherung der Verfügbarkeit und ihrer
              Trennung. Des Weiteren haben wir Verfahren eingerichtet, die eine
              Wahrnehmung von Betroffenenrechten, die Löschung von Daten und Reaktionen
              auf die Gefährdung der Daten gewährleisten. Ferner berücksichtigen wir den
              Schutz personenbezogener Daten bereits bei der Entwicklung bzw. Auswahl von
              Hardware, Software sowie Verfahren entsprechend dem Prinzip des
              Datenschutzes, durch Technikgestaltung und durch datenschutzfreundliche
              Voreinstellungen.
            </p>
            <div class="bg-base-200/50 rounded-lg p-4">
              <h3 class="font-semibold text-base-content mb-2">
                TLS-/SSL-Verschlüsselung (HTTPS)
              </h3>
              <p class="text-base-content/70 text-sm leading-relaxed">
                Um die Daten der Nutzer, die über unsere Online-Dienste übertragen werden,
                vor unerlaubten Zugriffen zu schützen, setzen wir auf die
                TLS-/SSL-Verschlüsselungstechnologie. Diese Technologien verschlüsseln die
                Informationen, die zwischen der Website oder App und dem Browser des Nutzers
                übertragen werden. Wenn eine Website durch ein SSL-/TLS-Zertifikat gesichert
                ist, wird dies durch die Anzeige von HTTPS in der URL signalisiert.
              </p>
            </div>
          </section>

          <%!-- ===== ÜBERMITTLUNG ===== --%>
          <section id="m25" class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Übermittlung von personenbezogenen Daten
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Im Rahmen unserer Verarbeitung von personenbezogenen Daten kommt es vor,
              dass diese an andere Stellen, Unternehmen, rechtlich selbstständige
              Organisationseinheiten oder Personen übermittelt beziehungsweise ihnen
              gegenüber offengelegt werden. Zu den Empfängern dieser Daten können z.&nbsp;B.
              mit IT-Aufgaben beauftragte Dienstleister gehören oder Anbieter von Diensten
              und Inhalten, die in eine Website eingebunden sind. In solchen Fällen
              beachten wir die gesetzlichen Vorgaben und schließen insbesondere
              entsprechende Verträge bzw. Vereinbarungen, die dem Schutz Ihrer Daten
              dienen, mit den Empfängern Ihrer Daten ab.
            </p>
          </section>

          <%!-- ===== INTERNATIONALE DATENTRANSFERS ===== --%>
          <section id="m24" class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Internationale Datentransfers
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Datenverarbeitung in Drittländern: Sofern wir Daten in ein Drittland (d.&nbsp;h.
              außerhalb der Europäischen Union (EU) oder des Europäischen Wirtschaftsraums
              (EWR)) übermitteln oder dies im Rahmen der Nutzung von Diensten Dritter oder
              der Offenlegung bzw. Übermittlung von Daten an andere Personen, Stellen oder
              Unternehmen geschieht, erfolgt dies stets im Einklang mit den gesetzlichen
              Vorgaben.
            </p>
            <p class="text-base-content/80 leading-relaxed">
              Für Datenübermittlungen in die USA stützen wir uns vorrangig auf das Data
              Privacy Framework (DPF), welches durch einen Angemessenheitsbeschluss der
              EU-Kommission vom 10.07.2023 als sicherer Rechtsrahmen anerkannt wurde.
              Zusätzlich haben wir mit den jeweiligen Anbietern Standardvertragsklauseln
              abgeschlossen, die den Vorgaben der EU-Kommission entsprechen und
              vertragliche Verpflichtungen zum Schutz Ihrer Daten festlegen.
            </p>
            <p class="text-base-content/80 leading-relaxed">
              Diese zweifache Absicherung gewährleistet einen umfassenden Schutz Ihrer
              Daten: Das DPF bildet die primäre Schutzebene, während die
              Standardvertragsklauseln als zusätzliche Sicherheit dienen.
            </p>
            <p class="text-sm text-base-content/60">
              Weitere Informationen:
              <a
                href="https://www.dataprivacyframework.gov/"
                target="_blank"
                rel="noopener noreferrer"
                class="text-primary hover:underline"
              >
                dataprivacyframework.gov
              </a>
              |
              <a
                href="https://commission.europa.eu/law/law-topic/data-protection/international-dimension-data-protection_en?prefLang=de"
                target="_blank"
                rel="noopener noreferrer"
                class="text-primary hover:underline"
              >
                EU-Kommission Datentransfers
              </a>
            </p>
          </section>

          <%!-- ===== DATENSPEICHERUNG UND LÖSCHUNG ===== --%>
          <section id="m12" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Allgemeine Informationen zur Datenspeicherung und Löschung
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Wir löschen personenbezogene Daten, die wir verarbeiten, gemäß den
              gesetzlichen Bestimmungen, sobald die zugrundeliegenden Einwilligungen
              widerrufen werden oder keine weiteren rechtlichen Grundlagen für die
              Verarbeitung bestehen. Ausnahmen bestehen, wenn gesetzliche Pflichten oder
              besondere Interessen eine längere Aufbewahrung erfordern.
            </p>

            <h3 class="text-lg font-medium text-base-content">
              Aufbewahrungsfristen nach deutschem Recht
            </h3>
            <div class="grid sm:grid-cols-2 gap-3">
              <div class="bg-base-200/50 rounded-lg p-4">
                <p class="text-2xl font-bold text-primary">10 Jahre</p>
                <p class="text-sm text-base-content/70 mt-1">
                  Bücher, Aufzeichnungen, Jahresabschlüsse, Inventare, Lageberichte,
                  Eröffnungsbilanz (§&nbsp;147 Abs.&nbsp;1 Nr.&nbsp;1 AO, §&nbsp;14b UStG, §&nbsp;257 Abs.&nbsp;1 Nr.&nbsp;1 HGB)
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <p class="text-2xl font-bold text-primary">8 Jahre</p>
                <p class="text-sm text-base-content/70 mt-1">
                  Buchungsbelege, Rechnungen, Kostenbelege (§&nbsp;147 Abs.&nbsp;1 Nr.&nbsp;4 AO, §&nbsp;257
                  Abs.&nbsp;1 Nr.&nbsp;4 HGB)
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <p class="text-2xl font-bold text-primary">6 Jahre</p>
                <p class="text-sm text-base-content/70 mt-1">
                  Geschäftsbriefe, steuerrelevante Unterlagen, Lohnabrechnungsunterlagen
                  (§&nbsp;147 Abs.&nbsp;1 Nr.&nbsp;2, 3, 5 AO, §&nbsp;257 Abs.&nbsp;1 Nr.&nbsp;2 u.&nbsp;3 HGB)
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <p class="text-2xl font-bold text-primary">3 Jahre</p>
                <p class="text-sm text-base-content/70 mt-1">
                  Gewährleistungs- und Schadensersatzansprüche – reguläre gesetzliche
                  Verjährungsfrist (§§&nbsp;195, 199 BGB)
                </p>
              </div>
            </div>

            <p class="text-sm text-base-content/60 leading-relaxed">
              Beginnt eine Frist nicht ausdrücklich zu einem bestimmten Datum und beträgt
              sie mindestens ein Jahr, so startet sie automatisch am Ende des
              Kalenderjahres, in dem das fristauslösende Ereignis eingetreten ist.
            </p>
          </section>

          <%!-- ===== RECHTE DER BETROFFENEN ===== --%>
          <section id="m10" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Rechte der betroffenen Personen
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Ihnen stehen als Betroffene nach der DSGVO verschiedene Rechte zu, die sich
              insbesondere aus Art.&nbsp;15 bis 21 DSGVO ergeben:
            </p>

            <div class="space-y-3">
              <div class="border-s-4 border-primary ps-4">
                <h3 class="font-semibold text-base-content">Widerspruchsrecht</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Sie haben das Recht, jederzeit gegen die Verarbeitung der Sie betreffenden
                  personenbezogenen Daten Widerspruch einzulegen, einschließlich gegen
                  Profiling und Direktwerbung (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;e oder f DSGVO).
                </p>
              </div>
              <div class="border-s-4 border-primary ps-4">
                <h3 class="font-semibold text-base-content">Widerrufsrecht bei Einwilligungen</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Sie haben das Recht, erteilte Einwilligungen jederzeit zu widerrufen.
                </p>
              </div>
              <div class="border-s-4 border-primary ps-4">
                <h3 class="font-semibold text-base-content">Auskunftsrecht</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Sie haben das Recht auf Bestätigung, ob Daten verarbeitet werden, und auf
                  Auskunft über diese Daten sowie auf Kopie der Daten.
                </p>
              </div>
              <div class="border-s-4 border-primary ps-4">
                <h3 class="font-semibold text-base-content">Recht auf Berichtigung</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Sie haben das Recht, die Vervollständigung oder Berichtigung unrichtiger
                  Daten zu verlangen.
                </p>
              </div>
              <div class="border-s-4 border-primary ps-4">
                <h3 class="font-semibold text-base-content">
                  Recht auf Löschung und Einschränkung
                </h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Sie haben das Recht, die unverzügliche Löschung oder Einschränkung der
                  Verarbeitung Ihrer Daten zu verlangen.
                </p>
              </div>
              <div class="border-s-4 border-primary ps-4">
                <h3 class="font-semibold text-base-content">Recht auf Datenübertragbarkeit</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Sie haben das Recht, Ihre Daten in einem strukturierten, gängigen und
                  maschinenlesbaren Format zu erhalten oder deren Übermittlung an einen
                  anderen Verantwortlichen zu fordern.
                </p>
              </div>
              <div class="border-s-4 border-primary ps-4">
                <h3 class="font-semibold text-base-content">Beschwerde bei Aufsichtsbehörde</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Sie haben das Recht auf Beschwerde bei einer Aufsichtsbehörde, insbesondere
                  in dem Mitgliedstaat Ihres gewöhnlichen Aufenthaltsorts.
                </p>
              </div>
            </div>
          </section>

          <%!-- ========================================= --%>
          <%!-- ===== ANIMINA-SPEZIFISCHE ABSCHNITTE ===== --%>
          <%!-- ========================================= --%>

          <div class="border-t-2 border-primary/20 pt-6">
            <p class="text-xs font-semibold text-primary uppercase tracking-wider mb-6">
              ANIMINA-spezifische Datenschutzhinweise
            </p>
          </div>

          <%!-- ===== ART. 9 BESONDERE KATEGORIEN ===== --%>
          <section id="mArt9" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Besondere Kategorien personenbezogener Daten (Art.&nbsp;9 DSGVO)
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Im Rahmen der Nutzung unserer Dating-Plattform verarbeiten wir besondere
              Kategorien personenbezogener Daten im Sinne von Art.&nbsp;9 DSGVO:
            </p>

            <div class="space-y-3">
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content">Geschlecht</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Bei der Registrierung geben Sie Ihr Geschlecht an (männlich, weiblich,
                  divers). Diese Angabe dient der Profilerstellung und dem Matching mit
                  anderen Nutzern.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content">Sexuelle Orientierung (abgeleitet)</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Aus Ihren Angaben zu den bevorzugten Partnergeschlechtern kann auf Ihre
                  sexuelle Orientierung geschlossen werden. Diese Angabe dient ausschließlich
                  dazu, Ihnen passende Partnervorschläge anzuzeigen.
                </p>
              </div>
            </div>

            <div class="bg-primary/5 border border-primary/20 rounded-lg p-4">
              <p class="text-sm text-base-content/80">
                <strong>Rechtsgrundlage:</strong>
                Ausdrückliche Einwilligung gemäß Art.&nbsp;9 Abs.&nbsp;2 lit.&nbsp;a DSGVO. Sie erteilen
                diese durch die aktive Angabe dieser Daten bei der Registrierung und die
                Bestätigung der Datenschutzerklärung. Sie können Ihre Einwilligung jederzeit
                widerrufen, indem Sie Ihr Konto löschen.
              </p>
            </div>
          </section>

          <%!-- ===== TELEFONNUMMER ===== --%>
          <section id="mPhone" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Telefonnummer / Mobilnummer
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Bei der Registrierung erheben wir Ihre Mobiltelefonnummer. Die Nummer wird
              im internationalen E.164-Format gespeichert (z.&nbsp;B. +491514567890).
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Zweck:</dt>
                <dd class="text-base-content/70 inline">
                  Kontoverifizierung, Zustellung eines Bestätigungs-PIN per SMS, Schutz vor
                  Mehrfachregistrierungen.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlage:</dt>
                <dd class="text-base-content/70 inline">
                  Vertragserfüllung (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;b DSGVO).
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Speicherdauer:</dt>
                <dd class="text-base-content/70 inline">
                  Für die Dauer des Nutzungsvertrags. Nach Kontolöschung gemäß den
                  allgemeinen Löschfristen.
                </dd>
              </div>
            </dl>
          </section>

          <%!-- ===== STANDORTDATEN ===== --%>
          <section id="mLocation" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Standortdaten / Postleitzahlen
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Sie können bis zu vier Postleitzahlen (PLZ) als Standorte angeben. Zu jeder
              PLZ wird das zugehörige Land gespeichert.
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Zweck:</dt>
                <dd class="text-base-content/70 inline">
                  Umkreissuche für Partnervorschläge. Die Zuordnung von PLZ zu geografischen
                  Koordinaten erfolgt über eine lokale Geodatenbank auf unseren Servern – es
                  werden keine Standortdaten an Dritte übermittelt.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Suchradius:</dt>
                <dd class="text-base-content/70 inline">
                  Sie legen einen individuellen Suchradius (in km) fest, innerhalb dessen
                  Partnervorschläge angezeigt werden.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlage:</dt>
                <dd class="text-base-content/70 inline">
                  Vertragserfüllung (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;b DSGVO).
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Speicherdauer:</dt>
                <dd class="text-base-content/70 inline">Für die Dauer des Nutzungsvertrags.</dd>
              </div>
            </dl>
          </section>

          <%!-- ===== GEBURTSDATUM ===== --%>
          <section id="mBirthday" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Geburtsdatum und Alter
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Bei der Registrierung geben Sie Ihr Geburtsdatum an. Daraus wird Ihr Alter
              berechnet.
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Zweck:</dt>
                <dd class="text-base-content/70 inline">
                  Sicherstellung, dass alle Nutzer mindestens 18 Jahre alt sind (gesetzliche
                  Anforderung). Ermittlung des Alters für Partnervorschläge gemäß Ihren
                  Altersgrenzen.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlage:</dt>
                <dd class="text-base-content/70 inline">
                  Vertragserfüllung (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;b DSGVO) sowie rechtliche
                  Verpflichtung (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;c DSGVO) hinsichtlich der
                  Altersprüfung.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Speicherdauer:</dt>
                <dd class="text-base-content/70 inline">Für die Dauer des Nutzungsvertrags.</dd>
              </div>
            </dl>
          </section>

          <%!-- ===== KÖRPERGRÖSSE ===== --%>
          <section id="mHeight" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Körpergröße
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Sie geben bei der Registrierung Ihre Körpergröße in Zentimetern an
              (80–225&nbsp;cm).
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Zweck:</dt>
                <dd class="text-base-content/70 inline">
                  Anzeige im Profil und Verwendung für Partnervorschläge gemäß Ihren
                  Größenpräferenzen.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlage:</dt>
                <dd class="text-base-content/70 inline">
                  Vertragserfüllung (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;b DSGVO).
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Speicherdauer:</dt>
                <dd class="text-base-content/70 inline">Für die Dauer des Nutzungsvertrags.</dd>
              </div>
            </dl>
          </section>

          <%!-- ===== MATCHING ===== --%>
          <section id="mMatching" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Partnervorstellungen und Matching (Profiling)
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Sie legen bei der Registrierung Partnervorstellungen fest: bevorzugte(s)
              Geschlecht(er), Altersbereich, Größenbereich und Suchradius.
            </p>

            <div class="bg-base-200/50 rounded-lg p-4 space-y-3">
              <h3 class="font-semibold text-base-content">Art der automatisierten Verarbeitung</h3>
              <p class="text-sm text-base-content/70">
                Auf Basis dieser Angaben und Ihrer Profildaten (Standort, Alter, Geschlecht,
                Größe) erstellen wir regelbasierte Partnervorschläge. Es handelt sich um ein
                rein regelbasiertes System – es kommen <strong>keine KI-Modelle, kein
                  Machine Learning</strong> und keine intransparenten Algorithmen zum Einsatz.
              </p>
              <h3 class="font-semibold text-base-content text-sm mt-3">Matching-Regeln</h3>
              <ul class="text-sm text-base-content/70 list-disc list-inside space-y-1">
                <li>Übereinstimmung der Geschlechtspräferenzen (gegenseitig)</li>
                <li>Alter innerhalb des jeweils angegebenen Bereichs (gegenseitig)</li>
                <li>Größe innerhalb des jeweils angegebenen Bereichs (gegenseitig)</li>
                <li>Entfernung innerhalb des angegebenen Suchradius</li>
              </ul>
            </div>

            <div class="bg-primary/5 border border-primary/20 rounded-lg p-4 space-y-2">
              <p class="text-sm text-base-content/80">
                <strong>Art.&nbsp;22 DSGVO (automatisierte Entscheidung):</strong>
                Das Matching stellt eine automatisierte Vorauswahl dar, die bestimmt, welche
                Profile Ihnen angezeigt werden. Es handelt sich jedoch nicht um eine
                Entscheidung mit rechtlicher Wirkung oder vergleichbar erheblicher
                Beeinträchtigung, da lediglich die Anzeige von Profilen gesteuert wird.
                Die endgültige Kontaktentscheidung liegt stets bei Ihnen.
              </p>
              <p class="text-sm text-base-content/80">
                <strong>Rechtsgrundlage:</strong>
                Vertragserfüllung (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;b DSGVO).
              </p>
            </div>
          </section>

          <%!-- ===== REFERRAL ===== --%>
          <section id="mReferral" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Empfehlungssystem (Referral)
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Bei der Registrierung können Sie optional einen Empfehlungscode (Referral
              Code) eingeben. In diesem Fall wird die Beziehung zwischen dem einladenden
              und dem eingeladenen Nutzer gespeichert.
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Zweck:</dt>
                <dd class="text-base-content/70 inline">
                  Nachvollziehbarkeit von Empfehlungen, ggf. zukünftige Bonusprogramme.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Gespeicherte Daten:</dt>
                <dd class="text-base-content/70 inline">
                  Referral-Code, Zuordnung Einladender/Eingeladener.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlage:</dt>
                <dd class="text-base-content/70 inline">
                  Vertragserfüllung (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;b DSGVO).
                </dd>
              </div>
            </dl>
          </section>

          <%!-- ===== PROFILFOTOS ===== --%>
          <section id="mPhotos" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Profilfotos
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Sie können Profilfotos hochladen, die anderen Nutzern gemäß Ihren
              Profileinstellungen angezeigt werden.
            </p>
            <div class="space-y-3">
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Speicherung</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Fotos werden ausschließlich auf unseren eigenen physischen Servern in
                  Deutschland gespeichert. Keine Übermittlung an Drittanbieter.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Foto-Metadaten (EXIF-Daten)</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Hochgeladene Fotos können Metadaten enthalten (z.&nbsp;B. GPS-Koordinaten,
                  Kamerainformationen, Zeitstempel). Der Umgang mit diesen Metadaten wird
                  derzeit festgelegt.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Sichtbarkeit &amp; Löschung</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Die Sichtbarkeit richtet sich nach Ihren Profileinstellungen. Fotos werden
                  zusammen mit dem Nutzerkonto gelöscht (siehe <a
                    href="#mAccountStates"
                    class="text-primary hover:underline"
                  >
                    Kontostatus und Soft-Delete</a>).
                </p>
              </div>
              <div class="bg-primary/5 border border-primary/20 rounded-lg p-4">
                <p class="text-sm text-base-content/80">
                  <strong>Keine Gesichtserkennung:</strong>
                  Es findet keine biometrische Identifizierung oder Gesichtserkennung statt.
                  Fotos werden nicht zur Ableitung biometrischer Daten im Sinne von Art.&nbsp;9
                  DSGVO verwendet.
                </p>
              </div>
            </div>
            <p class="text-sm text-base-content/60">
              <strong>Rechtsgrundlage:</strong>
              Vertragserfüllung (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;b DSGVO).
            </p>
          </section>

          <%!-- ===== FOTOMODERATION ===== --%>
          <section id="mPhotoAI" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Automatisierte Fotomoderation
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Hochgeladene Profilfotos werden durch ein eigenes KI-System automatisiert
              geprüft, um die Einhaltung unserer Nutzungsrichtlinien sicherzustellen
              (z.&nbsp;B. keine anstößigen Inhalte, keine urheberrechtlich geschützten Bilder).
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-3 text-sm">
              <div>
                <dt class="font-semibold text-base-content">Verarbeitung</dt>
                <dd class="text-base-content/70 mt-1">
                  Die KI-gestützte Moderation läuft ausschließlich auf unseren eigenen Servern
                  in Deutschland. Keine Fotos werden an externe Dienste übermittelt.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content">Art.&nbsp;22 DSGVO</dt>
                <dd class="text-base-content/70 mt-1">
                  Wird ein Foto durch die automatisierte Moderation abgelehnt, kann dies
                  Auswirkungen auf Ihr Nutzungserlebnis haben (z.&nbsp;B. eingeschränkte
                  Profilsichtbarkeit). Sie haben das Recht, die Entscheidung durch einen
                  menschlichen Moderator überprüfen zu lassen. Kontaktieren Sie uns hierzu
                  unter der oben angegebenen E-Mail-Adresse.
                </dd>
              </div>
            </dl>
            <p class="text-sm text-base-content/60">
              <strong>Rechtsgrundlage:</strong>
              Berechtigte Interessen (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;f DSGVO) – Schutz der
              Plattform und der Nutzer vor unangemessenen Inhalten.
            </p>
          </section>

          <%!-- ===== KONTOSTATUS ===== --%>
          <section id="mAccountStates" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Kontostatus und Soft-Delete
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Ihr Nutzerkonto kann sich in folgenden Zuständen befinden:
            </p>
            <div class="grid sm:grid-cols-2 gap-3">
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Warteliste (Waitlist)</h3>
                <p class="text-xs text-base-content/70 mt-1">
                  Ihr Konto ist registriert, aber noch nicht für die volle Nutzung
                  freigeschaltet.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Normal</h3>
                <p class="text-xs text-base-content/70 mt-1">
                  Ihr Konto ist aktiv und voll nutzbar.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Ruhend (Hibernate)</h3>
                <p class="text-xs text-base-content/70 mt-1">
                  Sie haben Ihr Konto vorübergehend deaktiviert. Ihre Daten bleiben
                  gespeichert, Ihr Profil ist jedoch nicht sichtbar.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Archiviert (Soft-Delete)</h3>
                <p class="text-xs text-base-content/70 mt-1">
                  Sie haben die Löschung beantragt. 30-tägige Nachfrist zur Reaktivierung.
                  Danach endgültige Löschung.
                </p>
              </div>
            </div>
            <div class="bg-primary/5 border border-primary/20 rounded-lg p-4">
              <p class="text-sm text-base-content/80">
                <strong>Endgültige Löschung:</strong>
                Nach Ablauf der 30-tägigen Soft-Delete-Frist werden sämtliche
                personenbezogene Daten, einschließlich Profilfotos, Standortdaten,
                Nachrichten und Partnervorstellungen, endgültig gelöscht, sofern keine
                gesetzlichen Aufbewahrungspflichten entgegenstehen.
              </p>
            </div>
          </section>

          <%!-- ===== DATENEXPORT ===== --%>
          <section id="mPortability" class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Datenübertragbarkeit (Datenexport)
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Gemäß Art.&nbsp;20 DSGVO haben Sie das Recht, Ihre personenbezogenen Daten in
              einem strukturierten, gängigen und maschinenlesbaren Format zu erhalten.
            </p>
            <p class="text-base-content/80 leading-relaxed">
              Wir planen, eine In-App-Exportfunktion bereitzustellen. Bis diese verfügbar
              ist, können Sie einen Datenexport per E-Mail an
              <a
                href="mailto:sw@wintermeyer-consulting.de"
                class="text-primary hover:underline"
              >
                sw@wintermeyer-consulting.de
              </a>
              anfordern. Wir werden Ihrem Antrag innerhalb der gesetzlichen Frist nachkommen.
            </p>
          </section>

          <%!-- ===== ADMIN- UND MODERATORZUGRIFF ===== --%>
          <section id="mAdminAccess" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Admin- und Moderatorzugriff auf Nutzerdaten
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Zur Sicherstellung eines sicheren und regelkonformen Betriebs der Plattform
              können autorisierte Administratoren und Moderatoren auf bestimmte Nutzerdaten
              zugreifen.
            </p>
            <div class="space-y-3">
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Zugriffsberechtigte</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Administratoren und Moderatoren der Plattform, die vom Betreiber autorisiert
                  wurden. Die Anzahl der Berechtigten wird auf das notwendige Minimum
                  beschränkt.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Zugängliche Daten</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Profilinformationen, Profilfotos, Moodboard-Inhalte, Nachrichtenverläufe,
                  Standortdaten (Postleitzahlen) und Kontoinformationen.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Zweckbindung</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Der Zugriff erfolgt ausschließlich zu folgenden Zwecken: Moderation von
                  Inhalten, Sicherheit der Nutzer, Bearbeitung von Supportanfragen,
                  Betrugsbekämpfung sowie Erfüllung gesetzlicher Pflichten (z.&nbsp;B.
                  behördliche Anfragen).
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Protokollierung</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Zugriffe auf Nutzerdaten durch Administratoren werden in einem Audit-Log
                  protokolliert, um die Nachvollziehbarkeit und Überprüfbarkeit
                  sicherzustellen.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">
                  Löschung durch Administratoren
                </h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Administratoren können bei Verstößen gegen die Nutzungsbedingungen einzelne
                  Inhalte (Fotos, Nachrichten) oder ganze Nutzerkonten löschen. Betroffene
                  Nutzer werden über solche Maßnahmen informiert, sofern dies nicht
                  behördlichen Auflagen widerspricht.
                </p>
              </div>
            </div>
            <p class="text-sm text-base-content/60">
              <strong>Rechtsgrundlagen:</strong>
              Berechtigte Interessen (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;f DSGVO) –
              Sicherheit der Plattform und Schutz der Nutzer;
              Vertragserfüllung (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;b DSGVO) –
              Durchsetzung der Nutzungsbedingungen.
              Siehe auch unsere
              <a href="/agb" class="text-primary hover:underline">Allgemeinen Geschäftsbedingungen</a>
              (§ 5, § 6, § 7).
            </p>
          </section>

          <%!-- ===== HOSTING ===== --%>
          <section id="mHosting" class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Hosting und Infrastruktur
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              ANIMINA wird auf eigenen physischen Servern in Deutschland betrieben. Es
              werden keine Cloud-Dienste Dritter (wie AWS, Google Cloud, Azure o.&nbsp;Ä.) für
              das Hosting der Anwendung, der Datenbank oder der Nutzerdaten eingesetzt.
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Standort:</dt>
                <dd class="text-base-content/70 inline">Deutschland</dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Betrieb:</dt>
                <dd class="text-base-content/70 inline">Eigene physische Server</dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlage:</dt>
                <dd class="text-base-content/70 inline">
                  Berechtigte Interessen (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;f DSGVO).
                </dd>
              </div>
            </dl>
          </section>

          <%!-- ===== E-MAIL-VERSAND ===== --%>
          <section id="mEmail" class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              E-Mail-Versand
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Für den Versand von E-Mails nutzen wir ausschließlich einen lokal
              betriebenen Postfix-Mailserver auf unseren eigenen Servern in Deutschland.
              Es werden keine externen E-Mail-Dienste (wie SendGrid, Mailgun, Amazon SES
              o.&nbsp;Ä.) eingesetzt. Ihre E-Mail-Adresse wird nicht an Dritte übermittelt.
            </p>
          </section>

          <%!-- ===== TRANSAKTIONALE E-MAILS ===== --%>
          <section id="mTransactional" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Transaktionale E-Mails
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Wir versenden folgende transaktionale E-Mails im Zusammenhang mit Ihrem
              Nutzerkonto:
            </p>
            <div class="grid sm:grid-cols-2 gap-3">
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Bestätigungs-PIN</h3>
                <p class="text-xs text-base-content/70 mt-1">
                  Nach der Registrierung erhalten Sie eine E-Mail mit einem Bestätigungscode
                  zur Verifizierung Ihres Kontos.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Passwort zurücksetzen</h3>
                <p class="text-xs text-base-content/70 mt-1">
                  Auf Ihre Anfrage erhalten Sie einen Link zum Zurücksetzen Ihres Passworts.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Doppelregistrierung</h3>
                <p class="text-xs text-base-content/70 mt-1">
                  Falls eine Registrierung mit einer bereits vorhandenen E-Mail-Adresse
                  versucht wird, informieren wir den bestehenden Kontoinhaber.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Löschbestätigung</h3>
                <p class="text-xs text-base-content/70 mt-1">
                  Nach der endgültigen Löschung Ihres Kontos erhalten Sie eine
                  Bestätigungs-E-Mail.
                </p>
              </div>
            </div>
            <p class="text-sm text-base-content/60">
              <strong>Rechtsgrundlage:</strong>
              Vertragserfüllung (Art.&nbsp;6 Abs.&nbsp;1 S.&nbsp;1 lit.&nbsp;b DSGVO).
            </p>
          </section>

          <%!-- ========================================= --%>
          <%!-- ===== ALLGEMEINE BESTIMMUNGEN ===== --%>
          <%!-- ========================================= --%>

          <div class="border-t-2 border-base-300 pt-6">
            <p class="text-xs font-semibold text-base-content/50 uppercase tracking-wider mb-6">
              Weitere Bestimmungen
            </p>
          </div>

          <%!-- ===== GESCHÄFTLICHE LEISTUNGEN ===== --%>
          <section id="m317" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Geschäftliche Leistungen
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Wir verarbeiten Daten unserer Vertrags- und Geschäftspartner, z.&nbsp;B. Kunden
              und Interessenten (zusammenfassend als „Vertragspartner" bezeichnet), im
              Rahmen von vertraglichen und vergleichbaren Rechtsverhältnissen sowie damit
              verbundenen Maßnahmen und im Hinblick auf die Kommunikation mit den
              Vertragspartnern (oder vorvertraglich), etwa zur Beantwortung von Anfragen.
            </p>
            <p class="text-base-content/80 leading-relaxed">
              Wir verwenden diese Daten, um unsere vertraglichen Verpflichtungen zu
              erfüllen. Dazu gehören insbesondere die Pflichten zur Erbringung der
              vereinbarten Leistungen, etwaige Aktualisierungspflichten und Abhilfe bei
              Gewährleistungs- und sonstigen Leistungsstörungen. Wir löschen die Daten
              nach Ablauf gesetzlicher Gewährleistungs- und vergleichbarer Pflichten,
              d.&nbsp;h. grundsätzlich nach vier Jahren.
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Verarbeitete Datenarten:</dt>
                <dd class="text-base-content/70 inline">
                  Bestandsdaten, Zahlungsdaten, Kontaktdaten, Vertragsdaten.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Betroffene Personen:</dt>
                <dd class="text-base-content/70 inline">
                  Leistungsempfänger und Auftraggeber, Interessenten, Geschäfts- und
                  Vertragspartner.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Zwecke:</dt>
                <dd class="text-base-content/70 inline">
                  Erbringung vertraglicher Leistungen, Kommunikation, Organisations- und
                  Verwaltungsverfahren, Geschäftsprozesse.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlagen:</dt>
                <dd class="text-base-content/70 inline">
                  Vertragserfüllung (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;b DSGVO), Rechtliche Verpflichtung
                  (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;c DSGVO), Berechtigte Interessen (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;f DSGVO).
                </dd>
              </div>
            </dl>
          </section>

          <%!-- ===== WEBHOSTING ===== --%>
          <section id="m225" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Bereitstellung des Onlineangebots und Webhosting
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Wir verarbeiten die Daten der Nutzer, um ihnen unsere Online-Dienste zur
              Verfügung stellen zu können. Zu diesem Zweck verarbeiten wir die IP-Adresse
              des Nutzers, die notwendig ist, um die Inhalte und Funktionen unserer
              Online-Dienste an den Browser oder das Endgerät der Nutzer zu übermitteln.
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Verarbeitete Datenarten:</dt>
                <dd class="text-base-content/70 inline">
                  Nutzungsdaten, Meta-/Kommunikationsdaten, Protokolldaten.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Zwecke:</dt>
                <dd class="text-base-content/70 inline">
                  Bereitstellung des Onlineangebotes, IT-Infrastruktur, Sicherheitsmaßnahmen.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlagen:</dt>
                <dd class="text-base-content/70 inline">
                  Berechtigte Interessen (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;f DSGVO).
                </dd>
              </div>
            </dl>

            <h3 class="text-lg font-medium text-base-content mt-4">Weitere Hinweise</h3>
            <div class="space-y-3">
              <div class="bg-base-200/50 rounded-lg p-4">
                <h4 class="font-semibold text-base-content text-sm">Eigene Server</h4>
                <p class="text-sm text-base-content/70 mt-1">
                  Für die Bereitstellung unseres Onlineangebotes nutzen wir eigene physische
                  Server in Deutschland.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h4 class="font-semibold text-base-content text-sm">
                  Zugriffsdaten und Logfiles
                </h4>
                <p class="text-sm text-base-content/70 mt-1">
                  Der Zugriff auf unser Onlineangebot wird in Form von Server-Logfiles
                  protokolliert (Adresse und Name der abgerufenen Webseiten, Datum/Uhrzeit,
                  übertragene Datenmengen, Browsertyp, Betriebssystem, Referrer URL,
                  IP-Adresse). Die Logfiles dienen der Sicherheit und Stabilität der Server.
                </p>
                <p class="text-xs text-base-content/50 mt-2">
                  <strong>Löschung:</strong> Logfile-Informationen werden maximal 30 Tage
                  gespeichert und danach gelöscht oder anonymisiert.
                </p>
              </div>
            </div>
          </section>

          <%!-- ===== COOKIES ===== --%>
          <section id="m134" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Einsatz von Cookies
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Unter dem Begriff „Cookies" werden Funktionen, die Informationen auf
              Endgeräten der Nutzer speichern und aus ihnen auslesen, verstanden. Wir
              verwenden Cookies gemäß den gesetzlichen Vorschriften. Dazu holen wir, wenn
              erforderlich, vorab die Zustimmung der Nutzer ein. Die Einwilligung kann
              jederzeit widerrufen werden.
            </p>

            <div class="grid sm:grid-cols-2 gap-3">
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">
                  Temporäre Cookies (Session)
                </h3>
                <p class="text-xs text-base-content/70 mt-1">
                  Werden spätestens gelöscht, nachdem ein Nutzer das Onlineangebot verlassen
                  und den Browser geschlossen hat.
                </p>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <h3 class="font-semibold text-base-content text-sm">Permanente Cookies</h3>
                <p class="text-xs text-base-content/70 mt-1">
                  Bleiben auch nach dem Schließen des Browsers gespeichert (z.&nbsp;B. Login-Status).
                  Speicherdauer bis zu zwei Jahre.
                </p>
              </div>
            </div>

            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Verarbeitete Datenarten:</dt>
                <dd class="text-base-content/70 inline">
                  Meta-, Kommunikations- und Verfahrensdaten.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlagen:</dt>
                <dd class="text-base-content/70 inline">
                  Berechtigte Interessen (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;f DSGVO), Einwilligung
                  (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;a DSGVO).
                </dd>
              </div>
            </dl>

            <p class="text-sm text-base-content/60">
              <strong>Opt-out:</strong> Nutzer können Einwilligungen jederzeit widerrufen
              und die Privatsphäre-Einstellungen ihres Browsers nutzen.
            </p>
          </section>

          <%!-- ===== REGISTRIERUNG ===== --%>
          <section id="m367" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Registrierung, Anmeldung und Nutzerkonto
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Nutzer können ein Nutzerkonto anlegen. Im Rahmen der Registrierung werden
              die erforderlichen Pflichtangaben mitgeteilt und zu Zwecken der
              Bereitstellung des Nutzerkontos auf Grundlage vertraglicher Pflichterfüllung
              verarbeitet. Zu den verarbeiteten Daten gehören insbesondere die
              Login-Informationen (Nutzername, Passwort sowie eine E-Mail-Adresse).
            </p>
            <p class="text-base-content/80 leading-relaxed">
              Wir speichern die IP-Adresse und den Zeitpunkt der jeweiligen
              Nutzerhandlung. Eine Weitergabe dieser Daten an Dritte erfolgt grundsätzlich
              nicht, es sei denn, sie ist zur Verfolgung unserer Ansprüche erforderlich.
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Verarbeitete Datenarten:</dt>
                <dd class="text-base-content/70 inline">
                  Bestandsdaten, Kontaktdaten, Inhaltsdaten, Nutzungsdaten, Protokolldaten.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlagen:</dt>
                <dd class="text-base-content/70 inline">
                  Vertragserfüllung (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;b DSGVO), Berechtigte Interessen
                  (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;f DSGVO).
                </dd>
              </div>
            </dl>

            <h3 class="text-lg font-medium text-base-content mt-4">Weitere Hinweise</h3>
            <ul class="space-y-2 text-sm text-base-content/70">
              <li class="bg-base-200/50 rounded-lg p-3">
                <strong class="text-base-content">Pseudonyme:</strong>
                Nutzer dürfen statt Klarnamen Pseudonyme als Nutzernamen verwenden.
              </li>
              <li class="bg-base-200/50 rounded-lg p-3">
                <strong class="text-base-content">Profilsichtbarkeit:</strong>
                Nutzer können bestimmen, in welchem Umfang ihre Profile sichtbar sind.
              </li>
              <li class="bg-base-200/50 rounded-lg p-3">
                <strong class="text-base-content">Löschung nach Kündigung:</strong>
                Daten werden nach Kündigung des Nutzerkontos gelöscht, vorbehaltlich
                gesetzlicher Pflichten.
              </li>
              <li class="bg-base-200/50 rounded-lg p-3">
                <strong class="text-base-content">Keine Aufbewahrungspflicht:</strong>
                Es obliegt den Nutzern, ihre Daten vor Vertragsende zu sichern.
              </li>
            </ul>
          </section>

          <%!-- ===== COMMUNITY ===== --%>
          <section id="m432" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Community Funktionen
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Die von uns bereitgestellten Community Funktionen erlauben es Nutzern
              miteinander in Konversationen oder sonst miteinander in einen Austausch zu
              treten. Die Nutzung ist nur unter Beachtung der geltenden Rechtslage und
              unserer Richtlinien gestattet.
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Verarbeitete Datenarten:</dt>
                <dd class="text-base-content/70 inline">Bestandsdaten, Nutzungsdaten.</dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlagen:</dt>
                <dd class="text-base-content/70 inline">
                  Vertragserfüllung (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;b DSGVO), Berechtigte Interessen
                  (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;f DSGVO).
                </dd>
              </div>
            </dl>

            <h3 class="text-lg font-medium text-base-content mt-4">Weitere Hinweise</h3>
            <ul class="space-y-2 text-sm text-base-content/70">
              <li class="bg-base-200/50 rounded-lg p-3">
                <strong class="text-base-content">Beitragssichtbarkeit:</strong>
                Nutzer bestimmen, in welchem Umfang ihre Beiträge sichtbar sind.
              </li>
              <li class="bg-base-200/50 rounded-lg p-3">
                <strong class="text-base-content">Sicherheitsspeicherung:</strong>
                Neben Beitragsinhalten werden auch Zeitpunkt und IP-Adresse gespeichert, um
                bei rechtswidrigen Inhalten angemessene Maßnahmen ergreifen zu können.
              </li>
              <li class="bg-base-200/50 rounded-lg p-3">
                <strong class="text-base-content">Gesprächsbeiträge nach Kündigung:</strong>
                Gesprächsbeiträge bleiben auch nach Kontolöschung gespeichert, damit
                Konversationen ihren Sinn behalten. Nutzernamen werden pseudonymisiert.
                Vollständige Löschung kann jederzeit verlangt werden.
              </li>
              <li class="bg-base-200/50 rounded-lg p-3">
                <strong class="text-base-content">Schutz eigener Daten:</strong>
                Nutzer entscheiden selbst, welche Daten sie preisgeben. Wir bitten,
                persönliche Daten nur mit Bedacht zu veröffentlichen und sichere Passwörter
                zu verwenden.
              </li>
            </ul>
          </section>

          <%!-- ===== BLOGS ===== --%>
          <section id="m104" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Blogs und Publikationsmedien
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Wir nutzen Blogs oder vergleichbare Mittel der Onlinekommunikation und
              Publikation. Die Daten der Leser werden nur insoweit verarbeitet, als es für
              die Darstellung und Kommunikation oder aus Gründen der Sicherheit
              erforderlich ist.
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Verarbeitete Datenarten:</dt>
                <dd class="text-base-content/70 inline">
                  Bestandsdaten, Kontaktdaten, Inhaltsdaten, Nutzungsdaten,
                  Meta-/Kommunikationsdaten.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlagen:</dt>
                <dd class="text-base-content/70 inline">
                  Berechtigte Interessen (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;f DSGVO).
                </dd>
              </div>
            </dl>
            <p class="text-sm text-base-content/60">
              <strong>Kommentare und Beiträge:</strong> IP-Adressen können auf Grundlage
              berechtigter Interessen gespeichert werden. Informationen zur Person und
              inhaltliche Angaben werden bis zum Widerspruch dauerhaft gespeichert.
            </p>
          </section>

          <%!-- ===== KONTAKT ===== --%>
          <section id="m182" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Kontakt- und Anfrageverwaltung
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Bei der Kontaktaufnahme mit uns (z.&nbsp;B. per Post, Kontaktformular, E-Mail,
              Telefon oder via soziale Medien) werden die Angaben der anfragenden Personen
              verarbeitet, soweit dies zur Beantwortung der Kontaktanfragen erforderlich
              ist.
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Verarbeitete Datenarten:</dt>
                <dd class="text-base-content/70 inline">
                  Kontaktdaten, Inhaltsdaten, Meta-/Kommunikationsdaten.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlagen:</dt>
                <dd class="text-base-content/70 inline">
                  Berechtigte Interessen (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;f DSGVO), Vertragserfüllung
                  (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;b DSGVO).
                </dd>
              </div>
            </dl>
          </section>

          <%!-- ===== NEWSLETTER ===== --%>
          <section id="m17" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Newsletter und elektronische Benachrichtigungen
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Wir versenden Newsletter, E-Mails und weitere elektronische
              Benachrichtigungen ausschließlich mit der Einwilligung der Empfänger oder
              aufgrund einer gesetzlichen Grundlage. Für die Anmeldung ist normalerweise
              die Angabe Ihrer E-Mail-Adresse ausreichend.
            </p>
            <p class="text-base-content/80 leading-relaxed">
              Ausgetragene E-Mail-Adressen können bis zu drei Jahren gespeichert werden,
              um eine ehemals gegebene Einwilligung nachweisen zu können.
            </p>
            <dl class="bg-base-200/50 rounded-lg p-4 space-y-2 text-sm">
              <div>
                <dt class="font-semibold text-base-content inline">Verarbeitete Datenarten:</dt>
                <dd class="text-base-content/70 inline">
                  Bestandsdaten, Kontaktdaten, Meta-/Kommunikationsdaten.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Rechtsgrundlage:</dt>
                <dd class="text-base-content/70 inline">
                  Einwilligung (Art.&nbsp;6 Abs.&nbsp;1 lit.&nbsp;a DSGVO).
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-base-content inline">Opt-Out:</dt>
                <dd class="text-base-content/70 inline">
                  Sie können den Empfang jederzeit kündigen – Link am Ende jedes Newsletters
                  oder per E-Mail an uns.
                </dd>
              </div>
            </dl>
          </section>

          <%!-- ===== ÄNDERUNG ===== --%>
          <section id="m15" class="space-y-3">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Änderung und Aktualisierung
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              Wir bitten Sie, sich regelmäßig über den Inhalt unserer Datenschutzerklärung
              zu informieren. Wir passen die Datenschutzerklärung an, sobald die
              Änderungen der von uns durchgeführten Datenverarbeitungen dies erforderlich
              machen. Wir informieren Sie, sobald durch die Änderungen eine
              Mitwirkungshandlung Ihrerseits (z.&nbsp;B. Einwilligung) oder eine sonstige
              individuelle Benachrichtigung erforderlich wird.
            </p>
          </section>

          <%!-- ===== BEGRIFFSDEFINITIONEN ===== --%>
          <section id="m42" class="space-y-4">
            <h2 class="text-2xl font-medium text-base-content border-b border-base-300 pb-2">
              Begriffsdefinitionen
            </h2>
            <p class="text-base-content/80 leading-relaxed">
              In diesem Abschnitt erhalten Sie eine Übersicht über die in dieser
              Datenschutzerklärung verwendeten Begrifflichkeiten. Soweit die
              Begrifflichkeiten gesetzlich definiert sind, gelten deren gesetzliche
              Definitionen.
            </p>
            <dl class="space-y-3">
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">Bestandsdaten</dt>
                <dd class="text-sm text-base-content/70 mt-1">
                  Wesentliche Informationen für die Identifikation und Verwaltung von
                  Vertragspartnern, Benutzerkonten und Profilen (z.&nbsp;B. Namen,
                  Kontaktinformationen, Geburtsdaten, Benutzer-IDs).
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">Inhaltsdaten</dt>
                <dd class="text-sm text-base-content/70 mt-1">
                  Informationen, die bei der Erstellung, Bearbeitung und Veröffentlichung von
                  Inhalten generiert werden (Texte, Bilder, Videos, Metadaten).
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">Kontaktdaten</dt>
                <dd class="text-sm text-base-content/70 mt-1">
                  Informationen, die die Kommunikation ermöglichen (Telefonnummern, Adressen,
                  E-Mail-Adressen, Social-Media-Handles).
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">
                  Meta-, Kommunikations- und Verfahrensdaten
                </dt>
                <dd class="text-sm text-base-content/70 mt-1">
                  Informationen über Art und Weise der Datenverarbeitung, -übermittlung und
                  -verwaltung (z.&nbsp;B. Dateigröße, Erstellungsdatum, Workflow-Dokumentationen,
                  Audit-Logs).
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">Nutzungsdaten</dt>
                <dd class="text-sm text-base-content/70 mt-1">
                  Informationen über die Interaktion mit digitalen Produkten (Seitenaufrufe,
                  Verweildauer, Klickpfade, Geräteinformationen, Standortdaten).
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">Personenbezogene Daten</dt>
                <dd class="text-sm text-base-content/70 mt-1">
                  Alle Informationen, die sich auf eine identifizierte oder identifizierbare
                  natürliche Person beziehen (z.&nbsp;B. Name, Kennnummer, Standortdaten,
                  Online-Kennung).
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">Protokolldaten</dt>
                <dd class="text-sm text-base-content/70 mt-1">
                  Informationen über Ereignisse oder Aktivitäten in einem System (Zeitstempel,
                  IP-Adressen, Benutzeraktionen, Fehlermeldungen).
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">Verantwortlicher</dt>
                <dd class="text-sm text-base-content/70 mt-1">
                  Die natürliche oder juristische Person, die über die Zwecke und Mittel
                  der Verarbeitung von personenbezogenen Daten entscheidet.
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">Verarbeitung</dt>
                <dd class="text-sm text-base-content/70 mt-1">
                  Jeder Vorgang im Zusammenhang mit personenbezogenen Daten (Erheben,
                  Auswerten, Speichern, Übermitteln, Löschen).
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">Vertragsdaten</dt>
                <dd class="text-sm text-base-content/70 mt-1">
                  Informationen zur Formalisierung einer Vereinbarung (Start-/Enddaten,
                  Leistungen, Preise, Zahlungsbedingungen, Kündigungsrechte).
                </dd>
              </div>
              <div class="bg-base-200/50 rounded-lg p-4">
                <dt class="font-semibold text-base-content">Zahlungsdaten</dt>
                <dd class="text-sm text-base-content/70 mt-1">
                  Informationen zur Abwicklung von Zahlungstransaktionen
                  (Kreditkartennummern, Bankverbindungen, Zahlungsbeträge,
                  Verifizierungsnummern).
                </dd>
              </div>
            </dl>
          </section>

          <%!-- ===== FOOTER ===== --%>
          <footer class="border-t border-base-300 pt-6 mt-10">
            <p class="text-sm text-base-content/50 text-center">
              <a
                href="https://datenschutz-generator.de/"
                target="_blank"
                rel="noopener noreferrer nofollow"
                class="text-base-content/50 hover:text-primary transition-colors"
              >
                Erstellt mit kostenlosem Datenschutz-Generator.de von Dr. Thomas Schwenke
              </a>
            </p>
          </footer>
        </article>
      </div>
    </Layouts.app>
    """
  end
end
