defmodule AniminaWeb.UserLive.BlockedContactsTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Accounts

  describe "Blocked Contacts page" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings/blocked-contacts")
      assert {:redirect, %{to: "/users/log-in"}} = redirect
    end

    test "renders empty state", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/blocked-contacts")

      assert html =~ "Blocked Contacts"
      assert html =~ "No contacts blocked yet"
      assert html =~ "0/50"
    end

    test "adds an email entry", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/blocked-contacts")

      html =
        lv
        |> form("#blocked-contact-form", %{value: "Test@Example.COM"})
        |> render_submit()

      assert html =~ "test@example.com"
      assert html =~ "Contact blocked"
      assert html =~ "1/50"
    end

    test "adds a phone entry and formats it nicely", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/blocked-contacts")

      html =
        lv
        |> form("#blocked-contact-form", %{value: "0171 1234567"})
        |> render_submit()

      # Phone is displayed in international format with spaces
      assert html =~ "+49 171 1234567"
      assert html =~ "Contact blocked"
    end

    test "shows label alongside value", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/blocked-contacts")

      html =
        lv
        |> form("#blocked-contact-form", %{value: "ex@example.com", label: "Ex-Husband"})
        |> render_submit()

      assert html =~ "Ex-Husband"
      assert html =~ "ex@example.com"
    end

    test "removes an entry", %{conn: conn} do
      user = user_fixture(language: "en")
      {:ok, _} = Accounts.add_contact_blacklist_entry(user, %{value: "remove@example.com"})

      {:ok, lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/blocked-contacts")

      assert html =~ "remove@example.com"

      lv
      |> element("[phx-click=delete_entry]")
      |> render_click()

      html = render(lv)
      assert html =~ "Contact unblocked"
      assert html =~ "0/50"
    end

    test "shows validation errors for invalid input", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/blocked-contacts")

      html =
        lv
        |> form("#blocked-contact-form", %{value: "123"})
        |> render_submit()

      assert html =~ "is not a valid phone number"
    end

    test "filters entries by search term", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _} =
        Accounts.add_contact_blacklist_entry(user, %{value: "alice@example.com", label: "Alice"})

      {:ok, _} =
        Accounts.add_contact_blacklist_entry(user, %{value: "030 12345678", label: "Bob Office"})

      {:ok, _} =
        Accounts.add_contact_blacklist_entry(user, %{value: "carol@test.com", label: "Carol"})

      {:ok, lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/blocked-contacts")

      # All entries visible initially
      assert html =~ "Alice"
      assert html =~ "Bob Office"
      assert html =~ "Carol"

      # Filter by email domain
      html = lv |> element("#filter-form") |> render_change(%{filter: "@test.com"})
      refute html =~ "Alice"
      refute html =~ "Bob Office"
      assert html =~ "Carol"

      # Filter by area code
      html = lv |> element("#filter-form") |> render_change(%{filter: "+4930"})
      refute html =~ "Alice"
      assert html =~ "Bob Office"
      refute html =~ "Carol"

      # Filter by label
      html = lv |> element("#filter-form") |> render_change(%{filter: "alice"})
      assert html =~ "Alice"
      refute html =~ "Bob Office"
      refute html =~ "Carol"

      # Clear filter shows all
      html = lv |> element("#filter-form") |> render_change(%{filter: ""})
      assert html =~ "Alice"
      assert html =~ "Bob Office"
      assert html =~ "Carol"
    end

    test "sorts entries", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _} =
        Accounts.add_contact_blacklist_entry(user, %{value: "zoe@example.com", label: "Zoe"})

      {:ok, _} =
        Accounts.add_contact_blacklist_entry(user, %{value: "anna@example.com", label: "Anna"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/blocked-contacts")

      # Sort A-Z by value
      html = lv |> element("#sort-select") |> render_change(%{sort: "value_asc"})
      anna_pos = :binary.match(html, "Anna") |> elem(0)
      zoe_pos = :binary.match(html, "Zoe") |> elem(0)
      assert anna_pos < zoe_pos

      # Sort Z-A by value
      html = lv |> element("#sort-select") |> render_change(%{sort: "value_desc"})
      anna_pos = :binary.match(html, "Anna") |> elem(0)
      zoe_pos = :binary.match(html, "Zoe") |> elem(0)
      assert zoe_pos < anna_pos
    end
  end
end
