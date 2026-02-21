defmodule Animina.Traits.Matching do
  @moduledoc """
  Flag matching and overlap computation for user compatibility.
  """

  import Ecto.Query

  alias Animina.Repo
  alias Animina.Traits
  alias Animina.Traits.Category

  @doc """
  Computes the flag overlap between two users for matching.

  Returns a map with:
  - `:white_white` - Shared traits (both users have as white)
  - `:green_white` - Desired traits that match (one's green matches other's white)
  - `:green_white_hard` - Hard green-white matches
  - `:green_white_soft` - Soft green-white matches
  - `:red_white` - Deal-breakers that match (one's red matches other's white)
  - `:red_white_hard` - Hard red-white matches
  - `:red_white_soft` - Soft red-white matches
  """
  def compute_flag_overlap(user_a, user_b) do
    a_flags = Traits.list_all_user_flags(user_a)
    b_flags = Traits.list_all_user_flags(user_b)

    a_opted = Traits.list_user_optin_category_ids(user_a)
    b_opted = Traits.list_user_optin_category_ids(user_b)

    sensitive_ids = list_sensitive_category_ids()

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

    white_white = MapSet.intersection(a_white_ids, b_white_ids) |> MapSet.to_list()

    green_white_ba = MapSet.intersection(b_green_ids, a_white_ids) |> MapSet.to_list()
    green_white_ab = MapSet.intersection(a_green_ids, b_white_ids) |> MapSet.to_list()
    green_white = Enum.uniq(green_white_ba ++ green_white_ab)

    red_white_ba = MapSet.intersection(b_red_ids, a_white_ids) |> MapSet.to_list()
    red_white_ab = MapSet.intersection(a_red_ids, b_white_ids) |> MapSet.to_list()
    red_white = Enum.uniq(red_white_ba ++ red_white_ab)

    green_intensity =
      build_intensity_map(a_by_color["green"])
      |> Map.merge(build_intensity_map(b_by_color["green"]), fn _k, v1, v2 ->
        if v1 == "hard" || v2 == "hard", do: "hard", else: "soft"
      end)

    red_intensity =
      build_intensity_map(a_by_color["red"])
      |> Map.merge(build_intensity_map(b_by_color["red"]), fn _k, v1, v2 ->
        if v1 == "hard" || v2 == "hard", do: "hard", else: "soft"
      end)

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

  defp list_sensitive_category_ids do
    from(c in Category, where: c.sensitive == true, select: c.id)
    |> Repo.all()
  end

  defp filter_sensitive(user_flags, sensitive_ids, mutual_sensitive) do
    sensitive_set = MapSet.new(sensitive_ids)

    Enum.filter(user_flags, fn uf ->
      case uf.flag do
        %{category_id: category_id} ->
          not MapSet.member?(sensitive_set, category_id) or
            MapSet.member?(mutual_sensitive, category_id)

        _ ->
          false
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
