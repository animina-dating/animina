defmodule Animina.Accounts.User do
  @moduledoc """
  This is the User module.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true

    attribute :username, :ci_string do
      constraints max_length: 15,
                  min_length: 2,
                  match: ~r/^[A-Za-z_-]*$/,
                  trim?: true,
                  allow_empty?: false
    end

    attribute :name, :string do
      constraints max_length: 50,
                  min_length: 1,
                  trim?: true,
                  allow_empty?: false
    end

    attribute :birthday, :date, allow_nil?: false
    attribute :zip_code, :string, allow_nil?: false
    attribute :gender, :string, allow_nil?: false
    attribute :height, :integer, allow_nil?: false
    attribute :mobile_phone, :string, allow_nil?: false
    # attribute :body_type, :integer, allow_nil?: false
    # attribute :subscribed_at, :utc_datetime, allow_nil?: false
    # attribute :terms_conds_id, :uuid, allow_nil?: true

    attribute :minimum_partner_height, :integer, allow_nil?: true
    attribute :maximum_partner_height, :integer, allow_nil?: true
    attribute :minimum_partner_age, :integer, allow_nil?: true
    attribute :maximum_partner_age, :integer, allow_nil?: true
  end

  relationships do
    has_many :credits, Animina.Accounts.Credit
  end

  calculations do
    calculate :gravatar_hash, :string, {Animina.Calculations.Md5, field: :email}
    calculate :age, :integer, {Animina.Calculations.UserAge, field: :birthday}
  end

  aggregates do
    sum :credit_points, :credits, :points, default: 0
  end

  preparations do
    prepare build(load: [:gravatar_hash, :age, :credit_points])
  end

  authentication do
    api Animina.Accounts

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
          :mobile_phone
        ])
      end
    end

    tokens do
      enabled? true
      token_resource Animina.Accounts.Token

      signing_secret Animina.Accounts.Secrets
    end
  end

  postgres do
    table "users"
    repo Animina.Repo
  end

  identities do
    identity :unique_email, [:email]
    identity :unique_username, [:username]
  end

  actions do
    defaults [:create, :read, :update]
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :create
    define :update
    define :by_username, get_by: [:username], action: :read
    define :by_id, get_by: [:id], action: :read
    define :by_email, get_by: [:email], action: :read
  end

  # TODO: Uncomment this if you want to use policies
  # If using policies, add the following bypass:
  # policies do
  #   bypass AshAuthentication.Checks.AshAuthenticationInteraction do
  #     authorize_if always()
  #   end
  # end
end
