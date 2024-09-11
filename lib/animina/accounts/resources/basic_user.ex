defmodule Animina.Accounts.BasicUser do
  @moduledoc """
  This is the Basic User module. It is a stripped down version of the
  User module. It is used for the registration form.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Accounts,
    extensions: [AshAuthentication, AshStateMachine]

  alias Animina.Accounts
  alias Animina.Validations

  postgres do
    table "users"
    repo Animina.Repo
  end

  authentication do
    domain Accounts

    strategies do
      password :password do
        identity_field :email
        sign_in_tokens_enabled? true
        confirmation_required?(false)

        register_action_accept([
          :email,
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

  state_machine do
    initial_states([:normal])
    default_initial_state(:normal)

    transitions do
      transition(:validate, from: [:normal, :under_investigation], to: :validated)
      transition(:investigate, from: [:normal, :validated], to: :under_investigation)
      transition(:ban, from: [:normal, :validated, :under_investigation], to: :banned)
      transition(:incognito, from: [:normal, :validated, :under_investigation], to: :incognito)
      transition(:hibernate, from: [:normal, :validated, :under_investigation], to: :hibernate)
      transition(:archive, from: [:normal, :validated, :under_investigation], to: :archived)
      transition(:reactivate, from: [:incognito, :hibernate], to: :normal)
      transition(:unban, from: [:banned], to: :normal)
      transition(:recover, from: [:archived], to: :normal)

      transition(:normalize,
        from: [:banned, :incognito, :hibernate, :archived, :under_investigation],
        to: :normal
      )
    end
  end

  code_interface do
    domain Accounts
    define :read
    define :create
    define :by_id, get_by: [:id], action: :read
    define :custom_sign_in, get?: true
    define :investigate
    define :ban
    define :archive
    define :hibernate
    define :reactivate
    define :unban
    define :recover
    define :validate
    define :normalize
    define :incognito
  end

  actions do
    defaults [:create, :read]

    read :custom_sign_in do
      argument :username_or_email, :string, allow_nil?: false
      argument :password, :string, allow_nil?: false, sensitive?: true
      prepare Animina.MyCustomSignInPreparation
    end

    update :validate do
      require_atomic? false
      change transition_state(:validated)
    end

    update :investigate do
      require_atomic? false
      change transition_state(:under_investigation)
    end

    update :ban do
      require_atomic? false
      change transition_state(:banned)
    end

    update :incognito do
      require_atomic? false
      change transition_state(:incognito)
    end

    update :hibernate do
      require_atomic? false
      change transition_state(:hibernate)
    end

    update :archive do
      require_atomic? false
      change transition_state(:archived)
    end

    update :reactivate do
      require_atomic? false
      change transition_state(:normal)
    end

    update :unban do
      require_atomic? false
      change transition_state(:normal)
    end

    update :recover do
      require_atomic? false
      change transition_state(:normal)
    end

    update :normalize do
      require_atomic? false
      change transition_state(:normal)
    end
  end

  preparations do
    prepare build(load: [:age, :credit_points])
  end

  validations do
    validate {Validations.Birthday, attribute: :birthday}
    validate {Validations.ZipCode, attribute: :zip_code}
    validate {Validations.Gender, attribute: :gender}
    validate {Validations.MobilePhoneNumber, attribute: :mobile_phone}
    validate {Validations.MustBeTrue, attribute: :legal_terms_accepted}
    validate {Validations.Country, attribute: :country}

    validate {Validations.BadPassword,
              where: [action_is([:register_with_password, :change_password])],
              attribute: :password}

    validate {Validations.BadUsername, attribute: :username}
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true

    attribute :username, :ci_string do
      allow_nil? false
      public? true

      constraints max_length: 15,
                  min_length: 2,
                  match: ~r/^[A-Za-z0-9._-]*$/,
                  trim?: true,
                  allow_empty?: false
    end

    attribute :name, :string do
      allow_nil? false
      public? true

      constraints max_length: 50,
                  min_length: 1,
                  trim?: true,
                  allow_empty?: false
    end

    attribute :birthday, :date, allow_nil?: false, public?: true

    attribute :zip_code, :string do
      constraints trim?: true,
                  allow_empty?: false
    end

    attribute :state, :atom do
      constraints one_of: [
                    :normal,
                    :validated,
                    :under_investigation,
                    :banned,
                    :incognito,
                    :hibernate,
                    :archived
                  ]

      default :normal
      allow_nil? false
    end

    attribute :country, :string do
      allow_nil? false
      public? true
    end

    attribute :gender, :string, allow_nil?: false, public?: true

    attribute :height, :integer do
      allow_nil? false
      public? true

      constraints max: 250,
                  min: 40
    end

    attribute :mobile_phone, :ash_phone_number, allow_nil?: false

    attribute :minimum_partner_height, :integer, allow_nil?: true
    attribute :maximum_partner_height, :integer, allow_nil?: true

    attribute :minimum_partner_age, :integer do
      allow_nil? true
      constraints min: 18
    end

    attribute :maximum_partner_age, :integer, allow_nil?: true, public?: true

    attribute :partner_gender, :string, allow_nil?: true, public?: true

    attribute :search_range, :integer, allow_nil?: true, public?: true
    attribute :language, :string, allow_nil?: true, public?: true
    attribute :legal_terms_accepted, :boolean, default: false, public?: true
    attribute :preapproved_communication_only, :boolean, default: false, public?: true
    attribute :streak, :integer, default: 0, public?: true

    attribute :last_registration_page_visited, :string,
      allow_nil?: true,
      public?: true,
      default: "/my/potential-partner"

    attribute :occupation, :string do
      constraints max_length: 40,
                  trim?: true,
                  allow_empty?: false
    end

    attribute :is_private, :boolean, default: false, public?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :credits, Accounts.Credit do
      destination_attribute :user_id
    end

    has_many :photos, Accounts.Photo do
      destination_attribute :user_id
    end
  end

  calculations do
    calculate :age, :integer, {Animina.Calculations.UserAge, field: :birthday}
  end

  aggregates do
    sum :credit_points, :credits, :points
  end

  identities do
    identity :unique_email, [:email], eager_check_with: Accounts
    identity :unique_username, [:username], eager_check_with: Accounts
    identity :unique_mobile_phone, [:mobile_phone], eager_check_with: Accounts
  end
end
