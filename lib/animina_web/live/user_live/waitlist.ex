defmodule AniminaWeb.UserLive.Waitlist do
  use AniminaWeb, :live_view

  alias Animina.GeoData

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
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
              Du befindest dich derzeit auf unserer Warteliste.
              Dafür kann es verschiedene Gründe geben:
            </p>
            <ul class="list-disc list-outside space-y-1 ml-8">
              <li>Es gibt noch zu wenige Nutzer in {@city_names}</li>
              <li>Es gibt für {@city_names} in den letzten 7 Tagen zu viele Neuanmeldungen</li>
              <li>
                Wir haben insgesamt zu viele neue Anmeldungen und müssen erst unsere in Deutschland gehostete Server-Hardware aufrüsten
              </li>
            </ul>
            <p>
              Voraussichtliche Wartezeit: <strong>ca. 4 Wochen</strong>.
            </p>
            <p>
              Wir werden dir eine E-Mail senden, sobald dein Konto
              freigeschaltet wurde. Du kannst Dich auch zwischenzeitlich immer mal wieder auf animina.de einloggen und nachschauen.
            </p>
            <p class="mt-8">
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

    {:ok, assign(socket, :city_names, city_names)}
  end
end
