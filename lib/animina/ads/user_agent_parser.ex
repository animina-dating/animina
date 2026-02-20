defmodule Animina.Ads.UserAgentParser do
  @moduledoc """
  Lightweight regex-based user-agent parser for ad visit tracking.
  No external dependencies.
  """

  @bot_patterns ~w(bot crawler spider googlebot bingbot facebookexternalhit slurp
                    duckduckbot baiduspider yandexbot sogou exabot ia_archiver
                    ahrefsbot semrushbot dotbot mj12bot rogerbot)

  @doc """
  Parses a user-agent string into structured data.

  Returns a map with `:os`, `:browser`, `:device_type`, `:device_model`, and `:is_bot`.
  """
  def parse(nil),
    do: %{os: "Other", browser: "Other", device_type: "desktop", device_model: nil, is_bot: false}

  def parse(""),
    do: %{os: "Other", browser: "Other", device_type: "desktop", device_model: nil, is_bot: false}

  def parse(ua) when is_binary(ua) do
    is_bot = bot?(ua)
    os = detect_os(ua)
    browser = detect_browser(ua)
    device_type = detect_device_type(ua)
    device_model = detect_device_model(ua, os)

    %{
      os: os,
      browser: browser,
      device_type: device_type,
      device_model: device_model,
      is_bot: is_bot
    }
  end

  @doc """
  Parses the Accept-Language header and returns the primary language tag.

  ## Examples

      iex> Animina.Ads.UserAgentParser.parse_language("de-DE,de;q=0.9,en;q=0.8")
      "de"

      iex> Animina.Ads.UserAgentParser.parse_language("en-US,en;q=0.5")
      "en"
  """
  def parse_language(nil), do: nil
  def parse_language(""), do: nil

  def parse_language(accept_language) when is_binary(accept_language) do
    accept_language
    |> String.split(",")
    |> List.first("")
    |> String.split(";")
    |> List.first("")
    |> String.split("-")
    |> List.first()
    |> String.trim()
    |> case do
      "" -> nil
      lang -> String.downcase(lang)
    end
  end

  # --- OS Detection ---

  @os_patterns [
    {["iphone", "ipad", "ipod"], "iOS"},
    {["android"], "Android"},
    {["cros"], "ChromeOS"},
    {["macintosh", "mac os x"], "macOS"},
    {["windows"], "Windows"},
    {["linux"], "Linux"}
  ]

  defp detect_os(ua) do
    ua_lower = String.downcase(ua)
    match_first(@os_patterns, ua_lower, "Other")
  end

  # --- Browser Detection ---

  # Order matters — more specific patterns first to avoid false positives.
  # Samsung Internet and Edge include "chrome" / "safari" in their UA strings.
  @browser_patterns [
    {["samsungbrowser"], "Samsung Internet"},
    {["edg/", "edge/"], "Edge"},
    {["opr/", "opera"], "Opera"},
    {["firefox"], "Firefox"}
  ]

  defp detect_browser(ua) do
    ua_lower = String.downcase(ua)

    match_first(@browser_patterns, ua_lower, nil) ||
      detect_chrome_or_safari(ua_lower) ||
      "Other"
  end

  defp detect_chrome_or_safari(ua) do
    has_chrome = String.contains?(ua, "chrome")

    cond do
      has_chrome and not String.contains?(ua, "chromium") -> "Chrome"
      not has_chrome and String.contains?(ua, "safari") -> "Safari"
      true -> nil
    end
  end

  defp match_first([], _ua, default), do: default

  defp match_first([{tokens, result} | rest], ua, default) do
    if Enum.any?(tokens, &String.contains?(ua, &1)) do
      result
    else
      match_first(rest, ua, default)
    end
  end

  # --- Device Type Detection ---

  defp detect_device_type(ua) do
    ua_lower = String.downcase(ua)

    cond do
      String.contains?(ua_lower, "ipad") or String.contains?(ua_lower, "tablet") ->
        "tablet"

      String.contains?(ua_lower, "mobile") or String.contains?(ua_lower, "iphone") or
          String.contains?(ua_lower, "android") ->
        if String.contains?(ua_lower, "tablet"), do: "tablet", else: "mobile"

      true ->
        "desktop"
    end
  end

  # --- Device Model Detection ---

  defp detect_device_model(ua, "iOS") do
    cond do
      String.contains?(ua, "iPad") -> "iPad"
      String.contains?(ua, "iPod") -> "iPod"
      String.contains?(ua, "iPhone") -> "iPhone"
      true -> nil
    end
  end

  defp detect_device_model(ua, "Android") do
    # Android UA pattern: "Android X.Y; MODEL Build/" or "Android X.Y; MODEL)"
    case Regex.run(~r/Android\s+[\d.]+;\s*([^;)]+?)(?:\s+Build\/|\))/, ua) do
      [_, model] -> String.trim(model)
      _ -> nil
    end
  end

  defp detect_device_model(_ua, _os), do: nil

  # --- Bot Detection ---

  defp bot?(ua) do
    ua_lower = String.downcase(ua)
    Enum.any?(@bot_patterns, &String.contains?(ua_lower, &1))
  end
end
