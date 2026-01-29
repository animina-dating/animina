defmodule AniminaWeb.UserLive.Waitlist do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.GeoData

  @referral_threshold 5

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      display_name={@current_scope.user.display_name}
    >
      <div class="mx-auto max-w-2xl px-4 py-8">
        <div class="bg-surface rounded-xl shadow-md p-6 sm:p-8">
          <h1 class="text-2xl sm:text-3xl font-light text-base-content mb-6 text-center">
            Warteliste
          </h1>

          <div class="space-y-4 text-base text-base-content/70">
            <p>
              Hallo {@current_scope.user.display_name},
            </p>
            <p>
              vielen Dank für deine Registrierung bei ANIMINA!
            </p>
            <p>
              Du befindest dich auf unserer Warteliste.
              Potentielle Gründe:
            </p>
            <ul class="list-disc list-outside space-y-1 ml-8">
              <li>Es gibt noch zu wenige Nutzer in {@city_names}</li>
              <li>Es gibt für {@city_names} in den letzten 7 Tagen zu viele Neuanmeldungen</li>
              <li>
                Es gibt insgesamt zu viele Neuanmeldungen und wir müssen erst unsere in Deutschland gehostete Server-Hardware aufrüsten
              </li>
              <li>
                Wir arbeiten an neuen Features und brauchen dafür etwas Luft zum Atmen
              </li>
            </ul>
            <p>
              Voraussichtliche Wartezeit: <strong>ca. 4 Wochen</strong>.
            </p>
            <p>
              Wir werden dir eine E-Mail senden, sobald dein Konto
              freigeschaltet wurde. Du kannst Dich auch zwischenzeitlich immer mal wieder auf animina.de einloggen und nachschauen.
            </p>
          </div>

          <div class="mt-8 border-t border-base-300 pt-6">
            <h2 class="text-lg font-medium text-base-content mb-4 text-center">
              Schneller freigeschaltet werden
            </h2>
            <p class="text-sm text-base-content/70 mb-4 text-center">
              Empfehle ANIMINA weiter! Nach {@referral_threshold} bestätigten Empfehlungen wirst du automatisch freigeschaltet.
            </p>

            <div class="bg-base-200 rounded-lg p-4 text-center">
              <p class="text-xs text-base-content/50 mb-2">Dein Empfehlungscode</p>
              <p
                id="referral-code"
                class="text-3xl font-mono font-bold tracking-widest text-primary select-all"
                phx-click={JS.dispatch("phx:copy", to: "#referral-code")}
              >
                {@referral_code}
              </p>
              <button
                type="button"
                class="btn btn-primary btn-sm mt-2"
                phx-click={JS.dispatch("phx:copy", to: "#referral-code")}
              >
                Code kopieren
              </button>
            </div>

            <div class="mt-4">
              <div class="flex justify-between text-sm text-base-content/70 mb-1">
                <span>{@referral_count}/{@referral_threshold} Empfehlungen</span>
                <span :if={@referral_count >= @referral_threshold} class="text-success font-medium">
                  Freigeschaltet!
                </span>
              </div>
              <div class="w-full bg-base-300 rounded-full h-2.5">
                <div
                  class="bg-primary h-2.5 rounded-full transition-all duration-300"
                  style={"width: #{min(100, @referral_count / @referral_threshold * 100)}%"}
                >
                </div>
              </div>
            </div>
          </div>

          <div class="mt-8 space-y-2 text-base text-base-content/70">
            <p>
              Viele Grüße
            </p>
            <p>
              Stefan Wintermeyer <br />
              <a href="mailto:sw@wintermeyer-consulting.de" class="text-primary hover:underline">
                sw@wintermeyer-consulting.de
              </a>
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    user = Animina.Repo.preload(user, :locations)

    city_names =
      user.locations
      |> Enum.sort_by(& &1.position)
      |> Enum.map(fn loc ->
        case GeoData.get_city_by_zip_code(loc.zip_code) do
          %{name: name} -> name
          nil -> loc.zip_code
        end
      end)
      |> Enum.join(", ")

    referral_count = Accounts.count_confirmed_referrals(user)

    {:ok,
     socket
     |> assign(:city_names, city_names)
     |> assign(:referral_code, user.referral_code)
     |> assign(:referral_count, referral_count)
     |> assign(:referral_threshold, @referral_threshold)}
  end
end
