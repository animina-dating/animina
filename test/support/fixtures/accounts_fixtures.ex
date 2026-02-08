defmodule Animina.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Animina.Accounts` context.
  """

  import Ecto.Query

  alias Animina.Accounts
  alias Animina.Accounts.Scope

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"

  def unique_mobile_phone,
    do: "+4917#{:rand.uniform(99_999_999) |> Integer.to_string() |> String.pad_leading(8, "0")}"

  def valid_user_password, do: "hello world!"

  def germany_id do
    germany = Animina.GeoData.get_country_by_code("DE")
    germany.id
  end

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      first_name: "Test",
      last_name: "User",
      display_name: "Test User",
      birthday: ~D[1990-01-01],
      gender: "male",
      height: 180,
      mobile_phone: unique_mobile_phone(),
      preferred_partner_gender: ["female"],
      terms_accepted: true,
      language: "en",
      locations: [%{country_id: germany_id(), zip_code: "10115"}]
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    user
  end

  def user_fixture(attrs \\ %{}) do
    attrs
    |> unconfirmed_user_fixture()
    |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now(:second))
    |> Animina.Repo.update!()
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    roles = Accounts.get_user_roles(user)
    Scope.for_user(user, roles, "user")
  end

  def admin_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)
    {:ok, _} = Accounts.assign_role(user, "admin")
    user
  end

  def moderator_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)
    {:ok, _} = Accounts.assign_role(user, "moderator")
    user
  end

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Animina.Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Animina.Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end

  @doc """
  Backdates a confirmed user's `inserted_at` and `confirmed_at` timestamps.

  ## Options

    * `:days_ago` - number of days to shift back (required)

  """
  def backdate_user(%Accounts.User{} = user, days_ago: days) do
    dt = DateTime.utc_now(:second) |> DateTime.add(-days, :day)

    Animina.Repo.update_all(
      from(u in Accounts.User, where: u.id == ^user.id),
      set: [inserted_at: dt, confirmed_at: dt]
    )
  end
end
