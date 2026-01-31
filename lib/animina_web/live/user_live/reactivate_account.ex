defmodule AniminaWeb.UserLive.ReactivateAccount do
  use AniminaWeb, :live_view

  alias Animina.Accounts

  @token_max_age 600

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl px-4 py-8">
        <div class="text-center mb-8">
          <.header>
            {gettext("Welcome back!")}
            <:subtitle>
              {gettext("Your account was scheduled for deletion. What would you like to do?")}
            </:subtitle>
          </.header>
        </div>

        <div class="alert alert-info mb-6">
          <p>
            {gettext(
              "Your account is still within the 30-day grace period. You can reactivate it or start fresh with a new account."
            )}
          </p>
        </div>

        <div class="flex flex-col gap-4">
          <button
            id="reactivate-btn"
            class="btn btn-primary btn-lg"
            phx-click="reactivate"
          >
            {gettext("Reactivate my account")}
          </button>
          <button
            id="fresh-start-btn"
            class="btn btn-outline btn-lg"
            phx-click="fresh_start"
          >
            {gettext("Start fresh with a new account")}
          </button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    case verify_reactivation_token(session) do
      {:ok, user} ->
        {:ok,
         socket
         |> assign(:page_title, gettext("Reactivate Account"))
         |> assign(:reactivation_user, user)}

      :error ->
        {:ok,
         socket
         |> put_flash(
           :error,
           gettext("Invalid or expired reactivation link. Please log in again.")
         )
         |> redirect(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("reactivate", _params, socket) do
    user = socket.assigns.reactivation_user

    case Accounts.reactivate_user(user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Your account has been reactivated. Please log in."))
         |> redirect(to: ~p"/users/log-in")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext(
             "This email address is now used by another account. Please register a new account."
           )
         )
         |> redirect(to: ~p"/users/register")}
    end
  end

  def handle_event("fresh_start", _params, socket) do
    user = socket.assigns.reactivation_user

    {:ok, _} = Accounts.hard_delete_user(user)

    {:noreply,
     socket
     |> put_flash(
       :info,
       gettext("Your old account has been removed. You can now register a new account.")
     )
     |> redirect(to: ~p"/users/register")}
  end

  defp verify_reactivation_token(session) do
    with token when is_binary(token) <- session["reactivation_token"],
         {:ok, user_id} <-
           Phoenix.Token.verify(AniminaWeb.Endpoint, "reactivation", token,
             max_age: @token_max_age
           ),
         %Accounts.User{} = user <- Accounts.get_user(user_id),
         true <- Accounts.user_deleted?(user),
         true <- Accounts.within_grace_period?(user) do
      {:ok, user}
    else
      _ -> :error
    end
  end
end
