defmodule Animina.Narratives.FastStory do
  @moduledoc """
  This is the fast story resource.
  """

  alias Animina.Accounts.OptimizedPhoto
  alias Animina.Accounts.Photo
  alias Animina.Accounts.User
  alias Animina.Narratives.Headline
  alias Animina.Repo

  import Ecto.Query

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    notifiers: [],
    domain: Animina.Narratives

  postgres do
    table "stories"
    repo Animina.Repo
  end

  code_interface do
    domain Animina.Accounts
    define :by_user_id
  end

  actions do
    defaults []

    action :by_user_id, :map do
      argument :id, :string, allow_nil?: false
      argument :limit, :integer, default: 10
      argument :page, :integer, default: 1, constraints: [min: 1]
      argument :sort_position_by, :atom, constraints: [one_of: [:asc, :desc]], default: :asc

      run fn input, _ ->
        # story to ecto query
        {:ok, query} =
          Ash.Query.new(__MODULE__)
          |> Ash.Query.data_layer_query()

        # headline to ecto query
        {:ok, headline_query} =
          Ash.Query.new(Headline)
          |> Ash.Query.data_layer_query()

        # user to ecto query
        {:ok, user_query} =
          Ash.Query.new(User)
          |> Ash.Query.data_layer_query()

        # photo to ecto query
        {:ok, photo_query} =
          Ash.Query.new(Photo)
          |> Ash.Query.data_layer_query()

        # optimized photo to ecto query
        {:ok, optimized_photo_query} =
          Ash.Query.new(OptimizedPhoto)
          |> Ash.Query.data_layer_query()

        # total stories query
        total_count_query =
          from s in query,
            where: s.user_id == ^input.arguments.id,
            select: count(s.id)

        # query pagination
        limit = input.arguments.limit
        offset = (input.arguments.page - 1) * input.arguments.limit

        query =
          from s in query,
            where: s.user_id == ^input.arguments.id,
            left_join: u in subquery(user_query),
            on: s.user_id == u.id,
            left_join: p in subquery(photo_query),
            on: s.id == p.story_id,
            left_join: op in subquery(optimized_photo_query),
            on: p.id == op.photo_id,
            left_join: h in subquery(headline_query),
            on: h.id == s.headline_id,
            group_by: [
              s.id,
              u.id,
              u.username,
              u.name,
              p.id,
              p.filename,
              p.original_filename,
              p.state,
              h.id,
              h.subject
            ],
            limit: ^limit,
            offset: ^offset,
            order_by: [{^input.arguments.sort_position_by, s.position}],
            select: %{
              id: s.id,
              content: s.content,
              position: s.position,
              user_id: s.user_id,
              headline_id: s.headline_id,
              created_at: s.created_at,
              updated_at: s.updated_at,
              headline:
                fragment(
                  "json_build_object('id', ?, 'subject', ?)",
                  h.id,
                  h.subject
                ),
              user:
                fragment(
                  "json_build_object('id', ?, 'username', ?, 'name', ?)",
                  u.id,
                  u.username,
                  u.name
                ),
              photo:
                fragment(
                  "CASE WHEN ? IS NOT NULL THEN json_build_object('id', ?, 'filename', ?, 'original_filename', ?, 'state', ?, 'optimized_photos', json_agg(DISTINCT jsonb_build_object('id', ?, 'image_url', ?, 'type', ?, 'user_id', ?, 'photo_id', ?))) ELSE NULL END",
                  p.id,
                  p.id,
                  p.filename,
                  p.original_filename,
                  p.state,
                  op.id,
                  op.image_url,
                  op.type,
                  op.user_id,
                  op.photo_id
                ),
              count: subquery(total_count_query)
            }

        # load the results
        results =
          Repo.all(query)

        # get count of total results
        count = Enum.at(results, 0, %{}) |> Map.get(:count)

        # cast photo, user to struct
        results =
          Enum.map(results, fn story ->
            # some stories may not have a photo
            story =
              if story.photo != nil do
                photo = struct(Photo, Animina.keys_to_atoms(story.photo))

                optimized_photos =
                  Enum.map(photo.optimized_photos, fn optimized_photo ->
                    struct(OptimizedPhoto, optimized_photo)
                  end)

                Map.merge(story, %{
                  photo:
                    Map.merge(photo, %{
                      optimized_photos: optimized_photos
                    })
                })
              else
                story
              end

            # build user struct
            user = struct(User, Animina.keys_to_atoms(story.user))
            # build headline struct
            headline = struct(Headline, Animina.keys_to_atoms(story.headline))
            # build story struct
            story = struct(__MODULE__, story)

            Map.merge(story, %{user: user, headline: headline})
          end)

        results =
          struct(Ash.Page.Offset, %{
            count: count,
            results: results,
            offset: offset,
            more?: count > input.arguments.page * input.arguments.limit,
            page: input.arguments.page,
            limit: input.arguments.limit
          })

        {:ok, results}
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string, public?: true
    attribute :position, :integer, public?: true
    attribute :user_id, :uuid, public?: true
    attribute :headline_id, :uuid, public?: true
    attribute :user, :map, public?: true, generated?: true
    attribute :photo, :map, public?: true, generated?: true
    attribute :headline, :map, public?: true, generated?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end
end
