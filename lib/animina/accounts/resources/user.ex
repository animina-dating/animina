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
    attribute :username, :string, allow_nil?: false
  end

  calculations do
    # bob = Animina.Accounts.User.by_username!("bob")
    # bob |> Animina.Accounts.load(:gravatar_hash)
    calculate :gravatar_hash, :string, {Animina.Calculations.Md5, field: :email}
  end

  authentication do
    api Animina.Accounts

    strategies do
      password :password do
        identity_field :email
        sign_in_tokens_enabled? true
        confirmation_required?(false)
        register_action_accept([:username])
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
    defaults [:read]
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :by_username, get_by: [:username], action: :read
  end

  # TODO: Uncomment this if you want to use policies
  # If using policies, add the following bypass:
  # policies do
  #   bypass AshAuthentication.Checks.AshAuthenticationInteraction do
  #     authorize_if always()
  #   end
  # end
end
