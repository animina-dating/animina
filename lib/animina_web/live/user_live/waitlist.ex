defmodule AniminaWeb.UserLive.Waitlist do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.FeatureFlags
  alias Animina.GeoData

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="bg-surface rounded-xl shadow-md p-6 sm:p-8">
          <h1 class="text-2xl sm:text-3xl font-light text-base-content mb-6 text-center">
            {gettext("Waitlist")}
          </h1>

          <div class="space-y-4 text-base text-base-content/70">
            <p>
              {gettext("Hello")} {@current_scope.user.display_name},
            </p>
            <p>
              {gettext("Thank you for registering with ANIMINA!")}
            </p>
            <p>
              {gettext("You are on our waitlist. Possible reasons:")}
            </p>
            <ul class="list-disc list-outside space-y-1 ms-8">
              <li>{gettext("There are not enough users in %{cities} yet.", cities: @city_names)}</li>
              <li>
                {gettext(
                  "There have been too many new registrations in %{cities} in the last 7 days.",
                  cities: @city_names
                )}
              </li>
              <li>
                {gettext(
                  "There are too many new registrations overall and we need to upgrade our server hardware hosted in Germany."
                )}
              </li>
              <li>
                {gettext("We are working on new features and need some breathing room.")}
              </li>
            </ul>
            <p>
              {gettext("Expected waiting time:")}
              <strong
                :if={
                  @end_waitlist_at && DateTime.compare(@end_waitlist_at, DateTime.utc_now()) == :gt
                }
                id="waitlist-countdown"
                phx-hook="WaitlistCountdown"
                data-end-waitlist-at={DateTime.to_iso8601(@end_waitlist_at)}
                data-locale={@current_scope.user.language}
                data-expired-text={gettext("Your activation is being processed")}
              >
                {gettext("approximately 4 weeks")}
              </strong>
              <strong :if={
                @end_waitlist_at && DateTime.compare(@end_waitlist_at, DateTime.utc_now()) != :gt
              }>
                {gettext("Your activation is being processed")}
              </strong>
              <strong :if={is_nil(@end_waitlist_at)}>
                {gettext("approximately 4 weeks")}
              </strong>
            </p>
            <p>
              {gettext(
                "We will send you an email once your account has been activated. You can also log in to animina.de from time to time to check."
              )}
            </p>
          </div>

          <div class="mt-8 border-t border-base-300 pt-6">
            <h2 class="text-lg font-medium text-base-content mb-4 text-center">
              {gettext("Get activated faster")}
            </h2>
            <p class="text-sm text-base-content/70 mb-4 text-center">
              {ngettext(
                "Refer ANIMINA! After %{count} confirmed referral you will be activated automatically.",
                "Refer ANIMINA! After %{count} confirmed referrals you will be activated automatically.",
                @referral_threshold
              )}
            </p>

            <div class="bg-base-200 rounded-lg p-4 text-center">
              <p class="text-xs text-base-content/50 mb-2">{gettext("Your referral code")}</p>
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
                {gettext("Copy code")}
              </button>
            </div>

            <div class="mt-4">
              <div class="flex justify-between text-sm text-base-content/70 mb-1">
                <span>
                  {ngettext(
                    "%{count}/%{threshold} referral",
                    "%{count}/%{threshold} referrals",
                    @referral_count,
                    threshold: @referral_threshold
                  )}
                </span>
                <span :if={@referral_count >= @referral_threshold} class="text-success font-medium">
                  {gettext("Activated!")}
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
              {gettext("Best regards")}
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
      |> Enum.map_join(", ", fn loc ->
        case GeoData.get_city_by_zip_code(loc.zip_code) do
          %{name: name} -> name
          nil -> loc.zip_code
        end
      end)

    referral_count = Accounts.count_confirmed_referrals(user)
    referral_threshold = FeatureFlags.referral_threshold()

    {:ok,
     socket
     |> assign(:city_names, city_names)
     |> assign(:referral_code, user.referral_code)
     |> assign(:referral_count, referral_count)
     |> assign(:referral_threshold, referral_threshold)
     |> assign(:end_waitlist_at, user.end_waitlist_at)}
  end
end
