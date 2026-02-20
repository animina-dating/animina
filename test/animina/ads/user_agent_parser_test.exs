defmodule Animina.Ads.UserAgentParserTest do
  use ExUnit.Case, async: true

  alias Animina.Ads.UserAgentParser

  describe "parse/1" do
    test "parses Safari on macOS" do
      ua =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

      result = UserAgentParser.parse(ua)
      assert result.os == "macOS"
      assert result.browser == "Safari"
      assert result.device_type == "desktop"
      assert result.device_model == nil
      assert result.is_bot == false
    end

    test "parses Chrome on Windows" do
      ua =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

      result = UserAgentParser.parse(ua)
      assert result.os == "Windows"
      assert result.browser == "Chrome"
      assert result.device_type == "desktop"
      assert result.is_bot == false
    end

    test "parses Safari on iPhone" do
      ua =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

      result = UserAgentParser.parse(ua)
      assert result.os == "iOS"
      assert result.browser == "Safari"
      assert result.device_type == "mobile"
      assert result.device_model == "iPhone"
      assert result.is_bot == false
    end

    test "parses Chrome on Android phone" do
      ua =
        "Mozilla/5.0 (Linux; Android 14; SM-S928B Build/UP1A.231005.007) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.230 Mobile Safari/537.36"

      result = UserAgentParser.parse(ua)
      assert result.os == "Android"
      assert result.browser == "Chrome"
      assert result.device_type == "mobile"
      assert result.device_model == "SM-S928B"
      assert result.is_bot == false
    end

    test "parses Android tablet" do
      ua =
        "Mozilla/5.0 (Linux; Android 13; SM-X710 Build/TP1A.220624.014) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

      result = UserAgentParser.parse(ua)
      assert result.os == "Android"
      assert result.device_model == "SM-X710"
    end

    test "parses iPad" do
      ua =
        "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

      result = UserAgentParser.parse(ua)
      assert result.os == "iOS"
      assert result.device_type == "tablet"
      assert result.device_model == "iPad"
    end

    test "parses Samsung Internet" do
      ua =
        "Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/23.0 Chrome/115.0.0.0 Mobile Safari/537.36"

      result = UserAgentParser.parse(ua)
      assert result.browser == "Samsung Internet"
    end

    test "parses Edge" do
      ua =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"

      result = UserAgentParser.parse(ua)
      assert result.browser == "Edge"
    end

    test "parses Firefox" do
      ua = "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0"

      result = UserAgentParser.parse(ua)
      assert result.os == "Linux"
      assert result.browser == "Firefox"
      assert result.device_type == "desktop"
    end

    test "detects Googlebot" do
      ua =
        "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

      result = UserAgentParser.parse(ua)
      assert result.is_bot == true
    end

    test "detects Bingbot" do
      ua =
        "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)"

      result = UserAgentParser.parse(ua)
      assert result.is_bot == true
    end

    test "detects Facebook crawler" do
      ua = "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)"
      result = UserAgentParser.parse(ua)
      assert result.is_bot == true
    end

    test "handles nil user-agent" do
      result = UserAgentParser.parse(nil)
      assert result.os == "Other"
      assert result.browser == "Other"
      assert result.device_type == "desktop"
      assert result.is_bot == false
    end

    test "handles empty user-agent" do
      result = UserAgentParser.parse("")
      assert result.os == "Other"
      assert result.browser == "Other"
    end

    test "parses Pixel phone model" do
      ua =
        "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro Build/UQ1A.240205.004) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.6167.178 Mobile Safari/537.36"

      result = UserAgentParser.parse(ua)
      assert result.device_model == "Pixel 8 Pro"
    end
  end

  describe "parse_language/1" do
    test "extracts primary language from Accept-Language" do
      assert UserAgentParser.parse_language("de-DE,de;q=0.9,en;q=0.8") == "de"
      assert UserAgentParser.parse_language("en-US,en;q=0.5") == "en"
      assert UserAgentParser.parse_language("fr") == "fr"
    end

    test "handles nil" do
      assert UserAgentParser.parse_language(nil) == nil
    end

    test "handles empty string" do
      assert UserAgentParser.parse_language("") == nil
    end
  end
end
