defmodule Animina.AI.SpellCheckTest do
  use ExUnit.Case, async: true

  alias Animina.AI.SpellCheck

  describe "build_system_prompt/1" do
    test "includes correction instructions" do
      prompt = SpellCheck.build_system_prompt()
      assert prompt =~ "spelling"
      assert prompt =~ "grammar"
    end

    test "requests JSON output format" do
      prompt = SpellCheck.build_system_prompt()
      assert prompt =~ ~s["text"]
      assert prompt =~ "JSON"
    end

    test "includes age and gender context when provided" do
      prompt = SpellCheck.build_system_prompt(age: 25, gender: "female")
      assert prompt =~ "25-year-old female"
    end

    test "works without age and gender" do
      prompt = SpellCheck.build_system_prompt([])
      refute prompt =~ "writer"
    end
  end

  describe "parse_response/2 — JSON extraction (primary)" do
    test "extracts text from clean JSON response" do
      response = ~s|{"text": "Hello world"}|
      assert SpellCheck.parse_response(response, "Helo wrold") == "Hello world"
    end

    test "extracts text from JSON with extra whitespace" do
      response = ~s|  {"text": "Hello world"}  |
      assert SpellCheck.parse_response(response, "Helo wrold") == "Hello world"
    end

    test "extracts text from JSON after think tags" do
      response = ~s|<think>\nLet me check...\n</think>\n{"text": "Hello world"}|
      assert SpellCheck.parse_response(response, "Helo wrold") == "Hello world"
    end

    test "extracts text from JSON after untagged thinking" do
      response =
        "Okay, let me check this text...\nThe corrections are:\n" <>
          ~s|{"text": "Das Haus ist blau. Wie geht es dir?"}|

      assert SpellCheck.parse_response(response, "Das haus ist Blau. wie get dir?") ==
               "Das Haus ist blau. Wie geht es dir?"
    end

    test "handles German umlauts and special chars in JSON" do
      response = ~s|{"text": "Schöne Grüße aus München"}|

      assert SpellCheck.parse_response(response, "Schöne Grüsse aus Munchen") ==
               "Schöne Grüße aus München"
    end
  end

  describe "parse_response/2 — fallback (non-JSON responses)" do
    test "returns corrected text trimmed" do
      assert SpellCheck.parse_response("  Hello world  ", "Helo wrold") == "Hello world"
    end

    test "strips surrounding double quotes LLMs sometimes add" do
      assert SpellCheck.parse_response("\"Hello world\"", "Helo wrold") == "Hello world"
    end

    test "strips surrounding single quotes" do
      assert SpellCheck.parse_response("'Hello world'", "Helo wrold") == "Hello world"
    end

    test "strips surrounding backticks" do
      assert SpellCheck.parse_response("`Hello world`", "Helo wrold") == "Hello world"
    end

    test "returns original on nil response" do
      assert SpellCheck.parse_response(nil, "original") == "original"
    end

    test "returns original on empty response" do
      assert SpellCheck.parse_response("", "original") == "original"
    end

    test "returns original on whitespace-only response" do
      assert SpellCheck.parse_response("   ", "original") == "original"
    end

    test "preserves inner quotes" do
      assert SpellCheck.parse_response("She said \"hello\"", "She said \"helo\"") ==
               "She said \"hello\""
    end

    test "strips <think> blocks from qwen3 models" do
      response = "<think>\nLet me check this...\n</think>\nHello world"
      assert SpellCheck.parse_response(response, "Helo wrold") == "Hello world"
    end

    test "strips unclosed <think> tags" do
      response = "<think>\nLet me check this...\nHello world"
      assert SpellCheck.parse_response(response, "Helo wrold") == "Helo wrold"
    end

    test "strips stray /think tags" do
      assert SpellCheck.parse_response("Hello world /think", "Helo wrold") == "Hello world"
    end

    test "strips untagged thinking when model dumps reasoning without <think> tags" do
      response = ~s'''
      Okay, let's tackle this proofreading request. The user wants me to fix spelling...
      Let me check each part.
      "Helo" should be "Hello". "wrold" should be "world".
      Hello world
      '''

      assert SpellCheck.parse_response(response, "Helo wrold") == "Hello world"
    end

    test "strips untagged thinking with German text" do
      response = ~s'''
      Okay, let me try to figure out how to approach this. The user wants me to proofread and fix their text.
      First sentence: "Das Haus ist blau." That's correct.
      Second sentence: "Wie geht dir?" should be "Wie geht es dir?"
      Das Haus ist blau. Wie geht es dir?
      '''

      assert SpellCheck.parse_response(response, "Das haus ist Blau. wie get dir?") ==
               "Das Haus ist blau. Wie geht es dir?"
    end

    test "strips untagged thinking with numbered steps" do
      response = ~s'''
      We are given a text: "Helo wrold"
       Steps:
       1. Check spelling: "Helo" -> "Hello"
       2. Check "wrold" -> "world"
       3. Therefore the corrected text:
      Hello world
      '''

      assert SpellCheck.parse_response(response, "Helo wrold") == "Hello world"
    end

    test "does not strip short clean responses" do
      assert SpellCheck.parse_response("Hello world", "Helo wrold") == "Hello world"
    end

    test "returns original when thinking response has no extractable answer" do
      response =
        "Okay, let me analyze this text. The user wrote something but I'm not sure " <>
          "what they mean. Let me think about this more carefully. I need to consider " <>
          "multiple interpretations of this text and figure out the best correction."

      assert SpellCheck.parse_response(response, "Helo") == "Helo"
    end
  end
end
