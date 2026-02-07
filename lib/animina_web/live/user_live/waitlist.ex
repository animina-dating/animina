defmodule AniminaWeb.UserLive.Waitlist do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.ProfileCompleteness
  alias Animina.FeatureFlags
  alias Animina.GeoData

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto space-y-6">
        <%!-- Header --%>
        <div class="text-center">
          <h1 class="text-2xl sm:text-3xl font-light text-base-content">
            {gettext("Waitlist")}
          </h1>
          <p class="mt-2 text-base-content/70">
            {gettext("Hi %{name}, your account is on the waitlist and will be activated soon.",
              name: @current_scope.user.display_name
            )}
          </p>
        </div>

        <%!-- Activation status --%>
        <div class="bg-surface rounded-xl shadow-md p-6">
          <div class="flex items-center gap-3 mb-3">
            <div class="w-10 h-10 rounded-full bg-warning/20 flex items-center justify-center">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-5 h-5 text-warning"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <h2 class="text-lg font-medium text-base-content">
              {gettext("Estimated activation")}
            </h2>
          </div>

          <p class="text-2xl font-semibold text-base-content mb-2">
            <span
              :if={@end_waitlist_at && DateTime.compare(@end_waitlist_at, DateTime.utc_now()) == :gt}
              id="waitlist-countdown"
              phx-hook="WaitlistCountdown"
              data-end-waitlist-at={DateTime.to_iso8601(@end_waitlist_at)}
              data-locale={@current_scope.user.language}
              data-expired-text={gettext("Your activation is being processed")}
            >
              {gettext("approximately 4 weeks")}
            </span>
            <span :if={
              @end_waitlist_at && DateTime.compare(@end_waitlist_at, DateTime.utc_now()) != :gt
            }>
              {gettext("Your activation is being processed")}
            </span>
            <span :if={is_nil(@end_waitlist_at)}>
              {gettext("approximately 4 weeks")}
            </span>
          </p>

          <p class="text-sm text-base-content/60">
            {gettext("We'll notify you by email when your account is ready.")}
          </p>
        </div>

        <%!-- Prepare your profile --%>
        <div class="bg-surface rounded-xl shadow-md p-6">
          <h2 class="text-lg font-medium text-base-content mb-2">
            {gettext("Prepare your profile")}
          </h2>
          <p class="text-sm text-base-content/60 mb-4">
            {gettext("Use the waiting time to set up your profile so you can get started right away.")}
          </p>

          <div class="grid gap-3 sm:grid-cols-2">
            <.waitlist_card
              navigate={~p"/users/settings/avatar"}
              icon_bg="bg-secondary/10"
              icon_color="text-secondary"
              complete={@profile_completeness.items.profile_photo}
            >
              <:icon>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="w-5 h-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path
                    fill-rule="evenodd"
                    d="M4 5a2 2 0 00-2 2v8a2 2 0 002 2h12a2 2 0 002-2V7a2 2 0 00-2-2h-1.586a1 1 0 01-.707-.293l-1.121-1.121A2 2 0 0011.172 3H8.828a2 2 0 00-1.414.586L6.293 4.707A1 1 0 015.586 5H4zm6 9a3 3 0 100-6 3 3 0 000 6z"
                    clip-rule="evenodd"
                  />
                </svg>
              </:icon>
              <:title>{gettext("Profile Photo")}</:title>
              <:description>{gettext("Upload your main profile photo.")}</:description>
            </.waitlist_card>

            <.waitlist_card
              navigate={~p"/users/settings/traits"}
              icon_bg="bg-success/10"
              icon_color="text-success"
              complete={@profile_completeness.items.flags}
            >
              <:icon>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="w-5 h-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
              </:icon>
              <:title>{gettext("Set up your flags")}</:title>
              <:description>
                {gettext("Define what you're about and what you're looking for.")}
              </:description>
            </.waitlist_card>

            <.waitlist_card
              navigate={~p"/users/settings/moodboard"}
              icon_bg="bg-primary/10"
              icon_color="text-primary"
              complete={@profile_completeness.items.moodboard}
            >
              <:icon>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="w-5 h-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path
                    fill-rule="evenodd"
                    d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z"
                    clip-rule="evenodd"
                  />
                </svg>
              </:icon>
              <:title>{gettext("Edit Moodboard")}</:title>
              <:description>
                {gettext("Add photos and stories to make a great first impression.")}
              </:description>
            </.waitlist_card>

            <.waitlist_card
              navigate={~p"/users/settings/passkeys"}
              icon_bg="bg-info/10"
              icon_color="text-info"
              complete={@has_passkeys}
              optional={true}
            >
              <:icon>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="w-5 h-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path
                    fill-rule="evenodd"
                    d="M18 8a6 6 0 01-7.743 5.743L10 14l-1 1-1 1H6v2H2v-4l4.257-4.257A6 6 0 1118 8zm-6-4a1 1 0 100 2 2 2 0 012 2 1 1 0 102 0 4 4 0 00-4-4z"
                    clip-rule="evenodd"
                  />
                </svg>
              </:icon>
              <:title>{gettext("Set up a passkey")}</:title>
              <:description>
                {gettext("Sign in faster and more securely with a passkey.")}
              </:description>
            </.waitlist_card>
          </div>
        </div>

        <%!-- Skip the waitlist --%>
        <div class="bg-surface rounded-xl shadow-md p-6">
          <h2 class="text-lg font-medium text-base-content mb-2">
            {gettext("Skip the waitlist")}
          </h2>
          <p class="text-sm text-base-content/60 mb-4">
            {ngettext(
              "Refer a friend to ANIMINA. After %{count} confirmed referral your account is activated instantly.",
              "Refer friends to ANIMINA. After %{count} confirmed referrals your account is activated instantly.",
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
      </div>
    </Layouts.app>
    """
  end

  attr :navigate, :string, required: true
  attr :icon_bg, :string, required: true
  attr :icon_color, :string, required: true
  attr :complete, :boolean, required: true
  attr :optional, :boolean, default: false

  slot :icon, required: true
  slot :title, required: true
  slot :description, required: true

  defp waitlist_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="flex items-center gap-3 rounded-lg border border-base-300 p-4 hover:bg-base-200 transition-colors relative"
    >
      <div class={"w-10 h-10 rounded-full #{@icon_bg} flex items-center justify-center shrink-0 #{@icon_color}"}>
        {render_slot(@icon)}
      </div>
      <div class="flex-1 min-w-0">
        <p class="font-medium text-base-content">{render_slot(@title)}</p>
        <p class="text-xs text-base-content/60">
          {render_slot(@description)}
        </p>
      </div>
      <span class="shrink-0">
        <%= if @complete do %>
          <.icon name="hero-check-circle-solid" class="size-5 text-success" />
        <% else %>
          <%= if @optional do %>
            <span class="text-xs text-base-content/40 font-medium">{gettext("Optional")}</span>
          <% else %>
            <span class="inline-block size-5 rounded-full border-2 border-base-content/20" />
          <% end %>
        <% end %>
      </span>
    </.link>
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
    has_passkeys = Accounts.list_user_passkeys(user) != []
    profile_completeness = ProfileCompleteness.compute(user)

    {:ok,
     socket
     |> assign(:city_names, city_names)
     |> assign(:referral_code, user.referral_code)
     |> assign(:referral_count, referral_count)
     |> assign(:referral_threshold, referral_threshold)
     |> assign(:end_waitlist_at, user.end_waitlist_at)
     |> assign(:has_passkeys, has_passkeys)
     |> assign(:profile_completeness, profile_completeness)}
  end
end
