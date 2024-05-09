defmodule Animina.Accounts.User do
  @moduledoc """
  This is the User module.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  alias Animina.Accounts
  alias Animina.Narratives
  alias Animina.Traits
  alias Animina.Validations
  alias Phoenix.PubSub

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
                  min: 40
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
    attribute :preapproved_communication_only, :boolean, default: false
    attribute :streak, :integer, default: 0

    attribute :last_registration_page_visited, :string,
      allow_nil?: true,
      default: "/my/potential-partner"

    attribute :occupation, :string do
      constraints max_length: 40,
                  trim?: true,
                  allow_empty?: false
    end

    attribute :is_private, :boolean, default: false

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
      api Narratives
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

  identities do
    identity :unique_email, [:email], eager_check_with: Accounts
    identity :unique_username, [:username], eager_check_with: Accounts
    identity :unique_mobile_phone, [:mobile_phone], eager_check_with: Accounts
  end

  actions do
    defaults [:read, :update, :create]

    update :update_last_registration_page_visited do
      accept [:last_registration_page_visited]
    end
  end

  code_interface do
    define_for Accounts
    define :read
    define :create
    define :update
    define :update_last_registration_page_visited, action: :update
    define :by_username, get_by: [:username], action: :read
    define :by_id, get_by: [:id], action: :read
    define :by_email, get_by: [:email], action: :read
  end

  aggregates do
    sum :credit_points, :credits, :points, default: 0
  end

  changes do
    change after_action(fn changeset, record ->
             if Mix.env() == :dev && Enum.empty?(Accounts.User.read!()) do
               create_user_and_admin_user_roles_for_first_user_in_dev_env(changeset)
             else
               create_user_role_for_user(changeset)
             end

             {:ok, record}
           end),
           on: [:create]

    change after_action(fn changeset, record ->
             username = Ash.CiString.value(record.username)

             PubSub.broadcast(Animina.PubSub, username, {:user, record})

             {:ok, record}
           end),
           on: [:update]
  end

  calculations do
    calculate :age, :integer, {Animina.Calculations.UserAge, field: :birthday}
    calculate :profile_photo, :map, {Animina.Calculations.UserProfilePhoto, field: :id}
    calculate :city, :map, {Animina.Calculations.UserCity, field: :zip_code}
  end

  preparations do
    prepare build(
              load: [
                :age,
                :credit_points,
                :profile_photo,
                :city,
                :flags,
                :stories,
                :traits
              ]
            )
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

  defp create_user_and_admin_user_roles_for_first_user_in_dev_env(changeset) do
    user_role = Animina.Accounts.Role.by_name!(:user)
    admin_role = Animina.Accounts.Role.by_name!(:admin)

    [
      %{user_id: changeset.attributes.id, role_id: user_role.id},
      %{user_id: changeset.attributes.id, role_id: admin_role.id}
    ]
    |> Animina.Accounts.bulk_create(Animina.Accounts.UserRole, :create,
      return_stream?: false,
      return_records?: false,
      batch_size: 100
    )
  end

  def create_user_role_for_user(changeset) do
    user_role = Animina.Accounts.Role.by_name!(:user)

    Animina.Accounts.UserRole.create(%{
      user_id: changeset.attributes.id,
      role_id: user_role.id
    })
  end

  def get_number_of_users do
    Accounts.User.read!()
    |> length()
  end

  # TODO: Uncomment this if you want to use policies
  # If using policies, add the following bypass:
  # policies do
  #   bypass AshAuthentication.Checks.AshAuthenticationInteraction do
  #     authorize_if always()
  #   end
  # end
end
