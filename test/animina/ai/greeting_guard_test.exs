defmodule Animina.AI.JobTypes.GreetingGuardTest do
  use Animina.DataCase, async: true

  alias Animina.AI.JobTypes.GreetingGuard

  describe "should_check?/4" do
    setup do
      # Enable the wingman feature flag for these tests
      # DataCase sandbox rolls back the DB change automatically
      FunWithFlags.enable(:wingman)

      sender = %{gender: "male", wingman_enabled: true}
      recipient = %{gender: "female"}
      %{sender: sender, recipient: recipient}
    end

    test "returns true for short message from male to female with empty messages", %{
      sender: sender,
      recipient: recipient
    } do
      assert GreetingGuard.should_check?(sender, recipient, "Hallo!", [])
    end

    test "returns false for long messages", %{sender: sender, recipient: recipient} do
      long = "This is a really personal and specific message about your moodboard"
      refute GreetingGuard.should_check?(sender, recipient, long, [])
    end

    test "returns false when messages already exist", %{sender: sender, recipient: recipient} do
      refute GreetingGuard.should_check?(sender, recipient, "Hi", [:existing_message])
    end

    test "returns false for female senders", %{recipient: recipient} do
      sender = %{gender: "female", wingman_enabled: true}
      refute GreetingGuard.should_check?(sender, recipient, "Hi", [])
    end

    test "returns false for multiline messages", %{sender: sender, recipient: recipient} do
      refute GreetingGuard.should_check?(sender, recipient, "Hi\nHow are you?", [])
    end

    test "returns false when wingman is disabled", %{recipient: recipient} do
      sender = %{gender: "male", wingman_enabled: false}
      refute GreetingGuard.should_check?(sender, recipient, "Hi", [])
    end
  end

  describe "build_prompt/1" do
    test "returns the content as the prompt" do
      assert GreetingGuard.build_prompt(%{"content" => "Hello!"}) == "Hello!"
    end
  end

  describe "prepare_input/1" do
    test "builds system prompt with sender and recipient names" do
      {:ok, opts} =
        GreetingGuard.prepare_input(%{
          "sender_name" => "Max",
          "recipient_name" => "Lisa"
        })

      api_opts = Keyword.fetch!(opts, :api_opts)
      system = Keyword.fetch!(api_opts, :system)
      assert system =~ "Max"
      assert system =~ "Lisa"
      assert system =~ "generic greeting"
      assert Keyword.fetch!(api_opts, :format) == "json"
    end
  end
end
