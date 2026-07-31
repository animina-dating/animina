defmodule AniminaWeb.Plugs.Shutdown do
  @moduledoc """
  Serves the static farewell page for every request while the platform
  is shut down (`config :animina, :shutdown_mode`).

  The legally required pages (Impressum, Datenschutz, AGB) and the
  `/health` endpoint used by the deploy pipeline pass through to the
  router. Static assets are unaffected because `Plug.Static` runs
  earlier in the endpoint. In prod the LiveView socket is removed at
  compile time (see `AniminaWeb.Endpoint`), so already-open tabs cannot
  reconnect after the deploy and fall back to HTTP, which lands here.
  """

  import Plug.Conn

  @allowed_paths ["/impressum", "/datenschutz", "/agb", "/health"]

  def init(opts), do: opts

  def call(conn, _opts) do
    path = String.trim_trailing(conn.request_path, "/")

    if enabled?() and path not in @allowed_paths do
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, page())
      |> halt()
    else
      conn
    end
  end

  defp enabled? do
    Application.get_env(:animina, :shutdown_mode, false)
  end

  @doc """
  The complete farewell page as a self-contained HTML document.

  Public so it can be exported to a static file once the app itself is
  retired and nginx serves the page directly:

      mix run --no-start -e 'IO.write(AniminaWeb.Plugs.Shutdown.page())'
  """
  def page do
    """
    <!DOCTYPE html>
    <html lang="de">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>ANIMINA stellt den Betrieb ein · ANIMINA is shutting down</title>
      <meta name="description" content="ANIMINA stellt den Betrieb ein · ANIMINA is shutting down">
      <link rel="icon" href="/favicon.ico">
      <style>
        :root { color-scheme: light dark; }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
            "Helvetica Neue", Arial, sans-serif;
          background: #fafafa;
          color: #1f2937;
          line-height: 1.65;
          padding: 3rem 1.25rem 4rem;
        }
        main { max-width: 44rem; margin: 0 auto; }
        h1, h2 {
          font-size: 1.6rem;
          font-weight: 600;
          letter-spacing: -0.01em;
          margin-bottom: 1.5rem;
        }
        h2 { margin-top: 0; }
        p { margin-bottom: 1rem; }
        ul { margin: 0 0 1rem 1.4rem; }
        li { margin-bottom: 0.5rem; }
        a { color: #0f766e; }
        .date {
          text-align: right;
          font-size: 0.9rem;
          color: #6b7280;
          margin-bottom: 0.75rem;
        }
        .lang-jump { font-size: 0.9rem; margin: -0.75rem 0 1.5rem; }
        figure {
          float: right;
          width: min(45%, 18rem);
          margin: 0.25rem 0 1rem 1.5rem;
        }
        img {
          max-width: 100%;
          height: auto;
          border-radius: 0.75rem;
          border: 1px solid #e5e7eb;
          box-shadow: 0 10px 25px rgb(0 0 0 / 0.08);
        }
        figcaption {
          font-size: 0.85rem;
          color: #6b7280;
          text-align: center;
          margin-top: 0.6rem;
        }
        hr { clear: both; border: 0; border-top: 1px solid #e5e7eb; margin: 2.5rem 0; }
        @media (max-width: 600px) {
          figure { float: none; width: 100%; margin: 0 0 1.5rem; }
        }
        footer {
          margin-top: 3rem;
          font-size: 0.85rem;
          color: #6b7280;
          text-align: center;
        }
        footer a { color: inherit; }
        @media (prefers-color-scheme: dark) {
          body { background: #111827; color: #e5e7eb; }
          a { color: #5eead4; }
          img { border-color: #374151; box-shadow: 0 10px 25px rgb(0 0 0 / 0.4); }
          hr { border-top-color: #374151; }
          .date, figcaption, footer { color: #9ca3af; }
        }
      </style>
    </head>
    <body>
      <main>
        <p class="date">31. Juli 2026</p>

        <h1>ANIMINA stellt den Betrieb ein</h1>

        <p class="lang-jump"><a href="#english">English version</a></p>

        <figure>
          <img src="/images/animina-landing-page.jpg"
               alt="Screenshot der ANIMINA-Startseite: Profilfotos, der Slogan 'Online-Dating? Online-Dating!' und die Merkmale 100% Kostenlos, Schubladen? und Flaggensystem"
               width="1600" height="1064">
          <figcaption>Die ANIMINA-Startseite · The ANIMINA landing page</figcaption>
        </figure>

        <p>Liebe Mitglieder,</p>

        <p>heute muss ich euch leider mitteilen, dass ANIMINA den Betrieb einstellt.</p>

        <p>
          ANIMINA war von Anfang an ein Open-Source-Projekt, das ich neben meiner
          eigentlichen Arbeit aufgebaut und betrieben habe. Die Entscheidung
          fällt mir nicht leicht, denn an der Idee liegt es nicht: Das Konzept
          funktioniert. Was fehlt, ist meine Zeit. Zwei Plattformen parallel zu
          betreiben schaffe ich nicht, und vutuv wächst gerade viel stärker.
          Also musste ich mich entscheiden. Eine Dating-Plattform, die niemand
          aktiv betreut, wäre unfair gegenüber allen, die hier ernsthaft
          jemanden suchen. Deshalb ist heute Schluss.
        </p>

        <p>
          vutuv ist ein kostenloses Open-Source-Netzwerk für berufliche Kontakte
          und meine Antwort auf LinkedIn:
          <a href="https://vutuv.de">https://vutuv.de</a><br>
          Schaut gern vorbei. Wer mit mir in Kontakt bleiben möchte, findet mich
          dort unter <a href="https://vutuv.de/wintermeyer">https://vutuv.de/wintermeyer</a>
        </p>

        <p>Was das konkret bedeutet:</p>

        <ul>
          <li>Die Plattform ist ab sofort abgeschaltet, ein Login ist nicht mehr möglich.</li>
          <li>Alle Konten, Profile, Fotos und Nachrichten werden am 28. August 2026 endgültig gelöscht.</li>
          <li>
            Wer vorher noch eine Kopie der eigenen Daten möchte oder Fragen hat, erreicht mich unter
            <a href="mailto:sw@wintermeyer-consulting.de">sw@wintermeyer-consulting.de</a>
          </li>
        </ul>

        <p>
          Der Quellcode bleibt frei verfügbar:
          <a href="https://github.com/wintermeyer/animina">https://github.com/wintermeyer/animina</a><br>
          Wer das Projekt übernehmen oder eine eigene Instanz betreiben möchte:
          Meldet euch, ich helfe gern beim Start.
        </p>

        <p>Danke an alle, die dabei waren.</p>

        <p>Stefan Wintermeyer</p>

        <hr>

        <section lang="en" id="english">
          <h2>ANIMINA is shutting down</h2>

          <p>Dear members,</p>

          <p>today I have to tell you that ANIMINA is shutting down.</p>

          <p>
            ANIMINA has always been an open-source project that I built and ran
            alongside my regular work. This is not an easy decision, because the
            idea is not the problem: the concept works. What I lack is time. I
            cannot run two platforms in parallel, and vutuv is currently growing
            much faster. I had to pick one. A dating platform that nobody
            actively looks after would be unfair to everyone who is seriously
            looking for someone here. So today it ends.
          </p>

          <p>
            vutuv is a free, open-source network for professional contacts and
            my answer to LinkedIn:
            <a href="https://vutuv.de">https://vutuv.de</a><br>
            Do have a look. If you would like to stay in touch, you will find me
            there at <a href="https://vutuv.de/wintermeyer">https://vutuv.de/wintermeyer</a>
          </p>

          <p>What this means:</p>

          <ul>
            <li>The platform is offline as of now; logging in is no longer possible.</li>
            <li>All accounts, profiles, photos and messages will be permanently deleted on 28 August 2026.</li>
            <li>
              If you would like a copy of your data before then, or have any questions, you can reach me at
              <a href="mailto:sw@wintermeyer-consulting.de">sw@wintermeyer-consulting.de</a>
            </li>
          </ul>

          <p>
            The source code remains freely available at
            <a href="https://github.com/wintermeyer/animina">https://github.com/wintermeyer/animina</a><br>
            If you want to take over the project or run your own instance, get
            in touch. I'll gladly help you get started.
          </p>

          <p>Thank you to everyone who was part of this.</p>

          <p>Stefan Wintermeyer</p>
        </section>

        <footer>
          <a href="/impressum">Impressum</a> ·
          <a href="/datenschutz">Datenschutz</a> ·
          <a href="/agb">AGB</a>
        </footer>
      </main>
    </body>
    </html>
    """
  end
end
