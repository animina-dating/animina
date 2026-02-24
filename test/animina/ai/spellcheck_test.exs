defmodule Animina.AI.JobTypes.SpellCheckTest do
  use ExUnit.Case, async: true

  alias Animina.AI.JobTypes.SpellCheck

  describe "parse_response/1" do
    test "extracts text from valid JSON" do
      assert SpellCheck.parse_response(~s({"text": "Hello world"})) == "Hello world"
    end

    test "handles JSON with think tags" do
      input = "<think>reasoning here</think>{\"text\": \"corrected\"}"
      assert SpellCheck.parse_response(input) == "corrected"
    end

    test "handles plain text response" do
      assert SpellCheck.parse_response("Just plain text") == "Just plain text"
    end

    test "strips surrounding quotes" do
      assert SpellCheck.parse_response(~s("quoted text")) == "quoted text"
    end

    test "returns nil for empty response" do
      assert SpellCheck.parse_response("") == nil
    end

    test "returns nil for nil response" do
      assert SpellCheck.parse_response(nil) == nil
    end

    test "trims whitespace from JSON text value" do
      assert SpellCheck.parse_response(~s({"text": "  trimmed  "})) == "trimmed"
    end

    test "handles incomplete think tags" do
      input = "<think>still thinking..."
      result = SpellCheck.parse_response(input)
      assert result == nil || result == ""
    end

    test "extracts JSON from end of response with preceding text" do
      input = "Here is the correction:\n{\"text\": \"fixed text\"}"
      assert SpellCheck.parse_response(input) == "fixed text"
    end
  end
end
