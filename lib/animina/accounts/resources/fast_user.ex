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
    define :by_id_email_or_username, args: [:id, :username, :email]
  end

  actions do
    defaults []

    action :by_id_email_or_username, :map do
      argument :id, :string, public?: true
      argument :username, :string, public?: true
      argument :email, :string, public?: true

      run fn input, _ ->
        # user to ecto query
        {:ok, query} =
          Ash.Query.new(__MODULE__)
          |> Ash.Query.data_layer_query()

        # roles to ecto query
        {:ok, roles_query} =
          Ash.Query.new(Role)
          |> Ash.Query.data_layer_query()

        # user roles to ecto query
        {:ok, user_roles_query} =
          Ash.Query.new(UserRole)
          |> Ash.Query.data_layer_query()

        # city to ecto query
        {:ok, city_query} =
          Ash.Query.new(City)
          |> Ash.Query.data_layer_query()

        # photo to ecto query
        {:ok, photo_query} =
          Ash.Query.new(Photo)
          |> Ash.Query.data_layer_query()

        # optimized photo to ecto query
        {:ok, optimized_photo_query} =
          Ash.Query.new(OptimizedPhoto)
          |> Ash.Query.data_layer_query()

        # credit points to ecto query
        {:ok, credit_points_query} =
          Ash.Query.new(Credit)
          |> Ash.Query.data_layer_query()

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

        query =
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
            on: u.id == p.user_id,
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

        # load the results
        result =
          Repo.one(query)

        # cast roles, city, profile_photo to struct
        roles =
          Enum.map(result.roles, fn user_role ->
            user_role = struct(UserRole, keys_to_atoms(user_role))

            Map.merge(user_role, %{
              role: struct(Role, user_role.role)
            })
          end)

        city = struct(City, keys_to_atoms(result.city))
        profile_photo = struct(Photo, keys_to_atoms(result.profile_photo))
        age = UserAge.calculate_age(result.birthday)

        optimized_photos =
          Enum.map(profile_photo.optimized_photos, fn optimized_photo ->
            struct(OptimizedPhoto, optimized_photo)
          end)

        result =
          Map.merge(result, %{
            roles: roles,
            age: age,
            city: city,
            profile_photo: Map.merge(profile_photo, %{optimized_photos: optimized_photos})
          })

        {:ok, result}
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

    attribute :roles, {:array, :map}, public?: true, generated?: true
    attribute :city, :map, public?: true, generated?: true
    attribute :profile_photo, :map, public?: true, generated?: true
    attribute :credit_points, :integer, public?: true, generated?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  def keys_to_atoms(string_key_map) when is_map(string_key_map) do
    for {key, val} <- string_key_map, into: %{}, do: {String.to_atom(key), keys_to_atoms(val)}
  end

  def keys_to_atoms(string_key_list) when is_list(string_key_list) do
    string_key_list
    |> Enum.map(&keys_to_atoms/1)
  end

  def keys_to_atoms(value), do: value
end
