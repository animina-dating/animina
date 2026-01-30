defmodule Animina.AccountsTest do
  use Animina.DataCase

  alias Animina.Accounts

  import Animina.AccountsFixtures
  alias Animina.Accounts.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture() |> set_password()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture() |> set_password()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!("11111111-1111-1111-1111-111111111111")
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email and profile fields to be set" do
      {:error, changeset} = Accounts.register_user(%{})
      errors = errors_on(changeset)

      assert %{email: ["can't be blank"]} = errors
      assert %{display_name: ["can't be blank"]} = errors
      assert %{birthday: ["can't be blank"]} = errors
      assert %{gender: ["can't be blank"]} = errors
      assert %{height: ["can't be blank"]} = errors
      assert %{mobile_phone: ["can't be blank"]} = errors
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the uppercased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users with all required fields" do
      email = unique_user_email()
      attrs = valid_user_attributes(email: email)
      {:ok, user} = Accounts.register_user(attrs)
      assert user.email == email
      assert user.display_name == "Test User"
      assert user.gender == "male"
      assert user.height == 180
      assert user.state == "waitlisted"
      assert user.terms_accepted_at != nil
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end

    test "validates birthday is at least 18 years old" do
      attrs = valid_user_attributes(birthday: Date.utc_today())
      {:error, changeset} = Accounts.register_user(attrs)
      assert "you must be at least 18 years old" in errors_on(changeset).birthday
    end

    test "validates gender inclusion" do
      attrs = valid_user_attributes(gender: "invalid")
      {:error, changeset} = Accounts.register_user(attrs)
      assert "is invalid" in errors_on(changeset).gender
    end

    test "accepts multiple preferred partner genders" do
      attrs = valid_user_attributes(preferred_partner_gender: ["male", "female"])
      {:ok, user} = Accounts.register_user(attrs)
      assert user.preferred_partner_gender == ["male", "female"]
    end

    test "validates preferred partner gender values" do
      attrs = valid_user_attributes(preferred_partner_gender: ["invalid"])
      {:error, changeset} = Accounts.register_user(attrs)
      assert "contains invalid gender" in errors_on(changeset).preferred_partner_gender
    end

    test "validates terms must be accepted" do
      attrs = valid_user_attributes(terms_accepted: false)
      {:error, changeset} = Accounts.register_user(attrs)
      assert "must be accepted" in errors_on(changeset).terms_accepted
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %User{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%User{})
    end
  end

  describe "change_user_email/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = unconfirmed_user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_user_email(user, token)
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_user_email(user, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(
          %User{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, {user, expired_tokens}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, {_, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given user in new token", %{user: user} do
      user = %{user | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.authenticated_at == user.authenticated_at
      assert DateTime.compare(user_token.inserted_at, user.authenticated_at) == :gt
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert session_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "get_user/1" do
    test "returns user when found" do
      user = user_fixture()
      assert %User{id: id} = Accounts.get_user(user.id)
      assert id == user.id
    end

    test "returns nil when not found" do
      refute Accounts.get_user("11111111-1111-1111-1111-111111111111")
    end
  end

  describe "generate_confirmation_pin/0" do
    test "generates a 6-digit string" do
      pin = Accounts.generate_confirmation_pin()
      assert String.length(pin) == 6
      assert Regex.match?(~r/^\d{6}$/, pin)
    end
  end

  describe "send_confirmation_pin/1" do
    test "stores hashed PIN and sends email" do
      user = unconfirmed_user_fixture()
      {:ok, pin} = Accounts.send_confirmation_pin(user)

      assert String.length(pin) == 6
      updated = Repo.get!(User, user.id)
      assert updated.confirmation_pin_hash != nil
      assert updated.confirmation_pin_attempts == 0
      assert updated.confirmation_pin_sent_at != nil
    end
  end

  describe "verify_confirmation_pin/2" do
    setup do
      user = unconfirmed_user_fixture()
      {:ok, pin} = Accounts.send_confirmation_pin(user)
      user = Repo.get!(User, user.id)
      %{user: user, pin: pin}
    end

    test "confirms user with correct PIN", %{user: user, pin: pin} do
      assert {:ok, confirmed_user} = Accounts.verify_confirmation_pin(user, pin)
      assert confirmed_user.confirmed_at != nil
      assert confirmed_user.confirmation_pin_hash == nil
    end

    test "returns error with wrong PIN", %{user: user} do
      assert {:error, :wrong_pin} = Accounts.verify_confirmation_pin(user, "000000")
      updated = Repo.get!(User, user.id)
      assert updated.confirmation_pin_attempts == 1
    end

    test "deletes user after 3 failed attempts", %{user: user} do
      assert {:error, :wrong_pin} = Accounts.verify_confirmation_pin(user, "000000")
      user = Repo.get!(User, user.id)
      assert {:error, :wrong_pin} = Accounts.verify_confirmation_pin(user, "000000")
      user = Repo.get!(User, user.id)
      assert {:error, :too_many_attempts} = Accounts.verify_confirmation_pin(user, "000000")
      refute Repo.get(User, user.id)
    end

    test "returns error for nil user" do
      assert {:error, :not_found} = Accounts.verify_confirmation_pin(nil, "123456")
    end

    test "returns expired when PIN is too old", %{user: user} do
      # Set sent_at to 31 minutes ago
      Repo.update_all(
        from(u in User, where: u.id == ^user.id),
        set: [confirmation_pin_sent_at: DateTime.add(DateTime.utc_now(), -31, :minute)]
      )

      user = Repo.get!(User, user.id)
      assert {:error, :expired} = Accounts.verify_confirmation_pin(user, "123456")
      refute Repo.get(User, user.id)
    end
  end

  describe "delete_expired_unconfirmed_users/0" do
    test "deletes expired unconfirmed users" do
      user = unconfirmed_user_fixture()
      {:ok, _pin} = Accounts.send_confirmation_pin(user)

      # Set sent_at to 31 minutes ago
      Repo.update_all(
        from(u in User, where: u.id == ^user.id),
        set: [confirmation_pin_sent_at: DateTime.add(DateTime.utc_now(), -31, :minute)]
      )

      {count, _} = Accounts.delete_expired_unconfirmed_users()
      assert count >= 1
      refute Repo.get(User, user.id)
    end

    test "does not delete confirmed users" do
      user = user_fixture()
      {count, _} = Accounts.delete_expired_unconfirmed_users()
      assert count == 0
      assert Repo.get(User, user.id)
    end

    test "does not delete users with recent PINs" do
      user = unconfirmed_user_fixture()
      {:ok, _pin} = Accounts.send_confirmation_pin(user)

      {count, _} = Accounts.delete_expired_unconfirmed_users()
      assert count == 0
      assert Repo.get(User, user.id)
    end
  end

  describe "referral system" do
    test "user gets a referral_code upon registration" do
      user = unconfirmed_user_fixture()
      assert user.referral_code != nil
      assert String.length(user.referral_code) == 6
      assert Regex.match?(~r/^[A-Z0-9]{6}$/, user.referral_code)
    end

    test "get_user_by_referral_code/1 returns user or nil" do
      user = unconfirmed_user_fixture()
      assert %User{id: id} = Accounts.get_user_by_referral_code(user.referral_code)
      assert id == user.id

      # Case insensitive
      assert %User{} = Accounts.get_user_by_referral_code(String.downcase(user.referral_code))

      assert is_nil(Accounts.get_user_by_referral_code("ZZZZZZ"))
      assert is_nil(Accounts.get_user_by_referral_code(nil))
      assert is_nil(Accounts.get_user_by_referral_code(""))
    end

    test "registration with valid referral code sets referred_by_id" do
      referrer = unconfirmed_user_fixture()

      {:ok, referred} =
        valid_user_attributes(referral_code_input: referrer.referral_code)
        |> Accounts.register_user()

      assert referred.referred_by_id == referrer.id
    end

    test "registration with invalid referral code returns changeset error" do
      {:error, changeset} =
        valid_user_attributes(referral_code_input: "ZZZZZZ")
        |> Accounts.register_user()

      assert "Empfehlungscode nicht gefunden" in errors_on(changeset).referral_code_input
    end

    test "registration with empty referral code succeeds without referrer" do
      {:ok, user} =
        valid_user_attributes(referral_code_input: "")
        |> Accounts.register_user()

      assert is_nil(user.referred_by_id)
    end

    test "PIN confirmation increments waitlist_priority for both users" do
      referrer = unconfirmed_user_fixture()

      {:ok, referred} =
        valid_user_attributes(referral_code_input: referrer.referral_code)
        |> Accounts.register_user()

      {:ok, pin} = Accounts.send_confirmation_pin(referred)
      referred = Repo.get!(User, referred.id)

      {:ok, _confirmed} = Accounts.verify_confirmation_pin(referred, pin)

      updated_referrer = Repo.get!(User, referrer.id)
      updated_referred = Repo.get!(User, referred.id)

      assert updated_referrer.waitlist_priority == 1
      assert updated_referred.waitlist_priority == 1
    end

    test "auto-activates user after 5 successful referrals" do
      referrer = unconfirmed_user_fixture()

      # Confirm the referrer first so they have confirmed_at set
      {:ok, pin} = Accounts.send_confirmation_pin(referrer)
      referrer = Repo.get!(User, referrer.id)
      {:ok, referrer} = Accounts.verify_confirmation_pin(referrer, pin)
      assert referrer.state == "waitlisted"

      for _i <- 1..5 do
        {:ok, referred} =
          valid_user_attributes(referral_code_input: referrer.referral_code)
          |> Accounts.register_user()

        {:ok, ref_pin} = Accounts.send_confirmation_pin(referred)
        referred = Repo.get!(User, referred.id)
        {:ok, _confirmed} = Accounts.verify_confirmation_pin(referred, ref_pin)
      end

      updated_referrer = Repo.get!(User, referrer.id)
      assert updated_referrer.state == "normal"
      assert updated_referrer.waitlist_priority == 5
    end

    test "count_confirmed_referrals/1 returns correct count" do
      referrer = unconfirmed_user_fixture()

      assert Accounts.count_confirmed_referrals(referrer) == 0

      # Create an unconfirmed referred user
      {:ok, _referred} =
        valid_user_attributes(referral_code_input: referrer.referral_code)
        |> Accounts.register_user()

      # Unconfirmed user should not count
      assert Accounts.count_confirmed_referrals(referrer) == 0

      # Create and confirm a referred user
      {:ok, referred2} =
        valid_user_attributes(referral_code_input: referrer.referral_code)
        |> Accounts.register_user()

      {:ok, pin} = Accounts.send_confirmation_pin(referred2)
      referred2 = Repo.get!(User, referred2.id)
      {:ok, _confirmed} = Accounts.verify_confirmation_pin(referred2, pin)

      assert Accounts.count_confirmed_referrals(referrer) == 1
    end
  end

  describe "count_confirmed_users_last_24h/0" do
    test "returns 0 when no users exist" do
      assert Accounts.count_confirmed_users_last_24h() == 0
    end

    test "counts confirmed users created within the last 24 hours" do
      _user = user_fixture()
      assert Accounts.count_confirmed_users_last_24h() == 1
    end

    test "does not count unconfirmed users" do
      _user = unconfirmed_user_fixture()
      assert Accounts.count_confirmed_users_last_24h() == 0
    end

    test "does not count users older than 24 hours" do
      user = user_fixture()

      Repo.update_all(
        from(u in User, where: u.id == ^user.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -25, :hour)]
      )

      assert Accounts.count_confirmed_users_last_24h() == 0
    end

    test "counts multiple confirmed recent users" do
      _user1 = user_fixture()
      _user2 = user_fixture()
      _unconfirmed = unconfirmed_user_fixture()

      assert Accounts.count_confirmed_users_last_24h() == 2
    end
  end

  describe "deliver_user_password_reset_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_password_reset_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "reset_password"
    end
  end

  describe "get_user_by_password_reset_token/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_password_reset_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = Accounts.get_user_by_password_reset_token(token)
    end

    test "does not return the user with invalid token" do
      refute Accounts.get_user_by_password_reset_token("oops")
    end

    test "does not return the user if token expired", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_password_reset_token(token)
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.reset_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} =
        Accounts.reset_user_password(user, %{password: "new valid password"})

      assert is_nil(updated_user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)
      {:ok, _} = Accounts.reset_user_password(user, %{password: "new valid password"})
      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
