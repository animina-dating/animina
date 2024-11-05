defmodule Animina.Accounts.FastUser do
  @moduledoc """
  This is the Fast User module.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer,
    domain: Animina.Accounts,
    extensions: []

  alias Animina.Accounts.Credit
  alias Animina.Accounts.OptimizedPhoto
  alias Animina.Accounts.Photo
  alias Animina.Accounts.Role
  alias Animina.Accounts.UserRole
  alias Animina.Calculations.UserAge
  alias Animina.GeoData.City
  alias Animina.Repo

  import Ecto.Query

  postgres do
    table "users"
    repo Animina.Repo
  end

  code_interface do
    domain Animina.Accounts
    define :by_id_email_or_username
    define :list
    define :public_users_who_created_an_account_in_the_last_60_days
  end

  actions do
    defaults []

    action :public_users_who_created_an_account_in_the_last_60_days, :map do
      argument :limit, :integer, default: 10
      argument :page, :integer, default: 1, constraints: [min: 1]
      argument :gender, :string, allow_nil?: false

      run fn input, _ ->
        # we dont need to filter by id, username or email. So we pass true as filter
        query = build_query(true, true, true)

        date = DateTime.add(DateTime.utc_now(), -60, :day)

        # query pagination
        limit = input.arguments.limit
        offset = (input.arguments.page - 1) * input.arguments.limit

        # total users query
        total_count_query =
          from u in user_query(),
            where: u.is_private == ^false,
            where: u.gender == ^input.arguments.gender,
            where: u.state == ^:normal or u.state == ^:validated,
            where: u.created_at >= ^date,
            where: is_nil(u.registration_completed_at) == ^false,
            select: count(u.id)

        # merge pagination and count to query
        query =
          from u in query,
            limit: ^limit,
            offset: ^offset,
            where: u.is_private == ^false,
            where: u.gender == ^input.arguments.gender,
            where: u.state == ^:normal or u.state == ^:validated,
            where: u.created_at >= ^date,
            where: is_nil(u.registration_completed_at) == ^false,
            order_by: fragment("RANDOM()"),
            select_merge: %{count: subquery(total_count_query)}

        # load the results
        results =
          Repo.all(query)

        # get count of total results
        count = Enum.at(results, 0, %{}) |> Map.get(:count, 0)

        # map results to user struct
        results = Enum.map(results, fn user -> to_user_struct(user) end)

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

    action :list, :map do
      argument :limit, :integer, default: 10
      argument :page, :integer, default: 1, constraints: [min: 1]

      run fn input, _ ->
        # we dont need to filter by id, username or email. So we pass true as filter
        query = build_query(true, true, true)

        # query pagination
        limit = input.arguments.limit
        offset = (input.arguments.page - 1) * input.arguments.limit

        # total users query
        total_count_query =
          from u in user_query(),
            select: count(u.id)

        # merge pagination and count to query
        query =
          from u in query,
            limit: ^limit,
            offset: ^offset,
            select_merge: %{count: subquery(total_count_query)}

        # load the results
        results =
          Repo.all(query)

        # get count of total results
        count = Enum.at(results, 0, %{}) |> Map.get(:count, 0)

        # map results to user struct
        results = Enum.map(results, fn user -> to_user_struct(user) end)

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

    action :by_id_email_or_username, :map do
      argument :id, :string, public?: true
      argument :username, :string, public?: true
      argument :email, :string, public?: true

      run fn input, _ ->
        # build where filter
        filter_by_id =
          if input.arguments[:id] != nil do
            dynamic([u], u.id == ^input.arguments.id)
          else
            true
          end

        filter_by_username =
          if input.arguments[:username] != nil do
            dynamic([u], u.username == ^input.arguments.username)
          else
            true
          end

        filter_by_email =
          if input.arguments[:email] != nil do
            dynamic([u], u.email == ^input.arguments.email)
          else
            true
          end

        query = build_query(filter_by_id, filter_by_username, filter_by_email)

        # load the results
        result =
          Repo.one(query)

        if is_nil(result) do
          {:error, :user_not_found}
        else
          user = to_user_struct(result)

          {:ok, user}
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, public?: true
    attribute :is_in_waitlist, :boolean, default: false, public?: true
    attribute :username, :ci_string, public?: true
    attribute :name, :string, public?: true
    attribute :birthday, :date, public?: true
    attribute :zip_code, :string, public?: true
    attribute :country, :string, public?: true
    attribute :gender, :string, public?: true
    attribute :height, :integer, public?: true
    attribute :mobile_phone, :ash_phone_number, public?: true
    attribute :minimum_partner_height, :integer, public?: true
    attribute :maximum_partner_height, :integer, public?: true
    attribute :minimum_partner_age, :integer, public?: true
    attribute :maximum_partner_age, :integer, public?: true
    attribute :partner_gender, :string, public?: true
    attribute :search_range, :integer, public?: true
    attribute :language, :string, public?: true
    attribute :state, :atom, public?: true
    attribute :legal_terms_accepted, :boolean, public?: true
    attribute :registration_completed_at, :utc_datetime_usec, public?: true
    attribute :preapproved_communication_only, :boolean, public?: true
    attribute :streak, :integer, default: 0, public?: true
    attribute :confirmed_at, :utc_datetime_usec, public?: true
    attribute :last_registration_page_visited, :string, public?: true
    attribute :occupation, :string, public?: true
    attribute :is_private, :boolean, public?: true
    attribute :roles, {:array, :map}, public?: true, generated?: true
    attribute :city, :map, public?: true, generated?: true
    attribute :profile_photo, :map, public?: true, generated?: true
    attribute :credit_points, :integer, public?: true, generated?: true
    attribute :count, :integer, public?: true, generated?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  defp build_query(filter_by_id, filter_by_username, filter_by_email) do
    query = user_query()
    user_roles_query = user_roles_query()
    roles_query = roles_query()
    city_query = city_query()
    photo_query = photo_query()
    optimized_photo_query = optimized_photo_query()
    credit_points_query = credit_points_query()

    from u in query,
      where: ^filter_by_username,
      where: ^filter_by_id,
      where: ^filter_by_email,
      left_join: ur in subquery(user_roles_query),
      on: u.id == ur.user_id,
      left_join: r in subquery(roles_query),
      on: ur.role_id == r.id,
      left_join: c in subquery(city_query),
      on: u.zip_code == c.zip_code,
      left_join: p in subquery(photo_query),
      on: u.id == p.user_id and is_nil(p.story_id),
      left_join: op in subquery(optimized_photo_query),
      on: p.id == op.photo_id,
      left_join: cr in subquery(credit_points_query),
      on: u.id == cr.user_id,
      group_by: [
        u.id,
        c.id,
        c.name,
        c.zip_code,
        c.lat,
        c.lon,
        p.id,
        p.filename,
        p.original_filename,
        p.state
      ],
      select: %{
        u
        | roles:
            fragment(
              "json_agg(DISTINCT jsonb_build_object('id', ?, 'user_id', ?, 'role_id', ?, 'role', json_build_object('id', ?, 'name', ?)))",
              ur.id,
              ur.user_id,
              ur.role_id,
              r.id,
              r.name
            ),
          city:
            fragment(
              "json_build_object('id', ?, 'name', ?, 'zip_code', ?, 'lat', ?, 'lon', ?)",
              c.id,
              c.name,
              c.zip_code,
              c.lat,
              c.lon
            ),
          profile_photo:
            fragment(
              "json_build_object('id', ?, 'filename', ?, 'original_filename', ?, 'state', ?, 'optimized_photos', json_agg(DISTINCT jsonb_build_object('id', ?, 'image_url', ?, 'type', ?, 'user_id', ?, 'photo_id', ?)))",
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
          credit_points: coalesce(sum(cr.points), 0) |> type(:integer)
      }
  end

  defp to_user_struct(user) do
    # cast roles, city, profile_photo to struct
    roles =
      Enum.map(user.roles, fn user_role ->
        user_role = struct(UserRole, Animina.keys_to_atoms(user_role))

        Map.merge(user_role, %{
          role: struct(Role, user_role.role)
        })
      end)

    city = struct(City, Animina.keys_to_atoms(user.city))
    profile_photo = struct(Photo, Animina.keys_to_atoms(user.profile_photo))
    age = UserAge.calculate_age(user.birthday)

    optimized_photos =
      Enum.map(profile_photo.optimized_photos, fn optimized_photo ->
        struct(OptimizedPhoto, optimized_photo)
      end)

    Map.merge(user, %{
      roles: roles,
      age: age,
      city: city,
      profile_photo: Map.merge(profile_photo, %{optimized_photos: optimized_photos})
    })
  end

  defp user_query do
    {:ok, query} =
      Ash.Query.new(__MODULE__)
      |> Ash.Query.data_layer_query()

    query
  end

  defp roles_query do
    {:ok, query} =
      Ash.Query.new(Role)
      |> Ash.Query.data_layer_query()

    query
  end

  defp user_roles_query do
    {:ok, query} =
      Ash.Query.new(UserRole)
      |> Ash.Query.data_layer_query()

    query
  end

  defp city_query do
    {:ok, query} =
      Ash.Query.new(City)
      |> Ash.Query.data_layer_query()

    query
  end

  defp photo_query do
    {:ok, query} =
      Ash.Query.new(Photo)
      |> Ash.Query.data_layer_query()

    query
  end

  defp optimized_photo_query do
    {:ok, query} =
      Ash.Query.new(OptimizedPhoto)
      |> Ash.Query.data_layer_query()

    query
  end

  defp credit_points_query do
    {:ok, query} =
      Ash.Query.new(Credit)
      |> Ash.Query.data_layer_query()

    query
  end
end
