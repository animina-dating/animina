defmodule Animina.Traits do
  @moduledoc """
  Context for personality traits: categories, flags, user flags, opt-ins, and matching.

  This module acts as a facade, delegating to specialized sub-modules:
  - `Animina.Traits.Matching` - Flag overlap computation for user compatibility
  - `Animina.Traits.Validations` - Single-select, exclusive-hard, and mixing validations
  """

  import Ecto.Query

  alias Animina.Repo
  alias Animina.Traits.{Category, Flag, UserCategoryOptIn, UserFlag, UserWhiteFlagCategoryPublish}
  alias Animina.Traits.Validations
  alias Animina.Utils.PaperTrail, as: PT

  # --- Categories ---

  def list_categories do
    Category
    |> order_by(:position)
    |> Repo.all()
  end

  def list_visible_categories(user) do
    sensitive_opted_ids =
      from(o in UserCategoryOptIn,
        where: o.user_id == ^user.id,
        select: o.category_id
      )
      |> Repo.all()

    from(c in Category,
      where: c.sensitive == false or c.id in ^sensitive_opted_ids,
      order_by: c.position
    )
    |> Repo.all()
  end

  def list_core_categories do
    from(c in Category, where: c.core == true, order_by: c.position)
    |> Repo.all()
  end

  def list_optin_categories do
    from(c in Category, where: c.core == false, order_by: c.position)
    |> Repo.all()
  end

  def list_user_optin_category_ids(user) do
    from(o in UserCategoryOptIn, where: o.user_id == ^user.id, select: o.category_id)
    |> Repo.all()
  end

  def toggle_category_optin(user, category, opts \\ []) do
    pt_opts = PT.opts(opts)

    case Repo.get_by(UserCategoryOptIn, user_id: user.id, category_id: category.id) do
      nil ->
        %UserCategoryOptIn{}
        |> UserCategoryOptIn.changeset(%{user_id: user.id, category_id: category.id})
        |> PaperTrail.insert(pt_opts)
        |> PT.unwrap()

      opt_in ->
        PaperTrail.delete(opt_in, pt_opts) |> PT.unwrap()
    end
  end

  def list_wizard_categories(user) do
    optin_ids = list_user_optin_category_ids(user)

    from(c in Category,
      where: c.core == true or c.id in ^optin_ids,
      order_by: c.position
    )
    |> Repo.all()
  end

  def get_category!(id), do: Repo.get!(Category, id)

  def create_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  # --- Flags ---

  def list_top_level_flags_by_category(category) do
    from(f in Flag,
      where: f.category_id == ^category.id and is_nil(f.parent_id),
      order_by: f.position,
      preload: [:children]
    )
    |> Repo.all()
  end

  def list_flags_by_category(category) do
    from(f in Flag,
      where: f.category_id == ^category.id,
      order_by: f.position
    )
    |> Repo.all()
  end

  def get_flag_with_children!(id) do
    Flag
    |> Repo.get!(id)
    |> Repo.preload(children: from(f in Flag, order_by: f.position))
  end

  def create_flag(attrs) do
    changeset = Flag.changeset(%Flag{}, attrs)

    case Ecto.Changeset.get_change(changeset, :parent_id) || Map.get(attrs, :parent_id) do
      nil ->
        Repo.insert(changeset)

      parent_id ->
        if nesting_depth_exceeded?(parent_id) do
          changeset
          |> Ecto.Changeset.add_error(:parent_id, "maximum nesting depth of 2 levels exceeded")
          |> Repo.insert()
        else
          Repo.insert(changeset)
        end
    end
  end

  defp nesting_depth_exceeded?(parent_id) do
    parent = Repo.get!(Flag, parent_id)
    not is_nil(parent.parent_id)
  end

  # --- User Flags ---

  def add_user_flag(attrs, opts \\ []) do
    changeset = UserFlag.changeset(%UserFlag{}, attrs)
    pt_opts = PT.opts(opts)

    with :ok <- Validations.validate_single_select(attrs),
         :ok <- Validations.validate_exclusive_hard(attrs),
         :ok <- Validations.validate_no_mixing(attrs),
         {:ok, user_flag} <- PaperTrail.insert(changeset, pt_opts) |> PT.unwrap() do
      expand_on_write(user_flag)
      maybe_broadcast_white_flags(user_flag)
      {:ok, user_flag}
    end
  end

  defp maybe_broadcast_white_flags(%{color: "white", user_id: user_id}) do
    broadcast_white_flags_updated(user_id)
  end

  defp maybe_broadcast_white_flags(_user_flag), do: :ok

  defp expand_on_write(user_flag) do
    flag = Repo.get!(Flag, user_flag.flag_id) |> Repo.preload(:children)

    Enum.each(flag.children, fn child ->
      %UserFlag{}
      |> UserFlag.changeset(%{
        user_id: user_flag.user_id,
        flag_id: child.id,
        color: user_flag.color,
        intensity: user_flag.intensity,
        position: user_flag.position,
        inherited: true,
        source_flag_id: flag.id
      })
      |> Repo.insert(on_conflict: :nothing)
    end)
  end

  def update_user_flag_intensity(user_flag_id, new_intensity, opts \\ []) do
    user_flag = Repo.get!(UserFlag, user_flag_id)
    pt_opts = PT.opts(opts)

    with :ok <- Validations.validate_exclusive_hard_update(user_flag, new_intensity) do
      with {:ok, updated} <-
             user_flag
             |> UserFlag.changeset(%{intensity: new_intensity})
             |> PaperTrail.update(pt_opts)
             |> PT.unwrap() do
        from(uf in UserFlag,
          where: uf.user_id == ^updated.user_id and uf.source_flag_id == ^updated.flag_id
        )
        |> Repo.update_all(set: [intensity: new_intensity])

        {:ok, updated}
      end
    end
  end

  def remove_user_flag(user, user_flag_id, opts \\ []) do
    pt_opts = PT.opts(opts)

    case Repo.get_by(UserFlag, id: user_flag_id, user_id: user.id) do
      nil ->
        {:ok, :already_removed}

      user_flag ->
        color = user_flag.color

        from(uf in UserFlag,
          where: uf.user_id == ^user.id and uf.source_flag_id == ^user_flag.flag_id
        )
        |> Repo.delete_all()

        result = PaperTrail.delete(user_flag, pt_opts) |> PT.unwrap()

        # Broadcast white flag changes
        if color == "white" do
          broadcast_white_flags_updated(user.id)
        end

        result
    end
  end

  def exclusive_hard_has_others?(user_id, flag_id, color) do
    if color in ["white", "red"] do
      false
    else
      flag = Repo.get!(Flag, flag_id) |> Repo.preload(:category)
      category = flag.category

      if category.exclusive_hard do
        from(uf in UserFlag,
          join: f in Flag,
          on: f.id == uf.flag_id,
          where:
            uf.user_id == ^user_id and
              uf.color == ^color and
              uf.inherited == false and
              f.category_id == ^category.id and
              uf.flag_id != ^flag_id
        )
        |> Repo.exists?()
      else
        false
      end
    end
  end

  def remove_other_exclusive_hard_flags(user, flag_id, color) do
    flag = Repo.get!(Flag, flag_id) |> Repo.preload(:category)
    category = flag.category

    if category.exclusive_hard && color != "white" do
      other_flags =
        from(uf in UserFlag,
          join: f in Flag,
          on: f.id == uf.flag_id,
          where:
            uf.user_id == ^user.id and
              uf.color == ^color and
              uf.inherited == false and
              f.category_id == ^category.id and
              uf.flag_id != ^flag_id,
          select: uf.id
        )
        |> Repo.all()

      Enum.each(other_flags, fn uf_id ->
        remove_user_flag(user, uf_id)
      end)

      :ok
    else
      :ok
    end
  end

  def find_existing_flag_in_category(user_id, flag_id, color) do
    flag = Repo.get!(Flag, flag_id) |> Repo.preload(:category)
    category = flag.category

    if Validations.single_select_enforced?(category.selection_mode, color) do
      from(uf in UserFlag,
        join: f in Flag,
        on: f.id == uf.flag_id,
        where:
          uf.user_id == ^user_id and
            uf.color == ^color and
            uf.inherited == false and
            f.category_id == ^category.id and
            uf.flag_id != ^flag_id,
        preload: [:flag]
      )
      |> Repo.one()
    else
      nil
    end
  end

  def list_user_flags(user, color) do
    from(uf in UserFlag,
      where: uf.user_id == ^user.id and uf.color == ^color and uf.inherited == false,
      order_by: uf.position,
      preload: [:flag]
    )
    |> Repo.all()
  end

  def list_all_user_flags(user) do
    from(uf in UserFlag,
      where: uf.user_id == ^user.id,
      order_by: uf.position,
      preload: [:flag]
    )
    |> Repo.all()
  end

  def count_user_flags(user) do
    from(uf in UserFlag, where: uf.user_id == ^user.id and uf.inherited == false)
    |> Repo.aggregate(:count)
  end

  def count_user_flags_by_color(user) do
    from(uf in UserFlag,
      where: uf.user_id == ^user.id and uf.inherited == false,
      group_by: uf.color,
      select: {uf.color, count(uf.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  def delete_all_user_flags(user, opts \\ []) do
    pt_opts = PT.opts(opts)

    flags =
      from(uf in UserFlag, where: uf.user_id == ^user.id)
      |> Repo.all()

    Enum.each(flags, fn flag ->
      PaperTrail.delete(flag, pt_opts)
    end)

    {:ok, length(flags)}
  end

  # --- Opt-ins ---

  def opt_into_category(user, category, opts \\ []) do
    case Repo.get_by(UserCategoryOptIn, user_id: user.id, category_id: category.id) do
      %UserCategoryOptIn{} = existing ->
        {:ok, existing}

      nil ->
        %UserCategoryOptIn{}
        |> UserCategoryOptIn.changeset(%{user_id: user.id, category_id: category.id})
        |> PaperTrail.insert(PT.opts(opts))
        |> PT.unwrap()
    end
  end

  def opt_out_of_category(user, category, opts \\ []) do
    pt_opts = PT.opts(opts)

    flag_ids =
      from(f in Flag, where: f.category_id == ^category.id, select: f.id)
      |> Repo.all()

    user_flags =
      from(uf in UserFlag,
        where: uf.user_id == ^user.id and uf.flag_id in ^flag_ids
      )
      |> Repo.all()

    Enum.each(user_flags, fn uf -> PaperTrail.delete(uf, pt_opts) end)

    case Repo.get_by(UserCategoryOptIn, user_id: user.id, category_id: category.id) do
      nil -> :ok
      opt_in -> PaperTrail.delete(opt_in, pt_opts)
    end

    {:ok, :opted_out}
  end

  def user_opted_into_category?(user, category) do
    from(o in UserCategoryOptIn,
      where: o.user_id == ^user.id and o.category_id == ^category.id
    )
    |> Repo.exists?()
  end

  # --- White Flag Category Publish ---

  @default_published_category_names ["Relationship Status", "What I'm Looking For", "Languages"]

  @doc """
  Returns the list of category names that are published by default.
  """
  def default_published_category_names, do: @default_published_category_names

  @doc """
  Ensures that default published categories have publish records for the user.
  Called on first visit to traits wizard to set up defaults for new users.
  """
  def ensure_default_published_categories(user, opts \\ []) do
    pt_opts = PT.opts(opts)

    default_category_ids =
      from(c in Category,
        where: c.name in ^@default_published_category_names,
        select: c.id
      )
      |> Repo.all()

    existing_published_ids = list_published_white_flag_category_ids(user)

    Enum.each(default_category_ids, fn category_id ->
      unless category_id in existing_published_ids do
        %UserWhiteFlagCategoryPublish{}
        |> UserWhiteFlagCategoryPublish.changeset(%{user_id: user.id, category_id: category_id})
        |> PaperTrail.insert(pt_opts)
      end
    end)

    :ok
  end

  @doc """
  Toggles the publish state for a user's white flags in a category.
  If published, removes the record. If not published, creates one.
  """
  def toggle_white_flag_category_publish(user, category, opts \\ []) do
    pt_opts = PT.opts(opts)

    result =
      case Repo.get_by(UserWhiteFlagCategoryPublish, user_id: user.id, category_id: category.id) do
        nil ->
          %UserWhiteFlagCategoryPublish{}
          |> UserWhiteFlagCategoryPublish.changeset(%{user_id: user.id, category_id: category.id})
          |> PaperTrail.insert(pt_opts)
          |> PT.unwrap()

        publish ->
          PaperTrail.delete(publish, pt_opts) |> PT.unwrap()
      end

    # Broadcast white flag changes (visibility changed)
    broadcast_white_flags_updated(user.id)

    result
  end

  @doc """
  Sets the publish state for a user's white flags in a category.
  If publish? is true, creates a record. If false, removes the record.
  Idempotent - calling with the same state multiple times has no effect.
  """
  def set_white_flag_category_publish(user, category, publish?, opts \\ [])

  def set_white_flag_category_publish(user, category, true, opts) do
    pt_opts = PT.opts(opts)

    case Repo.get_by(UserWhiteFlagCategoryPublish, user_id: user.id, category_id: category.id) do
      %UserWhiteFlagCategoryPublish{} = existing ->
        {:ok, existing}

      nil ->
        %UserWhiteFlagCategoryPublish{}
        |> UserWhiteFlagCategoryPublish.changeset(%{user_id: user.id, category_id: category.id})
        |> PaperTrail.insert(pt_opts)
        |> PT.unwrap()
    end
  end

  def set_white_flag_category_publish(user, category, false, opts) do
    pt_opts = PT.opts(opts)

    case Repo.get_by(UserWhiteFlagCategoryPublish, user_id: user.id, category_id: category.id) do
      nil ->
        {:ok, :already_unpublished}

      publish ->
        PaperTrail.delete(publish, pt_opts) |> PT.unwrap()
    end
  end

  @doc """
  Returns true if the user has published their white flags for the given category.
  """
  def white_flag_category_published?(user, category) do
    from(p in UserWhiteFlagCategoryPublish,
      where: p.user_id == ^user.id and p.category_id == ^category.id
    )
    |> Repo.exists?()
  end

  @doc """
  Returns a list of category IDs where the user has published their white flags.
  """
  def list_published_white_flag_category_ids(user) do
    from(p in UserWhiteFlagCategoryPublish, where: p.user_id == ^user.id, select: p.category_id)
    |> Repo.all()
  end

  @doc """
  Counts user flags by color, but only includes white flags from published categories.
  Green and red flags are always counted regardless of publish status.
  """
  def count_published_user_flags_by_color(user) do
    published_category_ids = list_published_white_flag_category_ids(user)

    # Count green and red flags (always shown)
    green_red_counts =
      from(uf in UserFlag,
        where: uf.user_id == ^user.id and uf.inherited == false and uf.color in ["green", "red"],
        group_by: uf.color,
        select: {uf.color, count(uf.id)}
      )
      |> Repo.all()

    # Count white flags only from published categories
    white_count =
      from(uf in UserFlag,
        join: f in Flag,
        on: f.id == uf.flag_id,
        where:
          uf.user_id == ^user.id and
            uf.inherited == false and
            uf.color == "white" and
            f.category_id in ^published_category_ids,
        select: count(uf.id)
      )
      |> Repo.one()

    counts = Map.new(green_red_counts)

    if white_count && white_count > 0 do
      Map.put(counts, "white", white_count)
    else
      counts
    end
  end

  @doc """
  Returns published white flags for a user (flags from published categories).
  Each flag includes the flag details (name, emoji) and category.
  """
  def list_published_white_flags(user) do
    published_category_ids = list_published_white_flag_category_ids(user)

    from(uf in UserFlag,
      join: f in Flag,
      on: f.id == uf.flag_id,
      join: c in Category,
      on: c.id == f.category_id,
      where:
        uf.user_id == ^user.id and
          uf.inherited == false and
          uf.color == "white" and
          f.category_id in ^published_category_ids,
      order_by: [c.position, uf.position],
      preload: [flag: {f, category: c}]
    )
    |> Repo.all()
  end

  @doc """
  Counts private (unpublished) white flags for a user.
  """
  def count_private_white_flags(user) do
    published_category_ids = list_published_white_flag_category_ids(user)

    from(uf in UserFlag,
      join: f in Flag,
      on: f.id == uf.flag_id,
      where:
        uf.user_id == ^user.id and
          uf.inherited == false and
          uf.color == "white" and
          f.category_id not in ^published_category_ids,
      select: count(uf.id)
    )
    |> Repo.one() || 0
  end

  @doc """
  Broadcasts white flag changes via PubSub.
  """
  def broadcast_white_flags_updated(user_id) do
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      "moodboard:#{user_id}",
      {:white_flags_updated, %{user_id: user_id}}
    )
  end

  # --- Delegations to Matching ---

  defdelegate compute_flag_overlap(user_a, user_b), to: Animina.Traits.Matching
end
