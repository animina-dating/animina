defmodule AniminaWeb.MessagesLiveGreetingGuardTest do
  use AniminaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Messaging

  describe "greeting guard in conversation" do
    setup do
      male_user =
        user_fixture(display_name: "Max", language: "en", gender: "male")

      female_user =
        user_fixture(display_name: "Lisa", language: "en", gender: "female")

      {:ok, conversation} = Messaging.get_or_create_conversation(male_user.id, female_user.id)

      %{male_user: male_user, female_user: female_user, conversation: conversation}
    end

    test "long message bypasses greeting guard (sends normally)", %{
      conn: conn,
      male_user: male_user,
      conversation: conversation
    } do
      FunWithFlags.enable(:wingman)

      {:ok, lv, _html} =
        conn
        |> log_in_user(male_user)
        |> live(~p"/my/messages/#{conversation.id}")

      long_message = "Hey, I noticed you really like hiking! What's your favourite trail?"

      lv
      |> form("#message-form", message: %{content: long_message})
      |> render_submit()

      # Message should be sent (no guard); wait for PubSub
      :timer.sleep(100)
      html = render(lv)

      # Should NOT show the greeting guard modal
      refute html =~ "Stand out!"
      # Message should appear in conversation
      assert html =~ "favourite trail"

      FunWithFlags.disable(:wingman)
    end

    test "existing messages bypass greeting guard", %{
      conn: conn,
      male_user: male_user,
      female_user: female_user,
      conversation: conversation
    } do
      FunWithFlags.enable(:wingman)

      # Send a message first so it's not a first message
      {:ok, _msg} = Messaging.send_message(conversation.id, female_user.id, "Hey there!")

      {:ok, lv, _html} =
        conn
        |> log_in_user(male_user)
        |> live(~p"/my/messages/#{conversation.id}")

      lv
      |> form("#message-form", message: %{content: "Hi!"})
      |> render_submit()

      :timer.sleep(100)
      html = render(lv)

      # Should NOT show the greeting guard modal (not a first message)
      refute html =~ "Stand out!"

      FunWithFlags.disable(:wingman)
    end

    test "female→male bypasses greeting guard", %{
      conn: conn,
      female_user: female_user,
      conversation: conversation
    } do
      FunWithFlags.enable(:wingman)

      {:ok, lv, _html} =
        conn
        |> log_in_user(female_user)
        |> live(~p"/my/messages/#{conversation.id}")

      lv
      |> form("#message-form", message: %{content: "Hi!"})
      |> render_submit()

      :timer.sleep(100)
      html = render(lv)

      # Should NOT show greeting guard modal for female→male
      refute html =~ "Stand out!"

      FunWithFlags.disable(:wingman)
    end

    test "wingman disabled bypasses greeting guard", %{
      conn: conn,
      female_user: female_user
    } do
      FunWithFlags.enable(:wingman)

      # Create a male user and disable wingman via the proper changeset
      male_no_wingman =
        user_fixture(display_name: "Tom", language: "en", gender: "male")

      {:ok, male_no_wingman} =
        male_no_wingman
        |> Animina.Accounts.User.wingman_changeset(%{wingman_enabled: false})
        |> Animina.Repo.update()

      {:ok, conversation} =
        Messaging.get_or_create_conversation(male_no_wingman.id, female_user.id)

      {:ok, lv, _html} =
        conn
        |> log_in_user(male_no_wingman)
        |> live(~p"/my/messages/#{conversation.id}")

      lv
      |> form("#message-form", message: %{content: "Hi!"})
      |> render_submit()

      :timer.sleep(100)
      html = render(lv)

      refute html =~ "Stand out!"

      FunWithFlags.disable(:wingman)
    end
  end
end
