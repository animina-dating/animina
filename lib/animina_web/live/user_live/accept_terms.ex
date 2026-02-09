defmodule AniminaWeb.UserLive.AcceptTerms do
  use AniminaWeb, :live_view

  alias Animina.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Accept Terms of Service"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="bg-surface rounded-xl shadow-md p-6 sm:p-8">
          <div class="text-center mb-6">
            <h1 class="text-2xl sm:text-3xl font-light text-base-content">
              {gettext("Updated Terms of Service")}
            </h1>
            <p class="mt-2 text-base text-base-content/70">
              {gettext("Please accept our updated Terms of Service to continue using ANIMINA.")}
            </p>
          </div>

          <div class="space-y-4 mb-6">
            <div class="bg-base-200/50 rounded-lg p-4 space-y-2">
              <p class="text-base-content/80 leading-relaxed text-sm">
                {gettext("We have introduced Terms of Service (AGB) that cover:")}
              </p>
              <ul class="list-disc list-inside text-sm text-base-content/70 space-y-1">
                <li>{gettext("Rules for using the platform")}</li>
                <li>{gettext("Content moderation by administrators and moderators")}</li>
                <li>{gettext("Account suspension and deletion policies")}</li>
                <li>{gettext("Your right to delete your account at any time")}</li>
              </ul>
            </div>
            <div class="flex gap-4 text-sm">
              <a href="/agb" target="_blank" class="text-primary hover:underline">
                {gettext("Terms of Service")} &rarr;
              </a>
              <a href="/datenschutz" target="_blank" class="text-primary hover:underline">
                {gettext("Privacy Policy")} &rarr;
              </a>
            </div>
          </div>

          <.form for={%{}} id="accept_tos_form" phx-submit="accept" class="space-y-4">
            <div class="flex items-start gap-3">
              <input
                type="checkbox"
                id="tos_accepted"
                name="tos_accepted"
                value="true"
                required
                class="checkbox checkbox-sm mt-1"
              />
              <label for="tos_accepted" class="text-sm text-base-content/70">
                {gettext("I accept the")}
                <a href="/agb" class="text-primary hover:underline" target="_blank">
                  {gettext("Terms of Service")}
                </a>
                {gettext("and the")}
                <a href="/datenschutz" class="text-primary hover:underline" target="_blank">{gettext("Privacy Policy")}</a>.
              </label>
            </div>

            <div class="flex flex-col sm:flex-row gap-3 pt-2">
              <.button class="btn btn-primary flex-1">
                {gettext("Accept and continue")}
              </.button>
              <button type="button" phx-click="decline" class="btn btn-ghost flex-1">
                {gettext("Decline and log out")}
              </button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("accept", %{"tos_accepted" => "true"}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.accept_terms_of_service(user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Terms of Service accepted. Welcome back!"))
         |> push_navigate(to: ~p"/settings")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Something went wrong. Please try again."))}
    end
  end

  def handle_event("decline", _params, socket) do
    {:noreply,
     socket
     |> put_flash(
       :info,
       gettext("You can accept the Terms of Service the next time you log in.")
     )
     |> redirect(to: ~p"/")}
  end
end
