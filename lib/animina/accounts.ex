defmodule Animina.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Animina.Repo

  alias Animina.Accounts.{User, UserLocation, UserToken, UserNotifier}

  @referral_auto_activate_threshold 5

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user. Returns `nil` if the user does not exist.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a user by referral code (case-insensitive, trimmed).
  Returns `nil` if no user is found.
  """
  def get_user_by_referral_code(nil), do: nil
  def get_user_by_referral_code(""), do: nil

  def get_user_by_referral_code(code) when is_binary(code) do
    Repo.get_by(User, referral_code: code |> String.trim() |> String.upcase())
  end

  @doc """
  Counts the number of confirmed referrals for a user.
  A confirmed referral is a user who has `referred_by_id` set and `confirmed_at` not nil.
  """
  def count_confirmed_referrals(%User{id: user_id}) do
    from(u in User,
      where: u.referred_by_id == ^user_id,
      where: not is_nil(u.confirmed_at),
      select: count()
    )
    |> Repo.one()
  end

  @doc """
  Processes referral credit after PIN confirmation.
  Increments `waitlist_priority` for both the referred user and the referrer.
  Auto-activates either user if they reach the threshold of #{@referral_auto_activate_threshold} referrals.
  """
  def process_referral(%User{referred_by_id: nil}), do: :ok

  def process_referral(%User{referred_by_id: referrer_id} = user) do
    # Increment waitlist_priority for the referred user
    from(u in User, where: u.id == ^user.id)
    |> Repo.update_all(inc: [waitlist_priority: 1])

    # Increment waitlist_priority for the referrer
    from(u in User, where: u.id == ^referrer_id)
    |> Repo.update_all(inc: [waitlist_priority: 1])

    # Check auto-activation for referrer
    maybe_auto_activate(referrer_id)

    # Check auto-activation for referred user
    maybe_auto_activate(user.id)

    :ok
  end

  defp maybe_auto_activate(user_id) do
    referral_count =
      from(u in User,
        where: u.referred_by_id == ^user_id,
        where: not is_nil(u.confirmed_at),
        select: count()
      )
      |> Repo.one()

    if referral_count >= @referral_auto_activate_threshold do
      from(u in User,
        where: u.id == ^user_id,
        where: u.state == "waitlisted"
      )
      |> Repo.update_all(set: [state: "normal"])
    end
  end

  @doc """
  Counts the number of users who registered and confirmed (PIN verified)
  within the last 24 hours.
  """
  def count_confirmed_users_last_24h do
    cutoff = DateTime.utc_now() |> DateTime.add(-24, :hour)

    from(u in User,
      where: not is_nil(u.confirmed_at),
      where: u.inserted_at >= ^cutoff,
      select: count()
    )
    |> Repo.one()
  end

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    locations_attrs = extract_locations(attrs)
    referral_code_input = extract_referral_code_input(attrs)

    Repo.transact(fn ->
      changeset = User.registration_changeset(%User{}, attrs)

      changeset = resolve_referral_code(changeset, referral_code_input)

      with {:ok, user} <- insert_with_referral_code_retry(changeset),
           :ok <- insert_locations(user, locations_attrs) do
        {:ok, user}
      end
    end)
  end

  @doc """
  Returns `true` if the changeset contains an email uniqueness error,
  covering both `unsafe_validate_unique` (validation: :unsafe_unique)
  and `unique_constraint` (constraint: :unique).
  """
  def email_uniqueness_error?(%Ecto.Changeset{} = changeset) do
    changeset.errors
    |> Keyword.get_values(:email)
    |> Enum.any?(fn {_msg, meta} ->
      meta[:validation] == :unsafe_unique or meta[:constraint] == :unique
    end)
  end

  @doc """
  Returns `true` when the email uniqueness error is the **only** error
  on the changeset (i.e. all other fields are valid).
  """
  def only_email_uniqueness_error?(%Ecto.Changeset{} = changeset) do
    email_uniqueness_error?(changeset) and
      changeset.errors
      |> Enum.reject(fn {field, {_msg, meta}} ->
        field == :email and
          (meta[:validation] == :unsafe_unique or meta[:constraint] == :unique)
      end)
      |> Enum.empty?()
  end

  defp extract_referral_code_input(attrs) do
    val = Map.get(attrs, :referral_code_input) || Map.get(attrs, "referral_code_input")

    case val do
      nil -> nil
      v when is_binary(v) -> String.trim(v)
      _ -> nil
    end
  end

  defp resolve_referral_code(changeset, nil), do: changeset
  defp resolve_referral_code(changeset, ""), do: changeset

  defp resolve_referral_code(changeset, code) do
    case get_user_by_referral_code(code) do
      nil ->
        Ecto.Changeset.add_error(
          changeset,
          :referral_code_input,
          "Empfehlungscode nicht gefunden"
        )

      referrer ->
        Ecto.Changeset.put_change(changeset, :referred_by_id, referrer.id)
    end
  end

  defp insert_with_referral_code_retry(changeset, attempts \\ 3) do
    case Repo.insert(changeset) do
      {:ok, user} ->
        {:ok, user}

      {:error, %Ecto.Changeset{errors: errors} = cs} ->
        if attempts > 1 && Keyword.has_key?(errors, :referral_code) do
          changeset
          |> Ecto.Changeset.put_change(:referral_code, User.generate_referral_code())
          |> insert_with_referral_code_retry(attempts - 1)
        else
          {:error, cs}
        end
    end
  end

  defp extract_locations(attrs) do
    locations =
      Map.get(attrs, :locations) || Map.get(attrs, "locations") || []

    locations
    |> Enum.with_index(1)
    |> Enum.map(fn {loc, idx} ->
      %{
        country_id: loc[:country_id] || loc["country_id"],
        zip_code: loc[:zip_code] || loc["zip_code"],
        position: idx
      }
    end)
  end

  defp insert_locations(_user, []) do
    :ok
  end

  defp insert_locations(user, locations) do
    results =
      Enum.reduce_while(locations, :ok, fn loc_attrs, :ok ->
        changeset =
          UserLocation.changeset(%UserLocation{}, Map.put(loc_attrs, :user_id, user.id))

        case Repo.insert(changeset) do
          {:ok, _location} -> {:cont, :ok}
          {:error, changeset} -> {:halt, {:error, changeset}}
        end
      end)

    results
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user registration changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(user, attrs \\ %{}, opts \\ []) do
    User.registration_changeset(
      user,
      attrs,
      [hash_password: false, validate_unique: false] ++ opts
    )
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `Animina.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `Animina.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Password reset

  @doc ~S"""
  Delivers the password reset instructions to the given user.

  ## Examples

      iex> deliver_user_password_reset_instructions(user, &url(~p"/users/reset-password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_password_reset_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_password_reset_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by password reset token.

  ## Examples

      iex> get_user_by_password_reset_token("validtoken")
      %User{}

      iex> get_user_by_password_reset_token("invalidtoken")
      nil

  """
  def get_user_by_password_reset_token(token) do
    with {:ok, query} <- UserToken.verify_password_reset_token_query(token),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password"})
      {:ok, %User{}}

  """
  def reset_user_password(user, attrs) do
    Repo.transact(fn ->
      with {:ok, user} <- user |> User.password_changeset(attrs) |> Repo.update() do
        Repo.delete_all(from(t in UserToken, where: t.user_id == ^user.id))
        {:ok, user}
      end
    end)
  end

  ## Confirmation PIN

  @pin_max_attempts 3
  @pin_validity_minutes 30

  @doc """
  Generates a random 6-digit confirmation PIN.
  """
  def generate_confirmation_pin do
    :rand.uniform(999_999) |> Integer.to_string() |> String.pad_leading(6, "0")
  end

  @doc """
  Generates a PIN, stores its hash on the user, and sends it via email.
  Returns `{:ok, pin}` on success.
  """
  def send_confirmation_pin(%User{} = user) do
    pin = generate_confirmation_pin()

    case user
         |> User.confirmation_pin_changeset(pin)
         |> Repo.update() do
      {:ok, updated_user} ->
        UserNotifier.deliver_confirmation_pin(updated_user, pin)
        {:ok, pin}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Verifies a confirmation PIN for the given user.

  Returns:
    - `{:ok, user}` on correct PIN (user is confirmed, PIN fields cleared)
    - `{:error, :wrong_pin}` on incorrect PIN (attempts incremented)
    - `{:error, :too_many_attempts}` when max attempts exceeded (user deleted)
    - `{:error, :expired}` when PIN has expired (user deleted)
    - `{:error, :not_found}` when user is nil
  """
  def verify_confirmation_pin(nil, _pin), do: {:error, :not_found}

  def verify_confirmation_pin(%User{} = user, pin) do
    cond do
      pin_expired?(user) ->
        Repo.delete(user)
        {:error, :expired}

      user.confirmation_pin_attempts >= @pin_max_attempts ->
        Repo.delete(user)
        {:error, :too_many_attempts}

      User.verify_confirmation_pin(user, pin) ->
        result =
          user
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_change(:confirmed_at, DateTime.utc_now(:second))
          |> Ecto.Changeset.put_change(:confirmation_pin_hash, nil)
          |> Ecto.Changeset.put_change(:confirmation_pin_attempts, 0)
          |> Ecto.Changeset.put_change(:confirmation_pin_sent_at, nil)
          |> Repo.update()

        case result do
          {:ok, confirmed_user} ->
            process_referral(confirmed_user)
            {:ok, confirmed_user}

          error ->
            error
        end

      true ->
        user
        |> User.increment_pin_attempts_changeset()
        |> Repo.update!()

        new_attempts = user.confirmation_pin_attempts + 1

        if new_attempts >= @pin_max_attempts do
          Repo.delete(Repo.get!(User, user.id))
          {:error, :too_many_attempts}
        else
          {:error, :wrong_pin}
        end
    end
  end

  defp pin_expired?(%User{confirmation_pin_sent_at: nil}), do: true

  defp pin_expired?(%User{confirmation_pin_sent_at: sent_at}) do
    DateTime.diff(DateTime.utc_now(), sent_at, :minute) >= @pin_validity_minutes
  end

  @doc """
  Deletes all unconfirmed users whose confirmation PIN has expired.
  """
  def delete_expired_unconfirmed_users do
    cutoff = DateTime.utc_now() |> DateTime.add(-@pin_validity_minutes, :minute)

    from(u in User,
      where: is_nil(u.confirmed_at),
      where: not is_nil(u.confirmation_pin_sent_at),
      where: u.confirmation_pin_sent_at < ^cutoff
    )
    |> Repo.delete_all()
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
