defmodule Animina.Traits.Validations do
  @moduledoc """
  Validation functions for user flag operations.

  Handles single-select, exclusive-hard, and parent/child mixing rules.
  """

  import Ecto.Query

  alias Animina.Repo
  alias Animina.Traits.{Flag, UserFlag}

  @doc """
  Validates single-select category rules when adding a flag.
  Returns `:ok` or `{:error, changeset}`.
  """
  def validate_single_select(attrs) do
    with_flag_and_user(attrs, &do_validate_single_select(attrs, &1, &2))
  end

  defp do_validate_single_select(attrs, flag_id, user_id) do
    color = get_attr(attrs, :color)
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

  @doc """
  Returns true if single-select is enforced for the given mode and color.
  """
  def single_select_enforced?("single", _color), do: true
  def single_select_enforced?("single_white", "white"), do: true
  def single_select_enforced?(_mode, _color), do: false

  @doc """
  Validates exclusive-hard category rules when adding a flag.
  Returns `:ok` or `{:error, changeset}`.
  """
  def validate_exclusive_hard(attrs) do
    color = get_attr(attrs, :color)

    if color in ["white", "red"] do
      :ok
    else
      with_flag_and_user(attrs, &do_validate_exclusive_hard(attrs, &1, &2, color))
    end
  end

  defp do_validate_exclusive_hard(attrs, flag_id, user_id, color) do
    intensity = get_attr(attrs, :intensity)
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

  @doc """
  Validates that parent and child flags are not mixed when adding a flag.
  Returns `:ok` or `{:error, changeset}`.
  """
  def validate_no_mixing(attrs) do
    with_flag_and_user(attrs, &do_validate_no_mixing(attrs, &1, &2))
  end

  defp do_validate_no_mixing(attrs, flag_id, user_id) do
    color = get_attr(attrs, :color)
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

  @doc """
  Validates exclusive-hard rules when updating a flag's intensity.
  Returns `:ok` or `{:error, changeset}`.
  """
  def validate_exclusive_hard_update(user_flag, new_intensity) do
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

  # Attribute extraction helpers that handle both atom and string keys

  defp get_attr(attrs, key), do: attrs[key] || attrs[Atom.to_string(key)]

  defp with_flag_and_user(attrs, fun) do
    flag_id = get_attr(attrs, :flag_id)
    user_id = get_attr(attrs, :user_id)

    if flag_id && user_id do
      fun.(flag_id, user_id)
    else
      :ok
    end
  end
end
