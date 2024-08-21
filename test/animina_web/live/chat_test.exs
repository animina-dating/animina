defmodule AniminaWeb.ChatTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Message
  alias Animina.Accounts.User
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story

  describe "Tests the Chat Live" do
    setup do
      public_user = create_public_user()

      private_user = create_private_user()

      Credit.create!(%{
        user_id: private_user.id,
        points: 100,
        subject: "Registration bonus"
      })

      Credit.create!(%{
        user_id: public_user.id,
        points: 100,
        subject: "Registration bonus"
      })

      [
        public_user: public_user,
        private_user: private_user
      ]
    end

    test "You are redirected to the chat page of a profile by clicking the chat icon on top of a profile",
         %{
           conn: conn,
           public_user: public_user,
           private_user: private_user
         } do
      # we visit the message box for public user and private user

      {:ok, index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{private_user.username}")

      assert html =~ private_user.name
      assert html =~ "#{private_user.height}"

      {:ok, index_live, html} =
        index_live
        |> element("#chat_button")
        |> render_click()
        |> follow_redirect(
          conn
          |> login_user(%{
            "username_or_email" => public_user.username,
            "password" => "MichaelTheEngineer"
          }),
          "/#{public_user.username}/messages/#{private_user.username}"
        )

      assert html =~ private_user.name
      assert has_element?(index_live, "#message_form")
    end

    test "if you visit /my/messages/profile you will be redirected to /current_user/messages/profile",
         %{
           conn: conn,
           public_user: public_user,
           private_user: private_user
         } do
      # we visit the message box for public user and private user

      {_, {:live_redirect, %{to: url, flash: %{}}}} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/messages/#{private_user.username}")

      assert url =~ "/#{public_user.username}/messages/#{private_user.username}"
    end

    test "You see a user's Mini Profile if you visit their chat live", %{
      conn: conn,
      public_user: public_user,
      private_user: private_user
    } do
      # we visit the message box for public user and private user

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{public_user.username}/messages/#{private_user.username}")

      assert html =~ private_user.name
      assert html =~ "#{private_user.height}"
    end

    test "You can send a message through the message box", %{
      conn: conn,
      public_user: public_user,
      private_user: private_user
    } do
      # we visit the message box for public user and private user

      {:ok, index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{public_user.username}/messages/#{private_user.username}")

      refute html =~ "Hello, how are you?"

      html =
        index_live
        |> form("#message_form", message: %{"content" => "Hello, how are you?"})
        |> render_submit()

      assert html =~ "Hello, how are you?"

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{public_user.username}/messages/#{private_user.username}")

      assert html =~ "Hello, how are you?"

      assert html =~ private_user.name
      assert html =~ "#{private_user.height}"
    end

    test "You can view messages received in the chat box", %{
      conn: conn,
      public_user: public_user,
      private_user: private_user
    } do
      # we visit the message box for public user and private user

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{public_user.username}/messages/#{private_user.username}")

      refute html =~ "This is a message received"

      {:ok, message} =
        Message.create(%{
          sender_id: private_user.id,
          receiver_id: public_user.id,
          content: "This is a message received"
        })

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{public_user.username}/messages/#{private_user.username}")

      assert html =~ message.content
    end

    test "Once You view a chat page , all messages that had previously not been read will be marked as read",
         %{
           conn: conn,
           public_user: public_user,
           private_user: private_user
         } do
      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{public_user.username}/messages/#{private_user.username}")

      refute html =~ "This is a message received"

      {:ok, message} =
        Message.create(%{
          sender_id: private_user.id,
          receiver_id: public_user.id,
          content: "This is a message received"
        })

      assert message.read_at == nil

      {:ok, _index_live, _html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{public_user.username}/messages/#{private_user.username}")

      {:ok, [message]} = Message.by_id(message.id)

      refute message.read_at == nil
    end
  end

  defp create_public_user do
    {:ok, user} =
      User.create(%{
        email: "adam@example.com",
        username: "adam",
        name: "Adam Newuser",
        hashed_password: Bcrypt.hash_pwd_salt("MichaelTheEngineer"),
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12345678",
        language: "en",
        legal_terms_accepted: true,
        confirmed_at: DateTime.utc_now()
      })

    create_about_me_story(user.id, get_about_me_headline().id)

    user
  end

  defp create_private_user do
    {:ok, user} =
      User.create(%{
        email: "private@example.com",
        username: "private",
        name: "Private",
        hashed_password: Bcrypt.hash_pwd_salt("MichaelTheEngineer"),
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-22345678",
        language: "en",
        is_private: true,
        legal_terms_accepted: true,
        confirmed_at: DateTime.utc_now()
      })

    create_about_me_story(user.id, get_about_me_headline().id)
    user
  end

  defp create_about_me_story(user_id, headline_id) do
    Story.create(%{
      user_id: user_id,
      headline_id: headline_id,
      content: "This is a story about me",
      position: 1
    })
  end

  defp get_about_me_headline do
    case Headline.by_subject("About me") do
      {:ok, headline} ->
        headline

      _ ->
        {:ok, headline} =
          Headline.create(%{
            subject: "About me",
            position: 90
          })

        headline
    end
  end

  defp login_user(conn, attributes) do
    {:ok, lv, _html} = live(conn, ~p"/sign-in/")

    form =
      form(lv, "#basic_user_sign_in_form", user: attributes)

    submit_form(form, conn)
  end
end
