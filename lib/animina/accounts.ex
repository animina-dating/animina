defmodule Animina.Accounts do
  @moduledoc """
  The Accounts context.

  This module acts as a facade, delegating to specialized sub-modules:
  - `Animina.Accounts.Locations` - User location management
  - `Animina.Accounts.Roles` - Role assignment and checking
  - `Animina.Accounts.SoftDelete` - Soft delete and reactivation
  - `Animina.Accounts.Statistics` - User counts and analytics
  """

  import Ecto.Query, warn: false
  use Gettext, backend: AniminaWeb.Gettext

  alias Animina.Accounts.{User, UserLocation, UserNotifier, UserToken}
  alias Animina.Gallery
  alias Animina.Repo
  alias Animina.Utils.PaperTrail, as: PT

  ## Database getters

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    from(u in User,
      where: u.email == ^email,
      order_by: [asc_nulls_first: u.deleted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Gets a user by email and password.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user =
      from(u in User,
        where: u.email == ^email,
        where: is_nil(u.deleted_at),
        limit: 1
      )
      |> Repo.one()

    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user. Raises `Ecto.NoResultsError` if not found.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user. Returns `nil` if not found.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a user by referral code (case-insensitive, trimmed).
  """
  def get_user_by_referral_code(nil), do: nil
  def get_user_by_referral_code(""), do: nil

  def get_user_by_referral_code(code) when is_binary(code) do
    Repo.get_by(User, referral_code: code |> String.trim() |> String.upcase())
  end

  @doc """
  Counts the number of confirmed referrals for a user.
  """
  def count_confirmed_referrals(%User{id: user_id}) do
    count_confirmed_referrals_by_id(user_id)
  end

  defp count_confirmed_referrals_by_id(user_id) do
    from(u in User,
      where: u.referred_by_id == ^user_id,
      where: not is_nil(u.confirmed_at),
      select: count()
    )
    |> Repo.one()
  end

  @doc """
  Processes referral credit after PIN confirmation.
  """
  def process_referral(%User{referred_by_id: nil}), do: :ok

  def process_referral(%User{referred_by_id: referrer_id} = user) do
    from(u in User, where: u.id == ^user.id)
    |> Repo.update_all(inc: [waitlist_priority: 1])

    from(u in User, where: u.id == ^referrer_id)
    |> Repo.update_all(inc: [waitlist_priority: 1])

    maybe_auto_activate(referrer_id)
    maybe_auto_activate(user.id)

    :ok
  end

  defp maybe_auto_activate(user_id) do
    threshold = Animina.FeatureFlags.referral_threshold()

    if count_confirmed_referrals_by_id(user_id) >= threshold do
      from(u in User,
        where: u.id == ^user_id,
        where: u.state == "waitlisted"
      )
      |> Repo.update_all(set: [state: "normal"])
    end
  end

  ## User registration

  @doc """
  Registers a user.
  """
  def register_user(attrs, opts \\ []) do
    locations_attrs = extract_locations(attrs)
    referral_code_input = extract_referral_code_input(attrs)
    pt_opts = PT.opts(opts)

    Repo.transact(fn ->
      changeset = User.registration_changeset(%User{}, attrs)

      changeset = resolve_referral_code(changeset, referral_code_input)

      with {:ok, user} <- insert_with_referral_code_retry(changeset, 3, pt_opts),
           :ok <- insert_locations(user, locations_attrs),
           {:ok, _pinned_item} <- create_pinned_intro_item(user) do
        {:ok, user}
      end
    end)
  end

  defp create_pinned_intro_item(user) do
    Gallery.create_pinned_intro_item(user, default_intro_prompt(user.language))
  end

  defp default_intro_prompt("de"), do: gettext("Erzähl uns etwas über dich...")
  defp default_intro_prompt(_), do: gettext("Tell us about yourself...")

  @doc """
  Returns `true` if the changeset contains an email uniqueness error.
  """
  def email_uniqueness_error?(%Ecto.Changeset{} = changeset) do
    changeset.errors
    |> Keyword.get_values(:email)
    |> Enum.any?(fn {_msg, meta} ->
      meta[:validation] == :unsafe_unique or meta[:constraint] == :unique
    end)
  end

  @doc """
  Returns `true` when the email uniqueness error is the only error.
  """
  def only_email_uniqueness_error?(%Ecto.Changeset{} = changeset) do
    email_uniqueness_error?(changeset) and
      Enum.all?(changeset.errors, fn {field, {_msg, meta}} ->
        field == :email and
          (meta[:validation] == :unsafe_unique or meta[:constraint] == :unique)
      end)
  end

  defp extract_referral_code_input(attrs) do
    val = Map.get(attrs, :referral_code_input) || Map.get(attrs, "referral_code_input")

    case val do
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
          dgettext("errors", "Referral code not found")
        )

      referrer ->
        Ecto.Changeset.put_change(changeset, :referred_by_id, referrer.id)
    end
  end

  defp insert_with_referral_code_retry(changeset, attempts, pt_opts) do
    case PaperTrail.insert(changeset, pt_opts) do
      {:ok, %{model: user}} ->
        {:ok, user}

      {:error, %Ecto.Changeset{errors: errors} = cs} ->
        if attempts > 1 && Keyword.has_key?(errors, :referral_code) do
          changeset
          |> Ecto.Changeset.put_change(:referral_code, User.generate_referral_code())
          |> insert_with_referral_code_retry(attempts - 1, pt_opts)
        else
          {:error, cs}
        end
    end
  end

  defp extract_locations(attrs) do
    (Map.get(attrs, :locations) || Map.get(attrs, "locations") || [])
    |> Enum.with_index(1)
    |> Enum.map(fn {loc, idx} ->
      %{
        country_id: loc[:country_id] || loc["country_id"],
        zip_code: loc[:zip_code] || loc["zip_code"],
        position: idx
      }
    end)
  end

  defp insert_locations(_user, []), do: :ok

  defp insert_locations(user, locations) do
    Enum.reduce_while(locations, :ok, fn loc_attrs, :ok ->
      changeset =
        UserLocation.changeset(%UserLocation{}, Map.put(loc_attrs, :user_id, user.id))

      case Repo.insert(changeset) do
        {:ok, _location} -> {:cont, :ok}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user registration changes.
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
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @change_email_validity_in_minutes 30

  @doc """
  Returns the pending new email address for a user.
  """
  def get_pending_email_change(%User{} = user) do
    context = "change:#{user.email}"

    from(t in UserToken,
      where: t.user_id == ^user.id,
      where: t.context == ^context,
      where: t.inserted_at > ago(@change_email_validity_in_minutes, "minute"),
      select: t.sent_to,
      order_by: [desc: t.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.
  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.
  """
  def update_user_email(user, token, opts \\ []) do
    context = "change:#{user.email}"
    pt_opts = PT.opts(opts)

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <-
             User.email_changeset(user, %{email: email})
             |> PaperTrail.update(pt_opts)
             |> PT.unwrap(),
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
  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.
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
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Delivers the update email instructions to the given user.
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

  @doc """
  Delivers the password reset instructions to the given user.
  """
  def deliver_user_password_reset_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_password_reset_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by password reset token.
  """
  def get_user_by_password_reset_token(token) do
    case UserToken.verify_password_reset_token_query(token) do
      {:ok, query} -> Repo.one(query)
      _ -> nil
    end
  end

  @doc """
  Resets the user password.
  """
  def reset_user_password(user, attrs) do
    Repo.transact(fn ->
      with {:ok, user} <-
             user
             |> User.password_changeset(attrs)
             |> PaperTrail.update()
             |> PT.unwrap() do
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
  """
  def send_confirmation_pin(%User{} = user) do
    pin = generate_confirmation_pin()

    with {:ok, updated_user} <-
           user
           |> User.confirmation_pin_changeset(pin)
           |> PaperTrail.update()
           |> PT.unwrap() do
      UserNotifier.deliver_confirmation_pin(updated_user, pin)
      {:ok, pin}
    end
  end

  @doc """
  Verifies a confirmation PIN for the given user.
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
        with {:ok, confirmed_user} <-
               user
               |> Ecto.Changeset.change()
               |> Ecto.Changeset.put_change(:confirmed_at, DateTime.utc_now(:second))
               |> Ecto.Changeset.put_change(:confirmation_pin_hash, nil)
               |> Ecto.Changeset.put_change(:confirmation_pin_attempts, 0)
               |> Ecto.Changeset.put_change(:confirmation_pin_sent_at, nil)
               |> Repo.update() do
          process_referral(confirmed_user)
          {:ok, confirmed_user}
        end

      true ->
        updated_user =
          user
          |> User.increment_pin_attempts_changeset()
          |> Repo.update!()

        if updated_user.confirmation_pin_attempts >= @pin_max_attempts do
          Repo.delete(updated_user)
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

  ## User profile & preferences

  @doc """
  Returns an `%Ecto.Changeset{}` for changing user profile fields.
  """
  def change_user_profile(user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  @doc """
  Updates the user profile.
  """
  def update_user_profile(user, attrs, opts \\ []) do
    user
    |> User.profile_changeset(attrs)
    |> PaperTrail.update(PT.opts(opts))
    |> PT.unwrap()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing user preferences.
  """
  def change_user_preferences(user, attrs \\ %{}) do
    User.preferences_changeset(user, attrs)
  end

  @doc """
  Updates the user preferences.
  """
  def update_user_preferences(user, attrs, opts \\ []) do
    user
    |> User.preferences_changeset(attrs)
    |> PaperTrail.update(PT.opts(opts))
    |> PT.unwrap()
  end

  @doc """
  Updates the user's language preference.
  """
  def update_user_language(%User{} = user, language, opts \\ []) do
    user
    |> Ecto.Changeset.change(language: language)
    |> PaperTrail.update(PT.opts(opts))
    |> PT.unwrap()
  end

  @doc """
  Updates gallery column preference for a specific device type.
  """
  def update_gallery_columns(%User{} = user, device_type, columns)
      when device_type in ["mobile", "tablet", "desktop"] and columns in [1, 2, 3] do
    field = String.to_existing_atom("gallery_columns_#{device_type}")

    user
    |> User.gallery_columns_changeset(%{field => columns})
    |> Repo.update()
  end

  ## User search

  @doc """
  Searches for active users by email or display name.
  """
  def search_users(query) when is_binary(query) and byte_size(query) > 0 do
    pattern = "%#{query}%"

    from(u in User,
      where: is_nil(u.deleted_at),
      where: ilike(u.email, ^pattern) or ilike(u.display_name, ^pattern),
      order_by: [asc: u.email],
      limit: 20
    )
    |> Repo.all()
  end

  def search_users(_), do: []

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- PaperTrail.update(changeset) |> PT.unwrap() do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  # --- Delegations to Statistics ---

  defdelegate count_confirmed_users_today_berlin(), to: Animina.Accounts.Statistics
  defdelegate average_daily_confirmed_users_last_30_days(), to: Animina.Accounts.Statistics
  defdelegate confirmed_users_today_by_hour_berlin(), to: Animina.Accounts.Statistics
  defdelegate count_confirmed_users_yesterday_berlin(), to: Animina.Accounts.Statistics
  defdelegate count_confirmed_users_last_24h(), to: Animina.Accounts.Statistics
  defdelegate count_confirmed_users_last_7_days(), to: Animina.Accounts.Statistics
  defdelegate count_confirmed_users_last_28_days(), to: Animina.Accounts.Statistics
  defdelegate count_active_users(), to: Animina.Accounts.Statistics
  defdelegate count_confirmed_users(), to: Animina.Accounts.Statistics
  defdelegate count_unconfirmed_users(), to: Animina.Accounts.Statistics
  defdelegate count_confirmed_users_by_state(), to: Animina.Accounts.Statistics
  defdelegate count_confirmed_users_by_gender(), to: Animina.Accounts.Statistics
  defdelegate record_online_user_count(count), to: Animina.Accounts.Statistics
  defdelegate online_user_counts_since(since, bucket_minutes), to: Animina.Accounts.Statistics
  defdelegate registration_counts_since(since, bucket_minutes), to: Animina.Accounts.Statistics
  defdelegate confirmation_counts_since(since, bucket_minutes), to: Animina.Accounts.Statistics
  defdelegate purge_old_online_user_counts(days \\ 30), to: Animina.Accounts.Statistics

  # --- Delegations to Roles ---

  defdelegate get_user_roles(user), to: Animina.Accounts.Roles
  defdelegate assign_role(user, role, opts \\ []), to: Animina.Accounts.Roles
  defdelegate remove_role(user, role, opts \\ []), to: Animina.Accounts.Roles
  defdelegate has_role?(user, role), to: Animina.Accounts.Roles
  defdelegate count_users_with_role(role), to: Animina.Accounts.Roles

  # --- Delegations to Locations ---

  defdelegate max_locations(), to: Animina.Accounts.Locations
  defdelegate list_user_locations(user), to: Animina.Accounts.Locations
  defdelegate add_user_location(user, attrs, opts \\ []), to: Animina.Accounts.Locations

  defdelegate update_user_location(user, location_id, attrs, opts \\ []),
    to: Animina.Accounts.Locations

  defdelegate remove_user_location(user, location_id, opts \\ []), to: Animina.Accounts.Locations

  # --- Delegations to SoftDelete ---

  defdelegate user_deleted?(user), to: Animina.Accounts.SoftDelete
  defdelegate soft_delete_user(user, opts \\ []), to: Animina.Accounts.SoftDelete

  defdelegate get_deleted_user_by_email_and_password(email, password),
    to: Animina.Accounts.SoftDelete

  defdelegate reactivate_user(user, opts \\ []), to: Animina.Accounts.SoftDelete
  defdelegate hard_delete_user(user, opts \\ []), to: Animina.Accounts.SoftDelete
  defdelegate within_grace_period?(user), to: Animina.Accounts.SoftDelete
  defdelegate purge_deleted_users(), to: Animina.Accounts.SoftDelete
end
