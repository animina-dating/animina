defmodule Animina.Narratives.Story do
  alias Animina.Accounts
  alias Animina.Validations

  @moduledoc """
  This is the story resource.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub],
    domain: Animina.Narratives

  postgres do
    table "stories"
    repo Animina.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  code_interface do
    domain Animina.Narratives
    define :read
    define :create
    define :update
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :by_user_id_with_headline, args: [:user_id]
    define :by_user_id, args: [:user_id]
    define :descending_by_user_id, args: [:user_id]
    define :about_story_by_user, args: [:user_id], get?: true
  end

  actions do
    defaults [:destroy]

    create :create do
      accept [
        :content,
        :position,
        :user_id,
        :headline_id
      ]

      primary? true
    end

    update :update do
      accept [
        :content,
        :position,
        :user_id,
        :headline_id
      ]

      require_atomic? false
    end

    read :read do
      primary? true

      pagination offset?: true, keyset?: true, required?: false

      prepare build(load: [:headline, :photo])
    end

    read :by_user_id do
      pagination offset?: true, keyset?: true, required?: false

      argument :user_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:headline, :photo, :user])

      prepare build(sort: [position: :asc])

      filter expr(user_id == ^arg(:user_id))
    end

    read :by_user_id_with_headline do
      pagination offset?: true, keyset?: true, required?: false

      argument :user_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:headline])

      filter expr(user_id == ^arg(:user_id))
    end

    read :descending_by_user_id do
      pagination offset?: true, keyset?: true, required?: false

      argument :user_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:headline, :photo, :user])

      prepare build(sort: [position: :desc])

      filter expr(user_id == ^arg(:user_id))
    end

    read :user_headlines do
      argument :user_id, :uuid, allow_nil?: false

      prepare build(load: [:headline, :photo, :user])

      filter expr(is_nil(headline_id) == ^false and user_id == ^arg(:user_id))
    end

    read :about_story_by_user do
      argument :user_id, :uuid, allow_nil?: false

      prepare build(load: [:headline])

      filter expr(user_id == ^arg(:user_id) and headline.subject == "About me")
    end
  end

  pub_sub do
    module Animina
    prefix "story"

    broadcast_type :phoenix_broadcast

    publish :create, ["created", [:user_id, nil]]
    publish :update, ["updated", :id]
    publish :destroy, ["deleted", [:id]]

    publish_all :destroy, ["deleted", [:user_id, :id]]
  end

  changes do
    change after_action(fn changeset, record, _ ->
             update_user_registration_completed_at(record.user_id)
             {:ok, record}
           end),
           on: [:create, :destroy]
  end

  validations do
    validate {Validations.AboutStory, headline: :headline_id, user: :user_id}
    validate {Validations.DeleteAboutStory, headline: :headline_id, user: :user_id}, on: :destroy
    validate present(:headline_id)
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      constraints max_length: 1_024
    end

    attribute :position, :integer, allow_nil?: false

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      domain Animina.Accounts
      attribute_writable? true
    end

    belongs_to :headline, Animina.Narratives.Headline do
      attribute_writable? true
    end

    has_one :photo, Animina.Accounts.Photo do
      domain Animina.Accounts
    end
  end

  identities do
    identity :unique_position, [:position, :user_id]
  end

  defp update_user_registration_completed_at(user_id) do
    user = Accounts.User.by_id!(user_id)

    case by_user_id(user_id) do
      {:ok, stories} ->
        if Enum.count(stories) >=
             Application.get_env(:animina, :number_of_stories_required_for_complete_registration) and
             user.registration_completed_at == nil and user.profile_photo != nil do
          Accounts.User.update(user, %{registration_completed_at: DateTime.utc_now()})
        end

      _ ->
        :ok
    end
  end
end
