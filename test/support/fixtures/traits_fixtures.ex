defmodule Animina.TraitsFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Animina.Traits` context.
  """

  alias Animina.Traits

  def category_fixture(attrs \\ %{}) do
    {:ok, category} =
      attrs
      |> Enum.into(%{
        name: "Category #{System.unique_integer([:positive])}",
        selection_mode: "multi",
        sensitive: false,
        position: System.unique_integer([:positive])
      })
      |> Traits.create_category()

    category
  end

  def sensitive_category_fixture(attrs \\ %{}) do
    category_fixture(Map.merge(%{sensitive: true}, attrs))
  end

  def single_select_category_fixture(attrs \\ %{}) do
    category_fixture(Map.merge(%{selection_mode: "single"}, attrs))
  end

  def single_white_category_fixture(attrs \\ %{}) do
    category_fixture(Map.merge(%{selection_mode: "single_white"}, attrs))
  end

  def exclusive_hard_category_fixture(attrs \\ %{}) do
    category_fixture(Map.merge(%{selection_mode: "multi", exclusive_hard: true}, attrs))
  end

  def core_category_fixture(attrs \\ %{}) do
    category_fixture(Map.merge(%{core: true}, attrs))
  end

  def optin_category_fixture(attrs \\ %{}) do
    category_fixture(Map.merge(%{core: false, picker_group: "lifestyle"}, attrs))
  end

  def flag_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        name: "Flag #{System.unique_integer([:positive])}",
        emoji: "🏷️",
        position: System.unique_integer([:positive])
      })

    attrs =
      if Map.has_key?(attrs, :category_id) do
        attrs
      else
        category = category_fixture()
        Map.put(attrs, :category_id, category.id)
      end

    {:ok, flag} = Traits.create_flag(attrs)
    flag
  end

  def flag_with_children_fixture(attrs \\ %{}) do
    parent = flag_fixture(attrs)

    children =
      for i <- 1..3 do
        {:ok, child} =
          Traits.create_flag(%{
            name: "#{parent.name} Child #{i}",
            emoji: parent.emoji,
            category_id: parent.category_id,
            parent_id: parent.id,
            position: i
          })

        child
      end

    {parent, children}
  end
end
