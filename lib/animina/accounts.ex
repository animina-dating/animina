defmodule Animina.Accounts do
  @moduledoc """
  The Accounts context.

  This module acts as a facade, delegating to specialized sub-modules:
  - `Animina.Accounts.Locations` - User location management
  - `Animina.Accounts.Roles` - Role assignment and checking
  - `Animina.Accounts.SoftDelete` - Soft delete and reactivation
  - `Animina.Accounts.Statistics` - User counts and analytics
  """

  import Ecto.Query
  use Gettext, backend: AniminaWeb.Gettext

  alias Animina.ActivityLog

  alias Animina.Accounts.{
    AccountSecurityEvent,
    TosAcceptance,
    User,
    UserLocation,
    UserNotifier,
    UserPasskey,
    UserToken
  }

  alias Animina.Moodboard
  alias Animina.Repo
  alias Animina.Repo.Paginator
  alias Animina.TimeMachine
  alias Animina.Utils.PaperTrail, as: PT

  ## Database getters

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    from(u in User,
      where: u.email == ^email,
      where: is_nil(u.deleted_at),
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

    reduce_waitlist_time(user.id)
    reduce_waitlist_time(referrer_id)

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

  defp reduce_waitlist_time(user_id) do
    user = Repo.get(User, user_id)

    if user && user.state == "waitlisted" && user.end_waitlist_at do
      apply_waitlist_reduction(user)
    end
  end

  defp apply_waitlist_reduction(user) do
    threshold = Animina.FeatureFlags.referral_threshold()
    duration_days = Animina.FeatureFlags.waitlist_duration_days()
    reduction_seconds = div(duration_days * 86_400, threshold)
    now = TimeMachine.utc_now(:second)

    reduced = DateTime.add(user.end_waitlist_at, -reduction_seconds, :second)
    new_end_at = Enum.max([reduced, now], DateTime)

    from(u in User, where: u.id == ^user.id)
    |> Repo.update_all(set: [end_waitlist_at: new_end_at])

    ActivityLog.log(
      "profile",
      "referral_waitlist_reduced",
      "Waitlist time reduced by #{div(reduction_seconds, 86_400)} days for #{user.display_name}",
      actor_id: user.id,
      subject_id: user.id
    )
  end

  ## Terms of Service

  # The current ToS version, derived from the @tos_updated_at date in UserAuth.
  # Update this when the ToS changes.
  @tos_version "2026-02-13"

  @doc """
  Returns the current ToS version string.
  """
  def tos_version, do: @tos_version

  @doc """
  Accepts the Terms of Service for an existing user (re-consent flow).
  Sets `tos_accepted_at` to the current time, records a TosAcceptance row,
  and logs to ActivityLog.
  """
  def accept_terms_of_service(%User{} = user) do
    Repo.transact(fn ->
      with {:ok, updated_user} <-
             user
             |> User.tos_acceptance_changeset()
             |> Repo.update(),
           {:ok, _acceptance} <- record_tos_acceptance(updated_user, @tos_version) do
        ActivityLog.log(
          "profile",
          "tos_accepted",
          "#{updated_user.display_name} accepted ToS version #{@tos_version}",
          actor_id: updated_user.id,
          subject_id: updated_user.id,
          metadata: %{"version" => @tos_version}
        )

        {:ok, updated_user}
      end
    end)
  end

  @doc """
  Records a ToS acceptance for a user with the given version.
  """
  def record_tos_acceptance(%User{} = user, version) do
    %TosAcceptance{}
    |> TosAcceptance.changeset(%{
      user_id: user.id,
      version: version,
      accepted_at: DateTime.utc_now(:second)
    })
    |> Repo.insert()
  end

  @doc """
  Lists ToS acceptances with filtering and pagination.

  ## Options

    * `:page` - page number (default: 1)
    * `:per_page` - results per page (default: 50)
    * `:filter_user_id` - filter by user_id
    * `:filter_version` - filter by version
  """
  def list_tos_acceptances(opts \\ []) do
    from(a in TosAcceptance,
      join: u in assoc(a, :user),
      preload: [user: u],
      order_by: [desc: a.accepted_at]
    )
    |> maybe_filter_tos_user(Keyword.get(opts, :filter_user_id))
    |> maybe_filter_tos_version(Keyword.get(opts, :filter_version))
    |> Paginator.paginate(opts)
  end

  @doc """
  Returns the total count of ToS acceptance records.
  """
  def count_tos_acceptances do
    Repo.aggregate(TosAcceptance, :count)
  end

  @doc """
  Returns a list of distinct ToS versions that have been accepted.
  """
  def list_tos_versions do
    from(a in TosAcceptance, distinct: true, select: a.version, order_by: [desc: a.version])
    |> Repo.all()
  end

  defp maybe_filter_tos_user(query, nil), do: query
  defp maybe_filter_tos_user(query, ""), do: query
  defp maybe_filter_tos_user(query, user_id), do: where(query, [a], a.user_id == ^user_id)

  defp maybe_filter_tos_version(query, nil), do: query
  defp maybe_filter_tos_version(query, ""), do: query
  defp maybe_filter_tos_version(query, version), do: where(query, [a], a.version == ^version)

  ## User registration

  @doc """
  Registers a user.
  """
  def register_user(attrs, opts \\ []) do
    # Check registration bans before proceeding
    phone = Map.get(attrs, :mobile_phone) || Map.get(attrs, "mobile_phone")
    email = Map.get(attrs, :email) || Map.get(attrs, "email")

    if phone && email && Animina.Reports.registration_banned?(phone, email) do
      {:error, :registration_banned}
    else
      do_register_user(attrs, opts)
    end
  end

  defp do_register_user(attrs, opts) do
    locations_attrs = extract_locations(attrs)
    referral_code_input = extract_referral_code_input(attrs)
    pt_opts = PT.opts(opts)

    Repo.transact(fn ->
      changeset =
        User.registration_changeset(%User{}, attrs)
        |> set_end_waitlist_at()

      changeset = resolve_referral_code(changeset, referral_code_input)

      with {:ok, user} <- insert_with_referral_code_retry(changeset, 3, pt_opts),
           :ok <- insert_locations(user, locations_attrs),
           {:ok, _pinned_item} <- create_pinned_intro_item(user) do
        # Restore any existing report invisibilities for re-registering users
        Animina.Reports.restore_invisibilities_for_new_user(user)

        ActivityLog.log("profile", "account_registered", "#{user.display_name} registered",
          actor_id: user.id,
          subject_id: user.id
        )

        {:ok, user}
      end
    end)
  end

  defp create_pinned_intro_item(user) do
    Moodboard.create_pinned_intro_item(user, "")
  end

  defp set_end_waitlist_at(changeset) do
    duration_days = Animina.FeatureFlags.waitlist_duration_days()

    end_at =
      TimeMachine.utc_now()
      |> DateTime.add(duration_days, :day)
      |> DateTime.truncate(:second)

    Ecto.Changeset.put_change(changeset, :end_waitlist_at, end_at)
  end

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

  Returns `{:ok, {user, security_info}}` where security_info contains
  `old_email`, `undo_token`, and `confirm_token` for the notification email.
  Returns `{:error, :cooldown_active}` if a security cooldown is in effect.
  """
  def update_user_email(user, token, opts \\ []) do
    context = "change:#{user.email}"
    pt_opts = PT.opts(opts)

    Repo.transact(fn ->
      with :ok <- check_no_active_cooldown(user.id),
           {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           old_email <- user.email,
           {:ok, user} <-
             User.email_changeset(user, %{email: email})
             |> PaperTrail.update(pt_opts)
             |> PT.unwrap(),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])),
           {:ok, security_info} <-
             create_security_event_for_email_change(user, old_email, email) do
        ActivityLog.log("profile", "email_changed", "#{user.display_name} changed email",
          actor_id: user.id,
          subject_id: user.id,
          metadata: %{"old_email" => old_email, "new_email" => email}
        )

        {:ok, {user, security_info}}
      else
        {:error, :cooldown_active} -> {:error, :cooldown_active}
        {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
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

  Returns `{:ok, {user, expired_tokens, security_info}}` on success,
  where security_info contains `undo_token` and `confirm_token`.
  Returns `{:error, :cooldown_active}` if a security cooldown is in effect.
  """
  def update_user_password(user, attrs) do
    case check_no_active_cooldown(user.id) do
      :ok ->
        old_hashed_password = user.hashed_password

        case user |> User.password_changeset(attrs) |> update_user_and_delete_all_tokens() do
          {:ok, {user, expired_tokens}} ->
            {:ok, security_info} =
              create_security_event_for_password_change(user, old_hashed_password)

            ActivityLog.log(
              "profile",
              "password_changed",
              "#{user.display_name} changed password",
              actor_id: user.id,
              subject_id: user.id
            )

            {:ok, {user, expired_tokens, security_info}}

          error ->
            error
        end

      {:error, :cooldown_active} ->
        {:error, :cooldown_active}
    end
  end

  ## Session

  @doc """
  Generates a session token, optionally with connection metadata.
  """
  def generate_user_session_token(user, conn_info \\ %{}) do
    {token, user_token} = UserToken.build_session_token(user, conn_info)
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

  @doc """
  Deletes all session tokens for a user. Used for forced logout (e.g., ban).
  """
  def delete_all_user_sessions(%User{id: user_id}) do
    from(t in UserToken, where: t.user_id == ^user_id and t.context == "session")
    |> Repo.delete_all()

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
        ActivityLog.log(
          "system",
          "account_expired",
          "Unconfirmed account #{user.display_name} (#{user.email}) auto-deleted: PIN expired",
          subject_id: user.id,
          metadata: %{"reason" => "pin_expired"}
        )

        Repo.delete(user)
        {:error, :expired}

      user.confirmation_pin_attempts >= @pin_max_attempts ->
        ActivityLog.log(
          "system",
          "account_expired",
          "Unconfirmed account #{user.display_name} (#{user.email}) auto-deleted: too many attempts",
          subject_id: user.id,
          metadata: %{"reason" => "too_many_attempts"}
        )

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
          ActivityLog.log(
            "system",
            "account_expired",
            "Unconfirmed account #{updated_user.display_name} (#{updated_user.email}) auto-deleted: too many attempts",
            subject_id: updated_user.id,
            metadata: %{"reason" => "too_many_attempts"}
          )

          Repo.delete(updated_user)
          {:error, :too_many_attempts}
        else
          {:error, :wrong_pin}
        end
    end
  end

  defp pin_expired?(%User{confirmation_pin_sent_at: nil}), do: true

  defp pin_expired?(%User{confirmation_pin_sent_at: sent_at}) do
    DateTime.diff(DateTime.utc_now(), sent_at, :minute) >=
      Animina.FeatureFlags.pin_validity_minutes()
  end

  @doc """
  Deletes all unconfirmed users whose confirmation PIN has expired.
  """
  def delete_expired_unconfirmed_users do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-Animina.FeatureFlags.pin_validity_minutes(), :minute)

    query =
      from(u in User,
        where: is_nil(u.confirmed_at),
        where: not is_nil(u.confirmation_pin_sent_at),
        where: u.confirmation_pin_sent_at < ^cutoff
      )

    users =
      from(u in query, select: %{id: u.id, display_name: u.display_name, email: u.email})
      |> Repo.all()

    for user <- users do
      ActivityLog.log(
        "system",
        "account_expired",
        "Unconfirmed account #{user.display_name} (#{user.email}) auto-deleted after PIN expiry",
        subject_id: user.id,
        metadata: %{"reason" => "pin_expired"}
      )
    end

    Repo.delete_all(query)
  end

  ## User profile & preferences

  @doc """
  Computes the age from a birthday.
  """
  def compute_age(nil), do: nil

  def compute_age(birthday) do
    today = TimeMachine.utc_today()
    age = today.year - birthday.year
    if {today.month, today.day} < {birthday.month, birthday.day}, do: age - 1, else: age
  end

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
    result =
      user
      |> User.profile_changeset(attrs)
      |> PaperTrail.update(PT.opts(opts))
      |> PT.unwrap()

    case result do
      {:ok, updated_user} ->
        ActivityLog.log(
          "profile",
          "profile_updated",
          "#{updated_user.display_name} updated profile",
          actor_id: updated_user.id,
          subject_id: updated_user.id
        )

        {:ok, updated_user}

      error ->
        error
    end
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
  Updates the grid column preference.
  """
  def update_grid_columns(%User{} = user, columns) when columns in [1, 2, 3] do
    user
    |> User.grid_columns_changeset(%{grid_columns: columns})
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

  ## Session management

  @doc """
  Lists all active session tokens for a user.
  """
  def list_user_sessions(user_id) do
    UserToken.user_sessions_query(user_id)
    |> Repo.all()
  end

  @doc """
  Deletes a specific session token by its ID, scoped to a user.
  Returns the deleted token (for broadcasting disconnect) or nil.
  """
  def delete_user_session_by_id(token_id, user_id) do
    query =
      from(t in UserToken,
        where: t.id == ^token_id,
        where: t.user_id == ^user_id,
        where: t.context == "session"
      )

    case Repo.one(query) do
      nil -> nil
      token -> Repo.delete!(token)
    end
  end

  @doc """
  Deletes all session tokens for a user except the current one.
  Returns the list of deleted tokens (for broadcasting disconnects).
  """
  def delete_other_user_sessions(user_id, current_token) do
    query =
      from(t in UserToken,
        where: t.user_id == ^user_id,
        where: t.context == "session",
        where: t.token != ^current_token
      )

    tokens = Repo.all(query)
    Repo.delete_all(query)
    tokens
  end

  @last_seen_throttle_minutes 5

  @doc """
  Updates `last_seen_at` on a session token, throttled to every 5 minutes.
  """
  def maybe_update_last_seen(token) when is_binary(token) do
    now = DateTime.utc_now(:second)
    throttle_cutoff = DateTime.add(now, -@last_seen_throttle_minutes, :minute)

    from(t in UserToken,
      where: t.token == ^token,
      where: t.context == "session",
      where: is_nil(t.last_seen_at) or t.last_seen_at < ^throttle_cutoff
    )
    |> Repo.update_all(set: [last_seen_at: now])
  end

  ## Security events (email/password change protection)

  @doc """
  Checks whether a user has an active (unresolved, unexpired) security cooldown.
  """
  def has_active_security_cooldown?(user_id) do
    AccountSecurityEvent.active_events_query(user_id)
    |> Repo.exists?()
  end

  @doc """
  Returns the active security event for a user, or nil.
  """
  def get_active_security_event(user_id) do
    AccountSecurityEvent.active_events_query(user_id)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Creates a security event for an email change.
  Returns `{:ok, %{old_email: ..., undo_token: ..., confirm_token: ...}}`.
  """
  def create_security_event_for_email_change(user, old_email, new_email) do
    {undo_token, confirm_token, event} =
      AccountSecurityEvent.build(user.id, "email_change", %{
        old_email: old_email,
        old_value: old_email,
        new_value: new_email
      })

    Repo.insert!(event)
    {:ok, %{old_email: old_email, undo_token: undo_token, confirm_token: confirm_token}}
  end

  @doc """
  Creates a security event for a password change.
  Returns `{:ok, %{undo_token: ..., confirm_token: ...}}`.
  """
  def create_security_event_for_password_change(user, old_hashed_password) do
    {undo_token, confirm_token, event} =
      AccountSecurityEvent.build(user.id, "password_change", %{
        old_value: old_hashed_password
      })

    Repo.insert!(event)
    {:ok, %{undo_token: undo_token, confirm_token: confirm_token}}
  end

  @doc """
  Verifies an undo token and reverts the associated change.

  For email changes: reverts the email to the old value, kills all sessions.
  For password changes: restores the old password hash, kills all sessions.

  Returns `{:ok, event}` or `{:error, reason}`.
  """
  def undo_security_event(token) do
    with {:ok, query} <- AccountSecurityEvent.verify_undo_token_query(token),
         %AccountSecurityEvent{} = event <- Repo.one(query) do
      case event.event_type do
        "email_change" -> undo_email_change(event)
        "password_change" -> undo_password_change(event)
        _ -> {:error, :unknown_event_type}
      end
    else
      nil -> {:error, :invalid_token}
      :error -> {:error, :invalid_token}
    end
  end

  defp undo_email_change(event),
    do: undo_security_change(event, email: event.old_value)

  defp undo_password_change(event),
    do: undo_security_change(event, hashed_password: event.old_value)

  defp undo_security_change(event, user_changes) do
    user = get_user!(event.user_id)

    Repo.transact(fn ->
      user
      |> Ecto.Changeset.change(user_changes)
      |> Repo.update!()

      updated_event =
        event
        |> Ecto.Changeset.change(resolved_at: DateTime.utc_now(:second), resolution: "undone")
        |> Repo.update!()

      Repo.delete_all(from(t in UserToken, where: t.user_id == ^event.user_id))

      {:ok, updated_event}
    end)
  end

  @doc """
  Verifies a confirm token and resolves the security event (user approves the change).
  Returns `{:ok, event}` or `{:error, reason}`.
  """
  def confirm_security_event(token) do
    with {:ok, query} <- AccountSecurityEvent.verify_confirm_token_query(token),
         %AccountSecurityEvent{} = event <- Repo.one(query) do
      event
      |> Ecto.Changeset.change(resolved_at: DateTime.utc_now(:second), resolution: "confirmed")
      |> Repo.update()
    else
      nil -> {:error, :invalid_token}
      :error -> {:error, :invalid_token}
    end
  end

  @doc """
  Returns `:ok` if no active cooldown exists, or `{:error, :cooldown_active}`.
  """
  def check_no_active_cooldown(user_id) do
    if has_active_security_cooldown?(user_id) do
      {:error, :cooldown_active}
    else
      :ok
    end
  end

  @doc """
  Deletes expired (resolved or past expiry) security events for cleanup.
  """
  def cleanup_expired_security_events do
    now = DateTime.utc_now(:second)

    from(e in AccountSecurityEvent,
      where: not is_nil(e.resolved_at) or e.expires_at < ^now
    )
    |> Repo.delete_all()
  end

  ## Passkeys (WebAuthn)

  @doc """
  Lists all passkeys for a user.
  """
  def list_user_passkeys(%User{id: user_id}) do
    from(p in UserPasskey, where: p.user_id == ^user_id, order_by: [asc: p.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets a single passkey. Returns nil if not found.
  """
  def get_user_passkey(%User{id: user_id}, passkey_id) do
    Repo.get_by(UserPasskey, id: passkey_id, user_id: user_id)
  end

  @doc """
  Creates a passkey for a user from a verified WebAuthn registration.
  """
  def create_user_passkey(%User{} = user, attrs) do
    result =
      %UserPasskey{user_id: user.id}
      |> UserPasskey.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, passkey} ->
        ActivityLog.log(
          "profile",
          "passkey_registered",
          "#{user.display_name} registered a passkey",
          actor_id: user.id,
          subject_id: user.id,
          metadata: %{"passkey_id" => passkey.id, "label" => passkey.label}
        )

        {:ok, passkey}

      error ->
        error
    end
  end

  @doc """
  Deletes a passkey belonging to a user.
  """
  def delete_user_passkey(%User{id: user_id} = user, passkey_id) do
    case Repo.get_by(UserPasskey, id: passkey_id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      passkey ->
        result = Repo.delete(passkey)

        case result do
          {:ok, _} ->
            ActivityLog.log(
              "profile",
              "passkey_deleted",
              "#{user.display_name} deleted a passkey",
              actor_id: user_id,
              subject_id: user_id,
              metadata: %{"passkey_id" => passkey_id, "label" => passkey.label}
            )

          _ ->
            :ok
        end

        result
    end
  end

  @doc """
  Finds a user by a credential_id (for discoverable credential login).
  Returns {user, passkey} or nil.
  """
  def get_user_by_passkey_credential_id(credential_id) when is_binary(credential_id) do
    query =
      from(p in UserPasskey,
        where: p.credential_id == ^credential_id,
        join: u in assoc(p, :user),
        where: is_nil(u.deleted_at),
        preload: [user: u]
      )

    case Repo.one(query) do
      %UserPasskey{user: user} = passkey -> {user, passkey}
      nil -> nil
    end
  end

  @doc """
  Updates the sign count and last_used_at for a passkey after successful authentication.
  """
  def update_passkey_after_auth(%UserPasskey{} = passkey, sign_count) do
    passkey
    |> Ecto.Changeset.change(%{
      sign_count: sign_count,
      last_used_at: DateTime.utc_now()
    })
    |> Repo.update()
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

  defdelegate list_admins(), to: Animina.Accounts.Roles
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

  # --- Delegations to ContactBlacklist ---

  defdelegate list_contact_blacklist_entries(user),
    to: Animina.Accounts.ContactBlacklist,
    as: :list_entries

  defdelegate count_contact_blacklist_entries(user),
    to: Animina.Accounts.ContactBlacklist,
    as: :count_entries

  defdelegate add_contact_blacklist_entry(user, attrs),
    to: Animina.Accounts.ContactBlacklist,
    as: :add_entry

  defdelegate remove_contact_blacklist_entry(user, entry_id),
    to: Animina.Accounts.ContactBlacklist,
    as: :remove_entry

  # --- Delegations to OnlineActivity ---

  defdelegate last_seen(user_id), to: Animina.Accounts.OnlineActivity
  defdelegate activity_level(user_id), to: Animina.Accounts.OnlineActivity
  defdelegate typical_online_times(user_id), to: Animina.Accounts.OnlineActivity
  defdelegate purge_old_sessions(), to: Animina.Accounts.OnlineActivity

  # --- Online status privacy ---

  @doc """
  Updates the hide_online_status preference for a user.
  """
  def update_online_status_visibility(%User{} = user, attrs) do
    user
    |> User.online_status_changeset(attrs)
    |> Repo.update()
  end

  # --- Wingman preference ---

  @doc """
  Updates the wingman_enabled preference for a user.
  """
  def update_wingman_enabled(%User{} = user, attrs) do
    user
    |> User.wingman_changeset(attrs)
    |> Repo.update()
  end
end
