defmodule Animina.Accounts.Photo do
  @moduledoc """
  This is the Photo module which we use to manage user photos.
  """

  alias Animina.Accounts

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStateMachine]

  attributes do
    uuid_primary_key :id
    attribute :filename, :string, allow_nil?: false
    attribute :original_filename, :string, allow_nil?: false
    attribute :mime, :string, allow_nil?: false
    attribute :size, :integer, allow_nil?: false
    attribute :ext, :string, allow_nil?: false
    attribute :dimensions, :map

    attribute :error, :string
    attribute :error_state, :string

    attribute :state, :atom do
      constraints one_of: [:pending_review, :in_review, :approved, :rejected, :error]

      default :pending_review
      allow_nil? false
    end
  end

  state_machine do
    initial_states([:pending_review])
    default_initial_state(:pending_review)

    transitions do
      transition(:review, from: :pending_review, to: :in_review)
      transition(:approve, from: :in_review, to: :approved)
      transition(:report, from: :approved, to: :in_review)
      transition(:reject, from: :in_review, to: :rejected)
      transition(:error, from: [:pending_review, :in_review, :approved, :rejected], to: :error)
    end
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :story, Animina.Narratives.Story do
      api Animina.Narratives
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :update]

    read :read do
      primary? true
      pagination offset?: true, keyset?: true, required?: false
    end

    read :user_profile_photo do
      argument :user_id, :uuid, allow_nil?: false

      pagination offset?: true, keyset?: true, required?: false

      filter expr(is_nil(story_id) == ^true and user_id == ^arg(:user_id))
    end

    update :review do
      change transition_state(:in_review)
    end

    update :approve do
      change transition_state(:approved)
    end

    update :report do
      change transition_state(:in_review)
    end

    update :reject do
      change transition_state(:rejected)
    end

    update :error do
      accept [:error_state, :error]
      change transition_state(:error)
    end
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :create
    define :by_id, get_by: [:id], action: :read
  end

  changes do
    change after_transaction(fn
             changeset, {:ok, result} ->
               {:ok, result}

             changeset, {:error, error} ->
               message = Exception.message(error)

               changeset.data
               |> Ash.Changeset.for_update(:error, %{
                 message: message,
                 error_state: changeset.data.state
               })
               |> Accounts.update()
           end),
           on: :update
  end

  postgres do
    table "photos"
    repo Animina.Repo

    references do
      reference :user, on_delete: :delete
    end
  end
end
