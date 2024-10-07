defmodule Animina.Accounts.FastUser do
  @moduledoc """
  This is the Fast User module.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer,
    domain: Animina.Accounts,
    extensions: []

  postgres do
    table "users"
    repo Animina.Repo
  end

  actions do
    defaults []

    action :by_username, {:array, :map} do
      argument :username, :string, allow_nil?: false, public?: true

      run fn input, _ ->
        {:ok, []}
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
    attribute :is_in_waitlist, :boolean, default: false, public?: true

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
    attribute :registration_completed_at, :utc_datetime_usec, allow_nil?: true, public?: true
    attribute :preapproved_communication_only, :boolean, default: false, public?: true
    attribute :streak, :integer, default: 0, public?: true
    attribute :confirmed_at, :utc_datetime_usec, allow_nil?: true, public?: true

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
end
