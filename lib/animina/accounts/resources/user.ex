defmodule Animina.Accounts.User do
  @moduledoc """
  This is the User module.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  alias Animina.Accounts
  alias Animina.Traits
  alias Animina.Validations

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true

    attribute :username, :ci_string do
      allow_nil? false

      constraints max_length: 15,
                  min_length: 2,
                  match: ~r/^[A-Za-z0-9._-]*$/,
                  trim?: true,
                  allow_empty?: false
    end

    attribute :name, :string do
      allow_nil? false

      constraints max_length: 50,
                  min_length: 1,
                  trim?: true,
                  allow_empty?: false
    end

    attribute :birthday, :date, allow_nil?: false

    attribute :zip_code, :string do
      constraints trim?: true,
                  allow_empty?: false
    end

    attribute :gender, :string, allow_nil?: false

    attribute :height, :integer do
      allow_nil? false

      constraints max: 250,
                  min: 50
    end

    attribute :mobile_phone, :ash_phone_number, allow_nil?: false

    attribute :minimum_partner_height, :integer, allow_nil?: true
    attribute :maximum_partner_height, :integer, allow_nil?: true

    attribute :minimum_partner_age, :integer do
      allow_nil? true
      constraints min: 18
    end

    attribute :maximum_partner_age, :integer, allow_nil?: true

    attribute :partner_gender, :string, allow_nil?: true

    attribute :search_range, :integer, allow_nil?: true
    attribute :language, :string, allow_nil?: true
    attribute :legal_terms_accepted, :boolean, default: false
    attribute :occupation, :string
  end

  relationships do
    has_many :credits, Accounts.Credit
    has_many :photos, Accounts.Photo

    has_many :flags, Traits.UserFlags do
      api Traits
    end
  end

  validations do
    validate {Validations.Birthday, attribute: :birthday}
    validate {Validations.ZipCode, attribute: :zip_code}
    validate {Validations.Gender, attribute: :gender}
    validate {Validations.Gender, attribute: :partner_gender}
    validate {Validations.MobilePhoneNumber, attribute: :mobile_phone}
    validate {Validations.MustBeTrue, attribute: :legal_terms_accepted}

    validate {Validations.BadPassword,
              where: [action_is([:register_with_password, :change_password])],
              attribute: :password}
  end

  identities do
    identity :unique_email, [:email], eager_check_with: Accounts
    identity :unique_username, [:username], eager_check_with: Accounts
    identity :unique_mobile_phone, [:mobile_phone], eager_check_with: Accounts
  end

  actions do
    defaults [:create, :read, :update]
  end

  code_interface do
    define_for Accounts
    define :read
    define :create
    define :update
    define :by_username, get_by: [:username], action: :read
    define :by_id, get_by: [:id], action: :read
    define :by_email, get_by: [:email], action: :read
  end

  aggregates do
    sum :credit_points, :credits, :points, default: 0
  end

  calculations do
    calculate :gravatar_hash, :string, {Animina.Calculations.Md5, field: :email}
    calculate :age, :integer, {Animina.Calculations.UserAge, field: :birthday}
    calculate :profile_photo, :map, {Animina.Calculations.UserProfilePhoto, field: :id}
    calculate :city, :map, {Animina.Calculations.UserCity, field: :zip_code}
  end

  preparations do
    prepare build(load: [:gravatar_hash, :age, :credit_points, :profile_photo, :city])
  end

  authentication do
    api Accounts

    strategies do
      password :password do
        identity_field :email
        sign_in_tokens_enabled? true
        confirmation_required?(false)

        register_action_accept([
          :username,
          :name,
          :zip_code,
          :birthday,
          :height,
          :gender,
          :mobile_phone,
          :language,
          :legal_terms_accepted,
          :occupation
        ])
      end
    end

    tokens do
      enabled? true
      token_resource Accounts.Token

      signing_secret Accounts.Secrets
    end
  end

  postgres do
    table "users"
    repo Animina.Repo
  end

  # TODO: Uncomment this if you want to use policies
  # If using policies, add the following bypass:
  # policies do
  #   bypass AshAuthentication.Checks.AshAuthenticationInteraction do
  #     authorize_if always()
  #   end
  # end
end
