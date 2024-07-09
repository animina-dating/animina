defmodule Animina.Accounts.User do
  @moduledoc """
  This is the User module.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer,
    domain: Animina.Accounts,
    extensions: [AshAuthentication, AshStateMachine, Ash.Notifier.PubSub]

  alias Animina.Accounts
  alias Animina.Accounts.Role
  alias Animina.Accounts.UserRole
  alias Animina.Narratives
  alias Animina.Traits
  alias Animina.Validations
  alias Phoenix.PubSub

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

    attribute :birthday, :date, allow_nil?: false , public?: true

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

    attribute :search_range, :integer, allow_nil?: true,public?: true
    attribute :language, :string, allow_nil?: true, public?: true
    attribute :legal_terms_accepted, :boolean, default: false , public?: true
    attribute :preapproved_communication_only, :boolean, default: false , public?: true
    attribute :streak, :integer, default: 0  , public?: true

    attribute :last_registration_page_visited, :string,
      allow_nil?: true,
       public?: true,
      default: "/my/potential-partner"

    attribute :occupation, :string do



      constraints max_length: 40,
                  trim?: true,
                  allow_empty?: false



    end

    attribute :is_private, :boolean, default: false , public?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :credits, Accounts.Credit
    has_many :photos, Accounts.Photo

    many_to_many :roles, Accounts.Role do
      through Accounts.UserRole
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :role_id
    end

    many_to_many :flags, Traits.Flag do
      through Traits.UserFlags
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :flag_id
    end

    has_many :traits, Traits.UserFlags do
      destination_attribute :user_id
    end

    has_many :stories, Narratives.Story do
      domain  Narratives
    end

    has_many :sent_messages, Accounts.Message do
      destination_attribute :sender_id
    end

    has_many :received_messages, Accounts.Message do
      destination_attribute :receiver_id
    end

    has_many :received_reactions, Animina.Accounts.Reaction do
      destination_attribute :receiver_id
    end

    has_many :send_reactions, Animina.Accounts.Reaction do
      destination_attribute :sender_id
    end

    has_many :bookmarks, Accounts.Bookmark do
      destination_attribute :owner_id
    end

    has_many :visit_log_entries, Accounts.VisitLogEntry do
      destination_attribute :user_id
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

    validate {Validations.BadUsername, attribute: :username}
  end

  state_machine do
    initial_states([:normal])
    default_initial_state(:normal)

    transitions do
      transition(:validate, from: [:normal, :under_investigation], to: :validated)
      transition(:investigate, from: [:normal, :validated], to: :under_investigation)
      transition(:ban, from: [:normal, :validated, :under_investigation], to: :banned)
      transition(:incognito, from: [:normal, :validated, :under_investigation], to: :incognito)

      transition(:hibernate,
        from: [:normal, :validated, :under_investigation, :archived],
        to: :hibernate
      )

      transition(:archive,
        from: [:normal, :validated, :under_investigation, :hibernate],
        to: :archived
      )

      transition(:reactivate, from: [:incognito, :hibernate], to: :normal)
      transition(:unban, from: [:banned], to: :normal)
      transition(:recover, from: [:archived], to: :normal)

      transition(:normalize,
        from: [:banned, :incognito, :hibernate, :archived, :under_investigation],
        to: :normal
      )
    end
  end

  pub_sub do
    module Animina
    prefix "user"
    broadcast_type :phoenix_broadcast

    publish :update, ["updated", :id]
  end

  identities do
    identity :unique_email, [:email], eager_check_with: Accounts
    identity :unique_username, [:username], eager_check_with: Accounts
    identity :unique_mobile_phone, [:mobile_phone], eager_check_with: Accounts
  end

  aggregates do
    sum :credit_points, :credits, :points, default: 0
  end

  actions do

    defaults [:read]


    create :create do
      accept [
        :email,
        :username,
        :name,
        :zip_code,
        :birthday,
        :height,
        :hashed_password,
        :language,
        :gender,
        :mobile_phone,
        :legal_terms_accepted,
        :occupation,
       :preapproved_communication_only,
       :state,
        :minimum_partner_height,
        :maximum_partner_height,
        :minimum_partner_age,
        :maximum_partner_age,
        :partner_gender,
        :search_range,
        :is_private

      ]
      primary? true
    end


    update :update do
      accept [:is_private, :streak, :last_registration_page_visited]

      primary? true
      require_atomic? false
    end

    update :update_last_registration_page_visited do
      accept [:last_registration_page_visited]
      require_atomic? false
    end

    read :custom_sign_in do
      argument :username_or_email, :string, allow_nil?: false
      argument :password, :string, allow_nil?: false, sensitive?: true
      prepare Animina.MyCustomSignInPreparation
    end

    read :by_username_as_an_actor do
      argument :username, :ci_string do
        allow_nil? false
      end

      get? true

      filter expr(username == ^arg(:username))
    end

    read :female_public_users_who_created_an_account_in_the_last_60_days do
      filter expr(
               is_private == ^false and gender == ^"female" and
                 created_at >= ^DateTime.add(DateTime.utc_now(), -60, :day)
             )
    end

    read :male_public_users_who_created_an_account_in_the_last_60_days do
      filter expr(
               is_private == ^false and gender == ^"male" and
                 created_at >= ^DateTime.add(DateTime.utc_now(), -60, :day)
             )
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

    action :make_admin, :string do
      argument :user_id, :uuid do
        allow_nil? false

      end


      run fn input, _ ->
        admin_role =
          case Role.by_name!(:admin) do
            nil ->
              Role.create!(%{name: :admin})

            _ ->
              Role.by_name!(:admin)
          end

        {:ok, user_role} =
          UserRole.create(%{
            user_id: input.arguments.user_id,
            role_id: admin_role.id
          })

        {:ok, user_role}
      end
    end

    action :remove_admin, :string do
      argument :user_id, :uuid do
        allow_nil? false
      end

      run fn input, _ ->
        {:ok, admin_roles_for_user} =
          UserRole.admin_roles_by_user_id(%{user_id: input.arguments.user_id})

        Enum.each(admin_roles_for_user, fn admin_role ->
          UserRole.destroy(admin_role)
        end)

        {:ok, :admin_roles_removed}
      end
    end
  end

  code_interface do
    domain Accounts
    define :read
    define :create
    define :update
    define :update_last_registration_page_visited, action: :update
    define :by_username, get_by: [:username], action: :read
    define :by_id, get_by: [:id], action: :read
    define :by_email, get_by: [:email], action: :read
    define :by_username_as_an_actor, args: [:username]
    define :custom_sign_in, get?: true
    define :female_public_users_who_created_an_account_in_the_last_60_days
    define :male_public_users_who_created_an_account_in_the_last_60_days
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
    define :make_admin
    define :remove_admin
  end

  calculations do
    calculate :age, :integer, {Animina.Calculations.UserAge, field: :birthday}
    calculate :profile_photo, :map, {Animina.Calculations.UserProfilePhoto, field: :id}
    calculate :city, :map, {Animina.Calculations.UserCity, field: :zip_code}
  end

  changes do
    change after_action(fn changeset, record, _ ->
           add_role(changeset, :user)

             # First user in dev becomes admin by default.
             if Mix.env() == :dev && Enum.count(Accounts.BasicUser.read!()) == 1 do
             add_role(changeset, :admin)
             end

             {:ok, record}
           end),
           on: [:create]

    change after_action(fn changeset, record , _context->
             PubSub.broadcast(Animina.PubSub, record.id, {:user, record})

             {:ok, record}
           end),
           on: [:update]
  end

  preparations do
    prepare build(
              load: [
                :age,
                :credit_points,
                :profile_photo,
                :city,
                :roles
              ]
            )
  end

  policies do
    policy action_type(:read) do
      authorize_if Animina.Checks.ReadProfileCheck
    end
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

  postgres do
    table "users"
    repo Animina.Repo
  end

  defp add_role(changeset, name) do
    role = Accounts.Role.by_name!(name)

    Accounts.UserRole.create(%{
      user_id: changeset.attributes.id,
      role_id: role.id
    })
  end
end
