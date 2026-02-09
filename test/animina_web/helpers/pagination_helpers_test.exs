defmodule AniminaWeb.Helpers.PaginationHelpersTest do
  use ExUnit.Case, async: true

  alias AniminaWeb.Helpers.PaginationHelpers

  describe "visible_pages/2" do
    test "returns all pages when total <= 7" do
      assert PaginationHelpers.visible_pages(1, 1) == [1]
      assert PaginationHelpers.visible_pages(1, 5) == [1, 2, 3, 4, 5]
      assert PaginationHelpers.visible_pages(3, 7) == [1, 2, 3, 4, 5, 6, 7]
    end

    test "adds gap at the beginning when current page is far from start" do
      result = PaginationHelpers.visible_pages(6, 10)
      assert :gap in result
      assert hd(result) == 1
      assert List.last(result) == 10
    end

    test "adds gap at the end when current page is far from end" do
      result = PaginationHelpers.visible_pages(2, 10)
      assert List.last(result) == 10
      assert Enum.any?(result, &(&1 == :gap))
    end

    test "shows correct pages for middle navigation" do
      result = PaginationHelpers.visible_pages(5, 10)
      assert hd(result) == 1
      assert List.last(result) == 10
      assert 5 in result
      assert 4 in result
      assert 6 in result
      assert :gap in result
    end

    test "no gap when near start" do
      result = PaginationHelpers.visible_pages(2, 10)
      assert hd(result) == 1
      refute Enum.at(result, 1) == :gap
    end

    test "no gap when near end" do
      result = PaginationHelpers.visible_pages(9, 10)
      assert List.last(result) == 10
      refute Enum.at(result, -2) == :gap
    end
  end

  describe "parse_sort_dir/1" do
    test "parses asc" do
      assert PaginationHelpers.parse_sort_dir("asc") == :asc
    end

    test "defaults to desc" do
      assert PaginationHelpers.parse_sort_dir("desc") == :desc
      assert PaginationHelpers.parse_sort_dir(nil) == :desc
      assert PaginationHelpers.parse_sort_dir("invalid") == :desc
    end
  end

  describe "maybe_put/3" do
    test "adds value to map" do
      assert PaginationHelpers.maybe_put(%{a: 1}, :b, "hello") == %{a: 1, b: "hello"}
    end

    test "skips nil values" do
      assert PaginationHelpers.maybe_put(%{a: 1}, :b, nil) == %{a: 1}
    end

    test "skips empty string values" do
      assert PaginationHelpers.maybe_put(%{a: 1}, :b, "") == %{a: 1}
    end
  end

  describe "relative_time/1" do
    test "returns empty string for nil" do
      assert PaginationHelpers.relative_time(nil) == ""
    end

    test "returns seconds ago for recent times" do
      datetime = DateTime.add(DateTime.utc_now(), -30, :second)
      result = PaginationHelpers.relative_time(datetime)
      assert result =~ ~r/\d+s ago/
    end

    test "returns minutes ago" do
      datetime = DateTime.add(DateTime.utc_now(), -300, :second)
      result = PaginationHelpers.relative_time(datetime)
      assert result =~ ~r/\d+m ago/
    end

    test "returns hours ago" do
      datetime = DateTime.add(DateTime.utc_now(), -7200, :second)
      result = PaginationHelpers.relative_time(datetime)
      assert result =~ ~r/\d+h ago/
    end

    test "returns days ago" do
      datetime = DateTime.add(DateTime.utc_now(), -172_800, :second)
      result = PaginationHelpers.relative_time(datetime)
      assert result =~ ~r/\d+d ago/
    end
  end
end
