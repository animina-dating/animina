defmodule Animina.Traits do
  @moduledoc """
  Context for personality traits: categories, flags, user flags, opt-ins, and matching.
  """

  import Ecto.Query

  alias Animina.Repo
  alias Animina.Traits.{Category, Flag, UserCategoryOptIn, UserFlag}

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

  def toggle_category_optin(user, category) do
    case Repo.get_by(UserCategoryOptIn, user_id: user.id, category_id: category.id) do
      nil ->
        %UserCategoryOptIn{}
        |> UserCategoryOptIn.changeset(%{user_id: user.id, category_id: category.id})
        |> Repo.insert()

      opt_in ->
        Repo.delete(opt_in)
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

  def add_user_flag(attrs) do
    changeset = UserFlag.changeset(%UserFlag{}, attrs)

    with :ok <- validate_single_select(attrs),
         :ok <- validate_exclusive_hard(attrs),
         :ok <- validate_no_mixing(attrs) do
      with {:ok, user_flag} <- Repo.insert(changeset) do
        expand_on_write(user_flag)
        {:ok, user_flag}
      end
    end
  end

  defp validate_single_select(attrs) do
    flag_id = attrs[:flag_id] || attrs["flag_id"]
    user_id = attrs[:user_id] || attrs["user_id"]

    if flag_id && user_id do
      do_validate_single_select(attrs, flag_id, user_id)
    else
      :ok
    end
  end

  defp do_validate_single_select(attrs, flag_id, user_id) do
    color = attrs[:color] || attrs["color"]
    flag = Repo.get!(Flag, flag_id) |> Repo.preload(:category)
    category = flag.category

    if single_select_enforced?(category.selection_mode, color) do
      check_single_select_count(attrs, user_id, color, category)
    else
      :ok
    end
  end

  defp check_single_select_count(attrs, user_id, color, category) do
    existing_count =
      from(uf in UserFlag,
        join: f in Flag,
        on: f.id == uf.flag_id,
        where:
          uf.user_id == ^user_id and
            uf.color == ^color and
            uf.inherited == false and
            f.category_id == ^category.id
      )
      |> Repo.aggregate(:count)

    if existing_count > 0 do
      changeset =
        UserFlag.changeset(%UserFlag{}, attrs)
        |> Ecto.Changeset.add_error(
          :flag_id,
          "single-select category allows only one flag per color"
        )

      {:error, changeset}
    else
      :ok
    end
  end

  defp single_select_enforced?("single", _color), do: true
  defp single_select_enforced?("single_white", "white"), do: true
  defp single_select_enforced?(_mode, _color), do: false

  defp validate_exclusive_hard(attrs) do
    color = attrs[:color] || attrs["color"]

    if color in ["white", "red"] do
      :ok
    else
      flag_id = attrs[:flag_id] || attrs["flag_id"]
      user_id = attrs[:user_id] || attrs["user_id"]

      if flag_id && user_id do
        do_validate_exclusive_hard(attrs, flag_id, user_id, color)
      else
        :ok
      end
    end
  end

  defp do_validate_exclusive_hard(attrs, flag_id, user_id, color) do
    intensity = attrs[:intensity] || attrs["intensity"]
    flag = Repo.get!(Flag, flag_id) |> Repo.preload(:category)

    if flag.category.exclusive_hard do
      check_exclusive_hard_add(attrs, user_id, color, flag.category.id, intensity)
    else
      :ok
    end
  end

  defp check_exclusive_hard_add(attrs, user_id, color, category_id, "hard") do
    if count_non_inherited_in_category(user_id, color, category_id) > 0 do
      exclusive_hard_error(attrs, "cannot add hard flag when other flags exist")
    else
      :ok
    end
  end

  defp check_exclusive_hard_add(attrs, user_id, color, category_id, "soft") do
    if has_hard_in_category?(user_id, color, category_id) do
      exclusive_hard_error(attrs, "cannot add soft flag when hard flag exists")
    else
      :ok
    end
  end

  defp check_exclusive_hard_add(_attrs, _user_id, _color, _category_id, _intensity), do: :ok

  defp count_non_inherited_in_category(user_id, color, category_id) do
    from(uf in UserFlag,
      join: f in Flag,
      on: f.id == uf.flag_id,
      where:
        uf.user_id == ^user_id and
          uf.color == ^color and
          uf.inherited == false and
          f.category_id == ^category_id
    )
    |> Repo.aggregate(:count)
  end

  defp has_hard_in_category?(user_id, color, category_id) do
    from(uf in UserFlag,
      join: f in Flag,
      on: f.id == uf.flag_id,
      where:
        uf.user_id == ^user_id and
          uf.color == ^color and
          uf.inherited == false and
          uf.intensity == "hard" and
          f.category_id == ^category_id
    )
    |> Repo.exists?()
  end

  defp exclusive_hard_error(attrs, message) do
    changeset =
      UserFlag.changeset(%UserFlag{}, attrs)
      |> Ecto.Changeset.add_error(:flag_id, "exclusive hard category: " <> message)

    {:error, changeset}
  end

  defp validate_no_mixing(attrs) do
    flag_id = attrs[:flag_id] || attrs["flag_id"]
    user_id = attrs[:user_id] || attrs["user_id"]

    if flag_id && user_id do
      do_validate_no_mixing(attrs, flag_id, user_id)
    else
      :ok
    end
  end

  defp do_validate_no_mixing(attrs, flag_id, user_id) do
    color = attrs[:color] || attrs["color"]
    flag = Repo.get!(Flag, flag_id) |> Repo.preload(:children)

    cond do
      flag.children != [] ->
        check_no_children_selected(attrs, flag, user_id, color)

      flag.parent_id != nil ->
        check_no_parent_selected(attrs, flag, user_id, color)

      true ->
        :ok
    end
  end

  defp check_no_children_selected(attrs, flag, user_id, color) do
    child_ids = Enum.map(flag.children, & &1.id)

    existing =
      from(uf in UserFlag,
        where:
          uf.user_id == ^user_id and
            uf.color == ^color and
            uf.inherited == false and
            uf.flag_id in ^child_ids
      )
      |> Repo.aggregate(:count)

    if existing > 0 do
      changeset =
        UserFlag.changeset(%UserFlag{}, attrs)
        |> Ecto.Changeset.add_error(
          :flag_id,
          "cannot select parent when children are already selected"
        )

      {:error, changeset}
    else
      :ok
    end
  end

  defp check_no_parent_selected(attrs, flag, user_id, color) do
    existing =
      from(uf in UserFlag,
        where:
          uf.user_id == ^user_id and
            uf.color == ^color and
            uf.inherited == false and
            uf.flag_id == ^flag.parent_id
      )
      |> Repo.aggregate(:count)

    if existing > 0 do
      changeset =
        UserFlag.changeset(%UserFlag{}, attrs)
        |> Ecto.Changeset.add_error(
          :flag_id,
          "cannot select child when parent is already selected"
        )

      {:error, changeset}
    else
      :ok
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

  def update_user_flag_intensity(user_flag_id, new_intensity) do
    user_flag = Repo.get!(UserFlag, user_flag_id)

    with :ok <- validate_exclusive_hard_update(user_flag, new_intensity) do
      with {:ok, updated} <-
             user_flag
             |> UserFlag.changeset(%{intensity: new_intensity})
             |> Repo.update() do
        from(uf in UserFlag,
          where: uf.user_id == ^updated.user_id and uf.source_flag_id == ^updated.flag_id
        )
        |> Repo.update_all(set: [intensity: new_intensity])

        {:ok, updated}
      end
    end
  end

  defp validate_exclusive_hard_update(user_flag, new_intensity) do
    if new_intensity == "hard" && user_flag.color not in ["white", "red"] do
      check_exclusive_hard_promotion(user_flag, new_intensity)
    else
      :ok
    end
  end

  defp check_exclusive_hard_promotion(user_flag, new_intensity) do
    flag = Repo.get!(Flag, user_flag.flag_id) |> Repo.preload(:category)
    category = flag.category

    if category.exclusive_hard && count_others_in_category(user_flag, category) > 0 do
      changeset =
        user_flag
        |> UserFlag.changeset(%{intensity: new_intensity})
        |> Ecto.Changeset.add_error(
          :flag_id,
          "exclusive hard category: cannot promote to hard when other flags exist"
        )

      {:error, changeset}
    else
      :ok
    end
  end

  defp count_others_in_category(user_flag, category) do
    from(uf in UserFlag,
      join: f in Flag,
      on: f.id == uf.flag_id,
      where:
        uf.user_id == ^user_flag.user_id and
          uf.color == ^user_flag.color and
          uf.inherited == false and
          f.category_id == ^category.id and
          uf.id != ^user_flag.id
    )
    |> Repo.aggregate(:count)
  end

  def remove_user_flag(user, user_flag_id) do
    case Repo.get_by(UserFlag, id: user_flag_id, user_id: user.id) do
      nil ->
        {:ok, :already_removed}

      user_flag ->
        # Remove inherited entries spawned by this flag
        from(uf in UserFlag,
          where: uf.user_id == ^user.id and uf.source_flag_id == ^user_flag.flag_id
        )
        |> Repo.delete_all()

        Repo.delete(user_flag)
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

    if single_select_enforced?(category.selection_mode, color) do
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

  def delete_all_user_flags(user) do
    {count, _} =
      from(uf in UserFlag, where: uf.user_id == ^user.id)
      |> Repo.delete_all()

    {:ok, count}
  end

  # --- Opt-ins ---

  def opt_into_category(user, category) do
    %UserCategoryOptIn{}
    |> UserCategoryOptIn.changeset(%{user_id: user.id, category_id: category.id})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id, :category_id])
  end

  def opt_out_of_category(user, category) do
    # Remove all user flags in this category
    flag_ids =
      from(f in Flag, where: f.category_id == ^category.id, select: f.id)
      |> Repo.all()

    from(uf in UserFlag,
      where: uf.user_id == ^user.id and uf.flag_id in ^flag_ids
    )
    |> Repo.delete_all()

    # Remove opt-in record
    from(o in UserCategoryOptIn,
      where: o.user_id == ^user.id and o.category_id == ^category.id
    )
    |> Repo.delete_all()

    {:ok, :opted_out}
  end

  def user_opted_into_category?(user, category) do
    from(o in UserCategoryOptIn,
      where: o.user_id == ^user.id and o.category_id == ^category.id
    )
    |> Repo.exists?()
  end

  # --- Matching ---

  def compute_flag_overlap(user_a, user_b) do
    # Get all flags for both users (including inherited, for matching)
    a_flags = list_all_user_flags(user_a)
    b_flags = list_all_user_flags(user_b)

    # Get sensitive categories each user has opted into
    a_opted = list_user_opt_in_category_ids(user_a)
    b_opted = list_user_opt_in_category_ids(user_b)

    # Get sensitive category IDs
    sensitive_ids = list_sensitive_category_ids()

    # Filter out sensitive flags where both users haven't opted in
    mutual_sensitive = MapSet.intersection(MapSet.new(a_opted), MapSet.new(b_opted))

    a_flags = filter_sensitive(a_flags, sensitive_ids, mutual_sensitive)
    b_flags = filter_sensitive(b_flags, sensitive_ids, mutual_sensitive)

    a_by_color = group_by_color(a_flags)
    b_by_color = group_by_color(b_flags)

    a_white_ids = flag_ids(a_by_color["white"])
    b_white_ids = flag_ids(b_by_color["white"])
    a_green_ids = flag_ids(a_by_color["green"])
    b_green_ids = flag_ids(b_by_color["green"])
    a_red_ids = flag_ids(a_by_color["red"])
    b_red_ids = flag_ids(b_by_color["red"])

    # White-white: shared traits (bidirectional)
    white_white = MapSet.intersection(a_white_ids, b_white_ids) |> MapSet.to_list()

    # Green-white: B's green matches A's white OR A's green matches B's white
    green_white_ba = MapSet.intersection(b_green_ids, a_white_ids) |> MapSet.to_list()
    green_white_ab = MapSet.intersection(a_green_ids, b_white_ids) |> MapSet.to_list()
    green_white = Enum.uniq(green_white_ba ++ green_white_ab)

    # Red-white: B's red matches A's white OR A's red matches B's white
    red_white_ba = MapSet.intersection(b_red_ids, a_white_ids) |> MapSet.to_list()
    red_white_ab = MapSet.intersection(a_red_ids, b_white_ids) |> MapSet.to_list()
    red_white = Enum.uniq(red_white_ba ++ red_white_ab)

    # Build intensity lookup for green and red flags (from both users)
    green_intensity =
      build_intensity_map(a_by_color["green"])
      |> Map.merge(build_intensity_map(b_by_color["green"]))

    red_intensity =
      build_intensity_map(a_by_color["red"]) |> Map.merge(build_intensity_map(b_by_color["red"]))

    {green_white_hard, green_white_soft} = split_by_intensity(green_white, green_intensity)
    {red_white_hard, red_white_soft} = split_by_intensity(red_white, red_intensity)

    %{
      white_white: white_white,
      green_white: green_white,
      green_white_hard: green_white_hard,
      green_white_soft: green_white_soft,
      red_white: red_white,
      red_white_hard: red_white_hard,
      red_white_soft: red_white_soft
    }
  end

  defp list_user_opt_in_category_ids(user) do
    from(o in UserCategoryOptIn, where: o.user_id == ^user.id, select: o.category_id)
    |> Repo.all()
  end

  defp list_sensitive_category_ids do
    from(c in Category, where: c.sensitive == true, select: c.id)
    |> Repo.all()
  end

  defp filter_sensitive(user_flags, sensitive_ids, mutual_sensitive) do
    sensitive_set = MapSet.new(sensitive_ids)

    Enum.filter(user_flags, fn uf ->
      flag = uf.flag
      category_id = flag.category_id

      if MapSet.member?(sensitive_set, category_id) do
        MapSet.member?(mutual_sensitive, category_id)
      else
        true
      end
    end)
  end

  defp group_by_color(flags), do: Enum.group_by(flags, & &1.color)

  defp flag_ids(nil), do: MapSet.new()
  defp flag_ids(flags), do: flags |> Enum.map(& &1.flag_id) |> MapSet.new()

  defp build_intensity_map(nil), do: %{}
  defp build_intensity_map(flags), do: Map.new(flags, &{&1.flag_id, &1.intensity})

  defp split_by_intensity(flag_ids, intensity_map) do
    Enum.split_with(flag_ids, fn id -> Map.get(intensity_map, id, "hard") == "hard" end)
  end
end
