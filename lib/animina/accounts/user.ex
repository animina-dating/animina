defmodule Animina.Accounts.User do
  @moduledoc """
  Schema and changesets for user accounts, profiles, and preferences.
  """

  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: AniminaWeb.Gettext

  alias Animina.TimeMachine

  @valid_genders ~w(male female diverse)
  @valid_languages ~w(de en tr ru ar pl fr es uk)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true

    # Profile fields
    field :display_name, :string
    field :birthday, :date
    field :gender, :string
    field :height, :integer
    field :mobile_phone, :string

    has_many :locations, Animina.Accounts.UserLocation, preload_order: [asc: :position]
    has_many :user_roles, Animina.Accounts.UserRole
    has_many :user_flags, Animina.Traits.UserFlag
    has_many :user_category_opt_ins, Animina.Traits.UserCategoryOptIn

    # Partner preferences
    field :preferred_partner_gender, {:array, :string}, default: []
    field :partner_minimum_age_offset, :integer, default: 6
    field :partner_maximum_age_offset, :integer, default: 2
    field :partner_height_min, :integer, default: 80
    field :partner_height_max, :integer, default: 225
    field :search_radius, :integer, default: 60

    # Confirmation PIN fields
    field :confirmation_pin_hash, :string
    field :confirmation_pin_attempts, :integer, default: 0
    field :confirmation_pin_sent_at, :utc_datetime

    # Additional fields
    field :terms_accepted_at, :utc_datetime
    field :occupation, :string
    field :language, :string, default: "de"
    field :state, :string, default: "waitlisted"
    field :deleted_at, :utc_datetime

    # Referral fields
    field :referral_code, :string
    field :waitlist_priority, :integer, default: 0
    belongs_to :referred_by, __MODULE__, foreign_key: :referred_by_id

    # Moodboard preferences
    field :moodboard_columns_mobile, :integer, default: 2
    field :moodboard_columns_tablet, :integer, default: 2
    field :moodboard_columns_desktop, :integer, default: 3

    # Messaging
    field :last_message_notified_at, :utc_datetime

    # Virtual fields
    field :terms_accepted, :boolean, virtual: true
    field :partner_minimum_age, :integer, virtual: true
    field :partner_maximum_age, :integer, virtual: true
    field :referral_code_input, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @registration_fields [
    :display_name,
    :birthday,
    :gender,
    :height,
    :mobile_phone,
    :preferred_partner_gender,
    :partner_minimum_age_offset,
    :partner_maximum_age_offset,
    :partner_minimum_age,
    :partner_maximum_age,
    :partner_height_min,
    :partner_height_max,
    :search_radius,
    :occupation,
    :language,
    :terms_accepted,
    :referral_code_input
  ]

  @referral_code_chars ~c"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  @referral_code_length 6

  @doc """
  A user changeset for registration.

  Validates all profile fields in addition to email and password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database. Defaults to `true`.
    * `:validate_unique` - Validates uniqueness of email. Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password | @registration_fields])
    |> compute_age_offsets()
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_profile_fields()
    |> validate_terms_accepted()
    |> maybe_generate_referral_code()
    |> validate_referral_code_input()
  end

  @doc """
  Generates a random 6-character alphanumeric referral code.
  """
  def generate_referral_code do
    for(_ <- 1..@referral_code_length, do: Enum.random(@referral_code_chars))
    |> List.to_string()
  end

  defp maybe_generate_referral_code(changeset) do
    if get_field(changeset, :referral_code) do
      changeset
    else
      put_change(changeset, :referral_code, generate_referral_code())
    end
  end

  defp validate_referral_code_input(changeset) do
    case get_change(changeset, :referral_code_input) do
      nil ->
        changeset

      "" ->
        changeset

      code when is_binary(code) ->
        trimmed = String.trim(code) |> String.upcase()

        if Regex.match?(~r/^[A-Z0-9]{6}$/, trimmed) do
          put_change(changeset, :referral_code_input, trimmed)
        else
          add_error(
            changeset,
            :referral_code_input,
            dgettext("errors", "must be 6 characters (letters and digits)")
          )
        end

      _ ->
        changeset
    end
  end

  defp compute_age_offsets(changeset) do
    birthday = get_field(changeset, :birthday)
    min_age = get_change(changeset, :partner_minimum_age)
    max_age = get_change(changeset, :partner_maximum_age)

    if birthday && (min_age || max_age) do
      user_age = compute_user_age(birthday)

      changeset
      |> maybe_put_min_offset(user_age, min_age)
      |> maybe_put_max_offset(user_age, max_age)
    else
      changeset
    end
  end

  defp maybe_put_min_offset(changeset, user_age, min_age) when is_integer(min_age) do
    put_change(changeset, :partner_minimum_age_offset, max(0, user_age - min_age))
  end

  defp maybe_put_min_offset(changeset, _user_age, _min_age), do: changeset

  defp maybe_put_max_offset(changeset, user_age, max_age) when is_integer(max_age) do
    put_change(changeset, :partner_maximum_age_offset, max(0, max_age - user_age))
  end

  defp maybe_put_max_offset(changeset, _user_age, _max_age), do: changeset

  defp compute_user_age(birthday) do
    today = TimeMachine.utc_today()
    age = today.year - birthday.year

    if {today.month, today.day} < {birthday.month, birthday.day},
      do: age - 1,
      else: age
  end

  defp validate_profile_fields(changeset) do
    changeset
    |> validate_required([
      :display_name,
      :birthday,
      :gender,
      :height,
      :mobile_phone
    ])
    |> validate_length(:display_name, min: 2, max: 50)
    |> validate_inclusion(:gender, @valid_genders)
    |> validate_inclusion(:language, @valid_languages)
    |> validate_number(:height, greater_than_or_equal_to: 80, less_than_or_equal_to: 225)
    |> validate_and_normalize_mobile_phone()
    |> validate_birthday()
    |> validate_preferred_partner_genders()
    |> validate_number(:partner_height_min,
      greater_than_or_equal_to: 80,
      less_than_or_equal_to: 225
    )
    |> validate_number(:partner_height_max,
      greater_than_or_equal_to: 80,
      less_than_or_equal_to: 225
    )
    |> validate_number(:search_radius, greater_than_or_equal_to: 1)
    |> unique_constraint(:mobile_phone, name: :users_mobile_phone_active_index)
    |> unique_constraint(:referral_code)
  end

  defp validate_and_normalize_mobile_phone(changeset) do
    case get_field(changeset, :mobile_phone) do
      nil -> changeset
      phone -> do_validate_mobile_phone(changeset, phone)
    end
  end

  defp do_validate_mobile_phone(changeset, phone) do
    case ExPhoneNumber.parse(phone, "DE") do
      {:ok, parsed} ->
        case ExPhoneNumber.get_number_type(parsed) do
          type when type in [:mobile, :fixed_line_or_mobile] ->
            put_change(changeset, :mobile_phone, ExPhoneNumber.format(parsed, :e164))

          _ ->
            add_error(
              changeset,
              :mobile_phone,
              dgettext("errors", "must be a mobile number (not a landline)")
            )
        end

      _ ->
        add_error(changeset, :mobile_phone, dgettext("errors", "is not a valid phone number"))
    end
  end

  defp validate_birthday(changeset) do
    case get_field(changeset, :birthday) do
      nil ->
        changeset

      birthday ->
        today = TimeMachine.utc_today()
        age = Date.diff(today, birthday) |> div(365)

        if age < 18 do
          add_error(changeset, :birthday, "you must be at least 18 years old")
        else
          changeset
        end
    end
  end

  defp validate_preferred_partner_genders(changeset) do
    case get_field(changeset, :preferred_partner_gender) do
      nil ->
        changeset

      genders ->
        filtered = Enum.filter(genders, &(&1 != ""))
        changeset = put_change(changeset, :preferred_partner_gender, filtered)

        if Enum.all?(filtered, &(&1 in @valid_genders)) do
          changeset
        else
          add_error(changeset, :preferred_partner_gender, "contains invalid gender")
        end
    end
  end

  defp validate_terms_accepted(changeset) do
    case get_change(changeset, :terms_accepted) do
      true ->
        put_change(changeset, :terms_accepted_at, DateTime.utc_now(:second))

      _ ->
        if get_field(changeset, :terms_accepted_at) do
          changeset
        else
          add_error(changeset, :terms_accepted, "must be accepted")
        end
    end
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique_active_email()
      |> unique_constraint(:email, name: :users_email_active_index)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp unsafe_validate_unique_active_email(changeset) do
    email = get_field(changeset, :email)

    if email do
      import Ecto.Query

      query =
        from(u in __MODULE__,
          where: u.email == ^email,
          where: is_nil(u.deleted_at),
          select: count()
        )

      # Exclude the current record if it's persisted (update case)
      query =
        case changeset.data.id do
          nil -> query
          id -> from(u in query, where: u.id != ^id)
        end

      if Animina.Repo.one(query) > 0 do
        add_error(changeset, :email, "has already been taken", validation: :unsafe_unique)
      else
        changeset
      end
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && is_nil(get_change(changeset, :email)) do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Animina.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  A changeset for storing a hashed confirmation PIN.
  """
  def confirmation_pin_changeset(user, pin) when is_binary(pin) do
    salt = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    hash = :crypto.hash(:sha256, salt <> pin) |> Base.encode16(case: :lower)

    user
    |> change(
      confirmation_pin_hash: salt <> ":" <> hash,
      confirmation_pin_attempts: 0,
      confirmation_pin_sent_at: DateTime.utc_now(:second)
    )
  end

  @doc """
  Increments the PIN attempt counter.
  """
  def increment_pin_attempts_changeset(user) do
    change(user, confirmation_pin_attempts: user.confirmation_pin_attempts + 1)
  end

  @doc """
  Verifies whether the given PIN matches the stored hash.
  Returns `true` if the PIN is correct, `false` otherwise.
  """
  def verify_confirmation_pin(%__MODULE__{confirmation_pin_hash: salted_hash}, pin)
      when is_binary(salted_hash) and is_binary(pin) do
    case String.split(salted_hash, ":", parts: 2) do
      [salt, hash] ->
        candidate = :crypto.hash(:sha256, salt <> pin) |> Base.encode16(case: :lower)
        Plug.Crypto.secure_compare(hash, candidate)

      _ ->
        false
    end
  end

  def verify_confirmation_pin(_, _), do: false

  @doc """
  A changeset for updating user profile fields.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:display_name, :height, :occupation, :language])
    |> validate_required([:display_name, :height])
    |> validate_length(:display_name, min: 2, max: 50)
    |> validate_inclusion(:language, @valid_languages)
    |> validate_number(:height, greater_than_or_equal_to: 80, less_than_or_equal_to: 225)
  end

  @doc """
  A changeset for updating partner preference fields.
  """
  def preferences_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :preferred_partner_gender,
      :partner_minimum_age_offset,
      :partner_maximum_age_offset,
      :partner_minimum_age,
      :partner_maximum_age,
      :partner_height_min,
      :partner_height_max,
      :search_radius
    ])
    |> compute_age_offsets()
    |> validate_preferred_partner_genders()
    |> validate_number(:partner_height_min,
      greater_than_or_equal_to: 80,
      less_than_or_equal_to: 225
    )
    |> validate_number(:partner_height_max,
      greater_than_or_equal_to: 80,
      less_than_or_equal_to: 225
    )
    |> validate_number(:search_radius, greater_than_or_equal_to: 1)
  end

  @doc """
  A changeset for soft-deleting a user.

  Sets `deleted_at` to a future date (current time + grace period days).
  The grace period is configured via the :soft_delete_grace_days system setting.
  """
  def soft_delete_changeset(user) do
    grace_days = Animina.FeatureFlags.soft_delete_grace_days()

    hard_delete_date =
      TimeMachine.utc_now()
      |> DateTime.add(grace_days, :day)
      |> DateTime.truncate(:second)

    change(user, deleted_at: hard_delete_date)
  end

  @doc """
  A changeset for updating moodboard column preferences.
  """
  def moodboard_columns_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :moodboard_columns_mobile,
      :moodboard_columns_tablet,
      :moodboard_columns_desktop
    ])
    |> validate_inclusion(:moodboard_columns_mobile, [1, 2, 3])
    |> validate_inclusion(:moodboard_columns_tablet, [1, 2, 3])
    |> validate_inclusion(:moodboard_columns_desktop, [1, 2, 3])
  end
end
