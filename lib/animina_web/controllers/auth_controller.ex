defmodule AniminaWeb.AuthController do
  use AniminaWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias Animina.Accounts.Token

  def success(conn, _activity, user, _token) do
    return_to =
      case Map.get(conn.query_params, "redirect_to") do
        nil ->
          get_session(conn, :return_to) || ~p"/profile/potential-partner"

        path ->
          path
      end

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: return_to)
  end

  def failure(
        conn,
        {:password, :sign_in},
        %AshAuthentication.Errors.AuthenticationFailed{} = reason
      ) do
    conn
    |> assign(:errors, reason)
    |> put_flash(
      :error,
      gettext("Username or password is incorrect")
    )
    |> redirect(to: "/sign-in")
  end

  def failure(
        conn,
        {:password, :register},
        reason
      ) do
    conn
    |> assign(:errors, reason)
    |> put_flash(
      :error,
      gettext("Something went wrong. Try again.") <>
        " " <>
        Enum.map_join(reason.errors, "\n", fn x ->
          (to_string(x.field) |> String.capitalize()) <> " " <> x.message
        end)
    )
    |> redirect(to: "/register")
  end

  # def failure(conn, _activity, reason) do
  #   # TODO: Fix the display of validation errors
  #   # see https://elixirforum.com/t/return-to-create-form-after-validation-error-for-ash-authentication/61110/5
  #   params =
  #     if reason.changeset do
  #       reason.changeset.params
  #     else
  #       %{}
  #     end

  #   conn =
  #     conn
  #     |> assign(:form_id, "sign-up-form")
  #     |> assign(:cta, "Account anlegen")
  #     |> assign(:action, ~p"/auth/user/password/register")
  #     |> assign(:is_register?, true)
  #     |> assign(
  #       :form,
  #       Form.for_create(BasicUser, :register_with_password,
  #         api: Accounts,
  #         as: "user",
  #         params: params
  #       )
  #     )

  #   render(conn, :register, layout: false)
  # end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    token = Plug.Conn.get_session(conn, "user_token")

    if token do
      Token
      |> AshAuthentication.TokenResource.Actions.get_token(%{"token" => token})
      |> case do
        {:ok, [token]} ->
          Token.destroy!(token, authorize?: false)

        _ ->
          :ok
      end
    end

    conn
    |> clear_session()
    |> redirect(to: return_to)
  end
end
