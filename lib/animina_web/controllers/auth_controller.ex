defmodule AniminaWeb.AuthController do
  use AniminaWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias Animina.Accounts
  alias Animina.Accounts.BasicUser
  alias AshPhoenix.Form

  def success(conn, _activity, user, _token) do
    # return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: ~p"/registration/potential-partner")
  end

  def failure(conn, _activity, reason) do
    # TODO: Fix the display of validation errors
    # see https://elixirforum.com/t/return-to-create-form-after-validation-error-for-ash-authentication/61110/5
    params =
      if reason.changeset do
        reason.changeset.params
      else
        %{}
      end

    conn =
      conn
      |> assign(:form_id, "sign-up-form")
      |> assign(:cta, "Account anlegen")
      |> assign(:action, ~p"/auth/user/password/register")
      |> assign(:is_register?, true)
      |> assign(
        :form,
        Form.for_create(BasicUser, :register_with_password,
          api: Accounts,
          as: "user",
          params: params
        )
      )

    render(conn, :register, layout: false)
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session()
    |> redirect(to: return_to)
  end

  def register(conn, _params) do
    language = get_session(conn, :language) || "en-gb"

    conn =
      conn
      |> assign(:form_id, "sign-up-form")
      |> assign(:cta, "Account anlegen")
      |> assign(:action, ~p"/auth/user/password/register")
      |> assign(:is_register?, true)
      |> assign(:language, language)
      |> assign(
        :form,
        Form.for_create(BasicUser, :register_with_password, api: Accounts, as: "user")
      )

    render(conn, :register, layout: false)
  end
end
