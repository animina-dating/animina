defmodule Animina.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_genders ~w(male female diverse)

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
    field :zip_code, :string
    field :mobile_phone, :string

    belongs_to :country, Animina.GeoData.Country

    # Partner preferences
    field :preferred_partner_gender, {:array, :string}, default: []
    field :partner_minimum_age_offset, :integer, default: 6
    field :partner_maximum_age_offset, :integer, default: 2
    field :partner_height_min, :integer, default: 80
    field :partner_height_max, :integer, default: 225
    field :search_radius, :integer, default: 60

    # Additional fields
    field :terms_accepted_at, :utc_datetime
    field :occupation, :string
    field :language, :string, default: "de"
    field :state, :string, default: "waitlisted"

    # Virtual field for form checkbox
    field :terms_accepted, :boolean, virtual: true

    timestamps(type: :utc_datetime)
  end

  @registration_fields [
    :display_name,
    :birthday,
    :gender,
    :height,
    :zip_code,
    :mobile_phone,
    :country_id,
    :preferred_partner_gender,
    :partner_minimum_age_offset,
    :partner_maximum_age_offset,
    :partner_height_min,
    :partner_height_max,
    :search_radius,
    :occupation,
    :language,
    :terms_accepted
  ]

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
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_profile_fields()
    |> validate_terms_accepted()
  end

  defp validate_profile_fields(changeset) do
    changeset
    |> validate_required([
      :display_name,
      :birthday,
      :gender,
      :height,
      :zip_code,
      :mobile_phone,
      :country_id
    ])
    |> validate_length(:display_name, min: 2, max: 50)
    |> validate_inclusion(:gender, @valid_genders)
    |> validate_number(:height, greater_than_or_equal_to: 80, less_than_or_equal_to: 225)
    |> validate_format(:zip_code, ~r/^\d{5}$/, message: "must be 5 digits")
    |> validate_format(:mobile_phone, ~r/^\+[1-9]\d{6,14}$/, message: "must be in E.164 format (e.g. +491234567890)")
    |> validate_birthday()
    |> validate_preferred_partner_genders()
    |> validate_number(:partner_height_min, greater_than_or_equal_to: 80, less_than_or_equal_to: 225)
    |> validate_number(:partner_height_max, greater_than_or_equal_to: 80, less_than_or_equal_to: 225)
    |> validate_number(:search_radius, greater_than_or_equal_to: 1)
    |> unique_constraint(:mobile_phone)
  end

  defp validate_birthday(changeset) do
    case get_field(changeset, :birthday) do
      nil ->
        changeset

      birthday ->
        today = Date.utc_today()
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
      |> unsafe_validate_unique(:email, Animina.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
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
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
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
end
