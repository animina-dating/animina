defmodule Animina.Traits do
  @moduledoc """
  Context for personality traits: categories, flags, user flags, opt-ins, and matching.

  This module acts as a facade, delegating to specialized sub-modules:
  - `Animina.Traits.Matching` - Flag overlap computation for user compatibility
  - `Animina.Traits.Validations` - Single-select, exclusive-hard, and mixing validations
  """

  import Ecto.Query

  alias Animina.Repo
  alias Animina.Traits.{Category, Flag, UserCategoryOptIn, UserFlag}
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
         :ok <- Validations.validate_no_mixing(attrs) do
      with {:ok, user_flag} <- PaperTrail.insert(changeset, pt_opts) |> PT.unwrap() do
        expand_on_write(user_flag)
        {:ok, user_flag}
      end
    end
  end

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
        from(uf in UserFlag,
          where: uf.user_id == ^user.id and uf.source_flag_id == ^user_flag.flag_id
        )
        |> Repo.delete_all()

        PaperTrail.delete(user_flag, pt_opts) |> PT.unwrap()
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

  # --- Delegations to Matching ---

  defdelegate compute_flag_overlap(user_a, user_b), to: Animina.Traits.Matching
end
