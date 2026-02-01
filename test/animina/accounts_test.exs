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

      assert "Referral code not found" in errors_on(changeset).referral_code_input
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

  describe "update_user_profile/2" do
    test "updates profile fields", %{} do
      user = user_fixture()

      assert {:ok, updated} =
               Accounts.update_user_profile(user, %{
                 display_name: "New Name",
                 height: 175,
                 occupation: "Developer",
                 language: "en"
               })

      assert updated.display_name == "New Name"
      assert updated.height == 175
      assert updated.occupation == "Developer"
      assert updated.language == "en"
    end

    test "validates display_name length" do
      user = user_fixture()
      {:error, changeset} = Accounts.update_user_profile(user, %{display_name: "A"})
      assert "should be at least 2 character(s)" in errors_on(changeset).display_name
    end

    test "validates height range" do
      user = user_fixture()
      {:error, changeset} = Accounts.update_user_profile(user, %{height: 50})
      assert "must be greater than or equal to 80" in errors_on(changeset).height
    end

    test "validates language inclusion" do
      user = user_fixture()
      {:error, changeset} = Accounts.update_user_profile(user, %{language: "xx"})
      assert "is invalid" in errors_on(changeset).language
    end
  end

  describe "update_user_preferences/2" do
    test "updates preference fields" do
      user = user_fixture()

      assert {:ok, updated} =
               Accounts.update_user_preferences(user, %{
                 search_radius: 100,
                 partner_height_min: 160,
                 partner_height_max: 200
               })

      assert updated.search_radius == 100
      assert updated.partner_height_min == 160
      assert updated.partner_height_max == 200
    end

    test "validates search_radius minimum" do
      user = user_fixture()
      {:error, changeset} = Accounts.update_user_preferences(user, %{search_radius: 0})
      assert "must be greater than or equal to 1" in errors_on(changeset).search_radius
    end

    test "validates partner_height range" do
      user = user_fixture()
      {:error, changeset} = Accounts.update_user_preferences(user, %{partner_height_min: 50})
      assert "must be greater than or equal to 80" in errors_on(changeset).partner_height_min
    end

    test "computes age offsets from virtual age fields" do
      user = user_fixture()

      {:ok, updated} =
        Accounts.update_user_preferences(user, %{
          partner_minimum_age: 25,
          partner_maximum_age: 45
        })

      # User was born 1990-01-01, so age should be 36 (in 2026)
      user_age = Date.utc_today().year - 1990

      user_age =
        if {Date.utc_today().month, Date.utc_today().day} < {1, 1},
          do: user_age - 1,
          else: user_age

      assert updated.partner_minimum_age_offset == user_age - 25
      assert updated.partner_maximum_age_offset == 45 - user_age
    end
  end

  describe "user locations" do
    test "list_user_locations/1 returns locations for a user" do
      user = user_fixture()
      locations = Accounts.list_user_locations(user)
      assert length(locations) == 1
      assert hd(locations).zip_code == "10115"
    end

    test "add_user_location/2 adds a location" do
      user = user_fixture()

      assert {:ok, location} =
               Accounts.add_user_location(user, %{
                 country_id: germany_id(),
                 zip_code: "80331"
               })

      assert location.zip_code == "80331"
      assert location.position == 2

      locations = Accounts.list_user_locations(user)
      assert length(locations) == 2
    end

    test "add_user_location/2 rejects more than 4 locations" do
      user = user_fixture()

      # Already has 1 location, add 3 more
      for zip <- ["80331", "20095", "50667"] do
        {:ok, _} = Accounts.add_user_location(user, %{country_id: germany_id(), zip_code: zip})
      end

      assert {:error, :max_locations_reached} =
               Accounts.add_user_location(user, %{
                 country_id: germany_id(),
                 zip_code: "60311"
               })
    end

    test "remove_user_location/2 removes a location when more than one exist" do
      user = user_fixture()
      {:ok, _} = Accounts.add_user_location(user, %{country_id: germany_id(), zip_code: "80331"})
      assert length(Accounts.list_user_locations(user)) == 2
      [location | _] = Accounts.list_user_locations(user)

      assert {:ok, _} = Accounts.remove_user_location(user, location.id)
      assert length(Accounts.list_user_locations(user)) == 1
    end

    test "remove_user_location/2 prevents removing the last location" do
      user = user_fixture()
      [location] = Accounts.list_user_locations(user)

      assert {:error, :last_location} = Accounts.remove_user_location(user, location.id)
      assert length(Accounts.list_user_locations(user)) == 1
    end

    test "remove_user_location/2 returns error for non-existent location" do
      user = user_fixture()
      {:ok, _} = Accounts.add_user_location(user, %{country_id: germany_id(), zip_code: "80331"})

      assert {:error, :not_found} =
               Accounts.remove_user_location(user, "11111111-1111-1111-1111-111111111111")
    end
  end

  describe "soft_delete_user/1" do
    test "sets deleted_at on the user" do
      user = user_fixture()
      assert {:ok, deleted_user} = Accounts.soft_delete_user(user)
      assert deleted_user.deleted_at != nil
    end

    test "deletes all session tokens" do
      user = user_fixture()
      _token = Accounts.generate_user_session_token(user)
      assert {:ok, _} = Accounts.soft_delete_user(user)
      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "user_deleted?/1" do
    test "returns false for nil" do
      refute Accounts.user_deleted?(nil)
    end

    test "returns false for user without deleted_at" do
      user = user_fixture()
      refute Accounts.user_deleted?(user)
    end

    test "returns true for user with deleted_at" do
      user = user_fixture()
      {:ok, deleted_user} = Accounts.soft_delete_user(user)
      assert Accounts.user_deleted?(deleted_user)
    end
  end

  describe "purge_deleted_users/0" do
    test "deletes users with deleted_at older than 30 days" do
      user = user_fixture()
      {:ok, _} = Accounts.soft_delete_user(user)

      # Set deleted_at to 31 days ago
      Repo.update_all(
        from(u in User, where: u.id == ^user.id),
        set: [deleted_at: DateTime.add(DateTime.utc_now(), -31, :day)]
      )

      {count, _} = Accounts.purge_deleted_users()
      assert count >= 1
      refute Repo.get(User, user.id)
    end

    test "does not delete users with recent deleted_at" do
      user = user_fixture()
      {:ok, _} = Accounts.soft_delete_user(user)

      {count, _} = Accounts.purge_deleted_users()
      assert count == 0
      assert Repo.get(User, user.id)
    end

    test "does not delete active users" do
      user = user_fixture()
      {count, _} = Accounts.purge_deleted_users()
      assert count == 0
      assert Repo.get(User, user.id)
    end
  end

  describe "get_user_by_email_and_password/2 with soft-deleted user" do
    test "does not return soft-deleted user" do
      user = user_fixture() |> set_password()
      {:ok, _} = Accounts.soft_delete_user(user)
      refute Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_deleted_user_by_email_and_password/2" do
    test "returns soft-deleted user with correct password within grace period" do
      user = user_fixture() |> set_password()
      {:ok, deleted_user} = Accounts.soft_delete_user(user)

      found =
        Accounts.get_deleted_user_by_email_and_password(deleted_user.email, valid_user_password())

      assert found.id == user.id
    end

    test "returns nil with wrong password" do
      user = user_fixture() |> set_password()
      {:ok, deleted_user} = Accounts.soft_delete_user(user)

      refute Accounts.get_deleted_user_by_email_and_password(deleted_user.email, "wrongpassword!")
    end

    test "returns nil when grace period expired" do
      user = user_fixture() |> set_password()
      {:ok, _} = Accounts.soft_delete_user(user)

      # Set deleted_at to 31 days ago
      Repo.update_all(
        from(u in User, where: u.id == ^user.id),
        set: [deleted_at: DateTime.add(DateTime.utc_now(), -31, :day)]
      )

      refute Accounts.get_deleted_user_by_email_and_password(user.email, valid_user_password())
    end

    test "returns nil for active (non-deleted) user" do
      user = user_fixture() |> set_password()
      refute Accounts.get_deleted_user_by_email_and_password(user.email, valid_user_password())
    end

    test "picks most recently deleted user when multiple soft-deleted rows exist" do
      user1 = user_fixture() |> set_password()
      email = user1.email
      {:ok, _} = Accounts.soft_delete_user(user1)

      # Set deleted_at to 10 days ago for the first one
      Repo.update_all(
        from(u in User, where: u.id == ^user1.id),
        set: [deleted_at: DateTime.add(DateTime.utc_now(), -10, :day)]
      )

      # Create a second user with the same email (partial index allows this)
      user2 = user_fixture(email: email) |> set_password()
      {:ok, deleted_user2} = Accounts.soft_delete_user(user2)

      found = Accounts.get_deleted_user_by_email_and_password(email, valid_user_password())
      assert found.id == deleted_user2.id
    end
  end

  describe "reactivate_user/1" do
    test "clears deleted_at on soft-deleted user" do
      user = user_fixture()
      {:ok, deleted_user} = Accounts.soft_delete_user(user)
      assert deleted_user.deleted_at != nil

      {:ok, reactivated} = Accounts.reactivate_user(deleted_user)
      assert reactivated.deleted_at == nil
    end

    test "fails with unique constraint error when email is claimed by another active user" do
      user1 = user_fixture()
      email = user1.email
      {:ok, deleted_user1} = Accounts.soft_delete_user(user1)

      # Register a new user with the same email (partial index allows this)
      _user2 = user_fixture(email: email)

      # Reactivation should fail because email is taken by active user
      assert {:error, changeset} = Accounts.reactivate_user(deleted_user1)
      assert errors_on(changeset).email != nil
    end
  end

  describe "hard_delete_user/1" do
    test "permanently removes user record" do
      user = user_fixture()
      {:ok, deleted_user} = Accounts.soft_delete_user(user)

      assert {:ok, _} = Accounts.hard_delete_user(deleted_user)
      refute Repo.get(User, user.id)
    end
  end

  describe "within_grace_period?/1" do
    test "returns true when deleted_at is within 30 days" do
      user = user_fixture()
      {:ok, deleted_user} = Accounts.soft_delete_user(user)
      assert Accounts.within_grace_period?(deleted_user)
    end

    test "returns false when deleted_at is older than 30 days" do
      user = user_fixture()
      {:ok, _} = Accounts.soft_delete_user(user)

      Repo.update_all(
        from(u in User, where: u.id == ^user.id),
        set: [deleted_at: DateTime.add(DateTime.utc_now(), -31, :day)]
      )

      stale_user = Repo.get!(User, user.id)
      refute Accounts.within_grace_period?(stale_user)
    end

    test "returns false for user without deleted_at" do
      user = user_fixture()
      refute Accounts.within_grace_period?(user)
    end
  end

  describe "soft_delete_user/1 sends goodbye email" do
    test "delivers account deletion goodbye email" do
      user = user_fixture()
      {:ok, _deleted_user} = Accounts.soft_delete_user(user)

      assert_received {:email, %{text_body: body}}
      assert body =~ "ANIMINA"
      assert body =~ user.display_name
    end
  end

  describe "registration with soft-deleted email" do
    test "allows registration with an email that belongs to a soft-deleted user" do
      user = user_fixture()
      email = user.email
      {:ok, _} = Accounts.soft_delete_user(user)

      # Register a new user with the same email
      {:ok, new_user} = Accounts.register_user(valid_user_attributes(email: email))
      assert new_user.email == email
      assert new_user.id != user.id
    end
  end

  describe "get_user_by_email/1 with partial index" do
    test "returns active user when both active and soft-deleted users share email" do
      user1 = user_fixture()
      email = user1.email
      {:ok, _} = Accounts.soft_delete_user(user1)

      # Register new active user with same email
      user2 = user_fixture(email: email)

      found = Accounts.get_user_by_email(email)
      assert found.id == user2.id
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "get_user_roles/1" do
    test "returns only user role for a user with no extra roles" do
      user = user_fixture()
      assert Accounts.get_user_roles(user) == ["user"]
    end

    test "returns user + assigned roles" do
      user = user_fixture()
      {:ok, _} = Accounts.assign_role(user, "admin")
      assert "user" in Accounts.get_user_roles(user)
      assert "admin" in Accounts.get_user_roles(user)
    end

    test "returns all assigned roles" do
      user = user_fixture()
      {:ok, _} = Accounts.assign_role(user, "admin")
      {:ok, _} = Accounts.assign_role(user, "moderator")
      roles = Accounts.get_user_roles(user)
      assert "user" in roles
      assert "admin" in roles
      assert "moderator" in roles
    end
  end

  describe "assign_role/2" do
    test "assigns admin role to user" do
      user = user_fixture()
      assert {:ok, _} = Accounts.assign_role(user, "admin")
      assert Accounts.has_role?(user, "admin")
    end

    test "assigns moderator role to user" do
      user = user_fixture()
      assert {:ok, _} = Accounts.assign_role(user, "moderator")
      assert Accounts.has_role?(user, "moderator")
    end

    test "is idempotent - assigning same role twice succeeds" do
      user = user_fixture()
      assert {:ok, _} = Accounts.assign_role(user, "admin")
      assert {:ok, _} = Accounts.assign_role(user, "admin")
      assert Accounts.has_role?(user, "admin")
    end
  end

  describe "remove_role/2" do
    test "removes an assigned role" do
      user = user_fixture()
      other_admin = user_fixture()
      {:ok, _} = Accounts.assign_role(user, "admin")
      {:ok, _} = Accounts.assign_role(other_admin, "admin")
      assert {:ok, _} = Accounts.remove_role(user, "admin")
      refute Accounts.has_role?(user, "admin")
    end

    test "returns error when removing the implicit user role" do
      user = user_fixture()
      assert {:error, :implicit_role} = Accounts.remove_role(user, "user")
    end

    test "returns error when role not found" do
      user = user_fixture()
      assert {:error, :not_found} = Accounts.remove_role(user, "admin")
    end

    test "prevents removing admin role from the last admin" do
      user = user_fixture()
      {:ok, _} = Accounts.assign_role(user, "admin")
      assert {:error, :last_admin} = Accounts.remove_role(user, "admin")
    end

    test "allows removing admin role when another admin exists" do
      user1 = user_fixture()
      user2 = user_fixture()
      {:ok, _} = Accounts.assign_role(user1, "admin")
      {:ok, _} = Accounts.assign_role(user2, "admin")
      assert {:ok, _} = Accounts.remove_role(user1, "admin")
    end
  end

  describe "has_role?/2" do
    test "always returns true for user role" do
      user = user_fixture()
      assert Accounts.has_role?(user, "user")
    end

    test "returns true for assigned role" do
      user = user_fixture()
      {:ok, _} = Accounts.assign_role(user, "admin")
      assert Accounts.has_role?(user, "admin")
    end

    test "returns false for unassigned role" do
      user = user_fixture()
      refute Accounts.has_role?(user, "admin")
    end
  end

  describe "search_users/1" do
    test "finds users by email" do
      user = user_fixture()
      results = Accounts.search_users(user.email)
      assert length(results) >= 1
      assert Enum.any?(results, &(&1.id == user.id))
    end

    test "finds users by display name" do
      user = user_fixture()
      results = Accounts.search_users(user.display_name)
      assert length(results) >= 1
      assert Enum.any?(results, &(&1.id == user.id))
    end

    test "returns empty list for empty query" do
      assert Accounts.search_users("") == []
    end

    test "returns empty list for nil query" do
      assert Accounts.search_users(nil) == []
    end

    test "does not find soft-deleted users" do
      user = user_fixture()
      {:ok, _} = Accounts.soft_delete_user(user)
      results = Accounts.search_users(user.email)
      refute Enum.any?(results, &(&1.id == user.id))
    end
  end
end
