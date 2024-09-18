defmodule Animina.Traits.UserFlags do
  alias Animina.Repo
  alias Animina.Validations

  import Ecto.Query

  @moduledoc """
  This is the UserFlags module which we use to manage a user's flags.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub],
    domain: Animina.Traits

  postgres do
    table "user_flags"
    repo Animina.Repo

    references do
      reference :user, on_delete: :delete
      reference :flag, on_delete: :delete
    end

    custom_indexes do
      index [:user_id]
      index [:flag_id]
      index [:flag_id, :user_id]
      index [:color, :user_id]
    end
  end

  code_interface do
    domain Animina.Traits
    define :read
    define :create
    define :by_id, get_by: [:id], action: :read
    define :destroy
    define :by_user_id, args: [:id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :flag_id,
        :user_id,
        :color,
        :position
      ]

      primary? true
    end

    read :by_user_id do
      argument :id, :uuid, allow_nil?: false, public?: true

      prepare build(sort: [position: :asc])

      filter expr(user_id == ^arg(:id))
    end

    action :intersecting_flags_by_color, {:array, :map} do
      argument :current_user, :uuid, allow_nil?: false, public?: true
      argument :user, :uuid, allow_nil?: false, public?: true
      argument :current_user_color, :string, allow_nil?: false, public?: true
      argument :user_color, :string, allow_nil?: false, public?: true

      run fn input, _ ->
        # user flags to ecto query
        {:ok, query} =
          Ash.Query.new(__MODULE__)
          |> Ash.Query.data_layer_query()

        # flags to ecto query
        {:ok, flags_query} =
          Ash.Query.new(Animina.Traits.Flag)
          |> Ash.Query.data_layer_query()

        # flags_translations to ecto query
        {:ok, flags_translations_query} =
          Ash.Query.new(Animina.Traits.FlagTranslation)
          |> Ash.Query.data_layer_query()

        # subquery that finds the flag_ids that the users have in common
        intersecting_flags_query =
          from u in query,
            where:
              (u.user_id == ^input.arguments.current_user and
                 u.color == fragment("?", ^input.arguments.current_user_color)) or
                (u.user_id == ^input.arguments.user and
                   u.color == fragment("?", ^input.arguments.user_color)),
            group_by: u.flag_id,
            having: fragment("COUNT(DISTINCT ?)", u.user_id) == 2,
            select: u.flag_id

        # subquery that loads the flag_translations
        flags_query =
          from ft in flags_query,
            left_join: tr in subquery(flags_translations_query),
            on: tr.flag_id == ft.id,
            group_by: [
              ft.id,
              ft.name,
              ft.emoji,
              ft.category_id,
              ft.photo_flagable
            ],
            select: %{
              id: ft.id,
              name: ft.name,
              emoji: ft.emoji,
              category_id: ft.category_id,
              photo_flagable: ft.photo_flagable,
              flag_translations: fragment("json_agg(?)", tr)
            }

        # query that finds the user_flags that have the flag_ids that the users have
        # in common and loads the flags
        query =
          from uf in query,
            where: uf.flag_id in subquery(intersecting_flags_query),
            where: uf.user_id in ^[input.arguments.current_user, input.arguments.user],
            left_join: fl in subquery(flags_query),
            on: fl.id == uf.flag_id,
            select: %{
              id: uf.id,
              flag: fl,
              flag_id: uf.flag_id,
              user_id: uf.user_id,
              position: uf.position,
              color: uf.color,
              created_at: uf.created_at,
              updated_at: uf.updated_at
            }

        # load the results into user_flags struct
        results =
          Repo.all(query)
          |> Enum.map(fn record ->
            record = struct(__MODULE__, record)
            flag = struct(Animina.Traits.Flag, record.flag)

            flag_tranlations =
              Enum.filter(record.flag.flag_translations, fn translation ->
                is_nil(translation) == false
              end)
              |> Enum.map(fn translation ->
                # convert the translation to a map with atom keys
                translation = Map.new(translation, fn {k, v} -> {String.to_atom(k), v} end)
                struct(Animina.Traits.FlagTranslation, translation)
              end)

            flag = Map.merge(flag, %{flag_translations: flag_tranlations})

            Map.merge(record, %{flag: flag})
          end)

        {:ok, results}
      end
    end
  end

  pub_sub do
    module Animina
    prefix "user_flag"

    broadcast_type :phoenix_broadcast
    publish :create, ["created", [:user_id, nil]]
    publish :destroy, ["deleted", [:user_id, :id]]
  end

  preparations do
    prepare build(load: [:flag])
  end

  validations do
    validate {Validations.UniqueColorUserFlags,
              user_id: :user_id, color: :color, flag_id: :flag_id}
  end

  attributes do
    uuid_primary_key :id

    attribute :flag_id, :uuid, allow_nil?: false, public?: true
    attribute :user_id, :uuid, allow_nil?: false, public?: true
    attribute :position, :integer, allow_nil?: false, public?: true

    attribute :color, :atom do
      constraints one_of: [:white, :green, :red]
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      domain Animina.Accounts
      allow_nil? false
      attribute_writable? true
    end

    has_one :flag, Animina.Traits.Flag do
      source_attribute :flag_id
      destination_attribute :id
    end
  end
end
