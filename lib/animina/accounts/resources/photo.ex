defmodule Animina.Accounts.Photo do
  @moduledoc """
  This is the Photo module which we use to manage user photos.
  """
  alias Animina.Accounts
  alias Animina.Accounts.OptimizedPhoto
  alias Animina.Narratives

  require Logger

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Accounts,
    notifiers: [Ash.Notifier.PubSub, Animina.Notifiers.Photo],
    extensions: [AshStateMachine, AshOban]

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
      constraints one_of: [:pending_review, :in_review, :approved, :rejected, :error, :nsfw]

      default :pending_review
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  pub_sub do
    module Animina
    prefix "photo"

    broadcast_type :phoenix_broadcast

    publish :update, ["updated", :id]
    publish :reject, ["updated", :id]
    publish :approve, ["updated", :id]
  end

  state_machine do
    initial_states([:pending_review])
    default_initial_state(:pending_review)

    transitions do
      transition(:review, from: :pending_review, to: :in_review)
      transition(:approve, from: :in_review, to: :approved)
      transition(:report, from: :approved, to: :in_review)
      transition(:reject, from: :in_review, to: :rejected)
      transition(:nsfw, from: :in_review, to: :nsfw)
      transition(:error, from: [:pending_review, :in_review, :approved, :rejected], to: :error)
    end
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :story, Animina.Narratives.Story do
      domain Animina.Narratives
      attribute_writable? true
    end

    has_many :optimized_photos, Animina.Accounts.OptimizedPhoto do
      domain Animina.Accounts
    end
  end

  actions do
    defaults [:destroy]

    create :create do
      accept [
        :filename,
        :original_filename,
        :mime,
        :size,
        :ext,
        :dimensions,
        :error,
        :error_state,
        :state,
        :user_id,
        :story_id
      ]

      primary? true
    end

    read :read do
      primary? true
      pagination offset?: true, keyset?: true, required?: false
    end

    read :user_profile_photo do
      argument :user_id, :uuid, allow_nil?: false

      pagination offset?: true, keyset?: true, required?: false

      filter expr(is_nil(story_id) == ^true and user_id == ^arg(:user_id))
    end

    read :by_user_id do
      pagination offset?: true, keyset?: true, required?: false

      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))
    end

    update :review do
      require_atomic? false
      change transition_state(:in_review)
    end

    update :approve do
      require_atomic? false
      change transition_state(:approved)
    end

    update :report do
      require_atomic? false
      change transition_state(:in_review)
    end

    update :reject do
      require_atomic? false
      change transition_state(:rejected)
    end

    update :nsfw do
      require_atomic? false
      change transition_state(:nsfw)
    end

    update :error do
      require_atomic? false
      accept [:error_state, :error]
      change transition_state(:error)
    end

    update :process do
      transaction? false
      require_atomic? false
      manual Animina.Actions.ProcessPhoto
    end
  end

  code_interface do
    domain Animina.Accounts
    define :read
    define :create
    define :by_id, get_by: [:id], action: :read
    define :destroy
    define :by_user_id, args: [:user_id]
  end

  changes do
    change after_transaction(fn
             changeset, {:ok, result}, _context ->
               {:ok, result}

             changeset, {:error, error}, _context ->
               message = Exception.message(error)

               changeset.data
               |> Ash.Changeset.for_update(:error, %{
                 error: message,
                 error_state: changeset.data.state
               })
               |> Ash.update()
           end),
           on: :update

    change after_action(fn changeset, record, _ ->
             create_optimized_photos(record)

             {:ok, record}
           end),
           on: [:create]

    change after_action(fn changeset, record, _ ->
             update_user_registration_completed_at(record.user_id)
             {:ok, record}
           end),
           on: [:create, :destroy]
  end

  postgres do
    table "photos"
    repo Animina.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  def get_optimized_photo_to_use(photo, type) do
    case OptimizedPhoto.by_type_and_photo_id(%{type: type, photo_id: photo.id}) do
      {:ok, optimized_photo} ->
        extract_uploads_path(optimized_photo.image_url)

      _ ->
        "/uploads/#{photo.filename}"
    end
  end

  defp update_user_registration_completed_at(user_id) do
    user =
      Accounts.User.by_id!(user_id)

    case Narratives.Story.by_user_id(user_id) do
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

  def extract_uploads_path(path) do
    case Regex.run(~r/\/uploads.*/, path) do
      [matched_path] -> matched_path
      _ -> nil
    end
  end

  def create_optimized_photos(record) do
    create_optimized_folder_if_not_exists()

    case check_if_image_magick_is_installed() do
      {:ok, _} ->
        resize_image(record)

      {:error, _} ->
        copy_image_directly(record)
    end
  end

  defp create_optimized_folder_if_not_exists do
    for type <- ["thumbnail", "normal", "big"] do
      case File.mkdir_p("priv/static/uploads/optimized/#{type}") do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to create directory '/uploads/optimized/#{type}' : #{reason}")
      end
    end
  end

  defp copy_image_directly(record) do
    for type <- [:thumbnail, :normal, :big] do
      OptimizedPhoto.create(%{
        image_url: copy_image(record.filename, type),
        type: type,
        user_id: record.user_id,
        photo_id: record.id
      })
    end
  end

  defp copy_image(file_name, type) do
    if File.exists?("priv/static/uploads/" <> file_name) do
      case File.cp!(
             "priv/static/uploads/" <> file_name,
             "priv/static/uploads/optimized/#{type}/#{file_name}"
           ) do
        :ok ->
          "/uploads/optimized/#{type}/#{file_name}"

        {:error, reason} ->
          Logger.error("Failed to copy '/uploads/optimized/#{type}/#{file_name}' : #{reason}")

          "/uploads/optimized/#{type}/#{file_name}"
      end
    else
      file_name
    end
  end

  defp resize_image(record) do
    for type <- [
          %{
            width: 100,
            height: 100,
            type: :thumbnail
          },
          %{
            width: 600,
            height: 600,
            type: :normal
          },
          %{
            width: 1000,
            type: :big
          }
        ] do
      if File.exists?("priv/static/uploads/" <> record.file_name) do
        OptimizedPhoto.create(%{
          image_url: resize_image(record.filename, type.width, type.type),
          type: type.type,
          user_id: record.user_id,
          photo_id: record.id
        })
      else
        OptimizedPhoto.create(%{
          image_url: record.file_name,
          type: type.type,
          user_id: record.user_id,
          photo_id: record.id
        })
      end
    end
  end

  defp resize_image(image_path, width, type) do
    image =
      Mogrify.open("priv/static/uploads/" <> image_path)
      |> Mogrify.resize("#{width}")
      |> Mogrify.format("webp")
      |> Mogrify.save(path: "priv/static/uploads/optimized/#{type}/#{image_path}")

    image.path
  end

  def check_if_image_magick_is_installed do
    {output, 0} = System.cmd("convert", ["--version"])
    {:ok, output}
  rescue
    e in ErlangError ->
      if e.reason == :enoent do
        {:error, "ImageMagick is not installed or not in the system's PATH"}
      else
        {:error, "An unknown error occurred: #{inspect(e)}"}
      end
  end
end
