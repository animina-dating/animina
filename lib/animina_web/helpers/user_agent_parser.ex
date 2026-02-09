defmodule AniminaWeb.Helpers.UserAgentParser do
  @moduledoc """
  Simple User-Agent string parser. Extracts browser, OS, and device type
  using pattern matching. No external dependency needed.
  """

  @doc """
  Parses a User-Agent string into a map with :browser, :os, and :device_type.

  Returns `%{browser: "Chrome", os: "Windows", device_type: :desktop}` etc.
  """
  def parse(nil), do: %{browser: "Unknown", os: "Unknown", device_type: :unknown}
  def parse(""), do: %{browser: "Unknown", os: "Unknown", device_type: :unknown}

  def parse(ua) when is_binary(ua) do
    %{
      browser: detect_browser(ua),
      os: detect_os(ua),
      device_type: detect_device_type(ua)
    }
  end

  @browser_patterns [
    {~r/Edg[e\/]/, "Edge"},
    {~r/OPR\/|Opera/, "Opera"},
    {~r/Vivaldi/, "Vivaldi"},
    {~r/Brave/, "Brave"},
    {~r/Chrome\/|CriOS/, "Chrome"},
    {~r/Firefox\/|FxiOS/, "Firefox"},
    {~r/MSIE|Trident/, "Internet Explorer"}
  ]

  defp detect_browser(ua) do
    case Enum.find(@browser_patterns, fn {regex, _} -> ua =~ regex end) do
      {_, name} -> name
      nil -> if ua =~ ~r/Safari\// and not (ua =~ ~r/Chrome/), do: "Safari", else: "Unknown"
    end
  end

  defp detect_os(ua) do
    cond do
      ua =~ ~r/iPhone|iPad|iPod/ -> "iOS"
      ua =~ ~r/Android/ -> "Android"
      ua =~ ~r/Windows NT/ -> "Windows"
      ua =~ ~r/Mac OS X|Macintosh/ -> "macOS"
      ua =~ ~r/Linux/ -> "Linux"
      ua =~ ~r/CrOS/ -> "ChromeOS"
      true -> "Unknown"
    end
  end

  defp detect_device_type(ua) do
    cond do
      ua =~ ~r/iPhone|iPod|Android.*Mobile|Mobile/ -> :mobile
      ua =~ ~r/iPad|Android(?!.*Mobile)|Tablet/ -> :tablet
      true -> :desktop
    end
  end

  @doc """
  Returns a human-friendly summary string like "Chrome on Windows".
  """
  def summary(ua) do
    %{browser: browser, os: os} = parse(ua)
    "#{browser} on #{os}"
  end

  @doc """
  Returns an icon name based on the device type.
  """
  def device_icon(ua) do
    case parse(ua).device_type do
      :mobile -> "hero-device-phone-mobile"
      :tablet -> "hero-device-tablet"
      :desktop -> "hero-computer-desktop"
      _ -> "hero-globe-alt"
    end
  end
end
