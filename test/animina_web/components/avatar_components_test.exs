defmodule AniminaWeb.AvatarComponentsTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Animina.Accounts.Scope
  alias Animina.Photos.Photo
  alias AniminaWeb.AvatarComponents

  describe "user_avatar/1" do
    test "renders photo avatar with :sm size" do
      html = render_avatar(size: :sm, has_photo: true)

      assert html =~ "w-10 h-10"
      assert html =~ "rounded-full"
      assert html =~ "object-cover"
      assert html =~ "<img"
    end

    test "renders photo avatar with :xs size" do
      html = render_avatar(size: :xs, has_photo: true)
      assert html =~ "w-8 h-8"
    end

    test "renders photo avatar with :md size (default)" do
      html = render_avatar(size: :md, has_photo: true)
      assert html =~ "w-12 h-12"
    end

    test "renders photo avatar with :lg size" do
      html = render_avatar(size: :lg, has_photo: true)
      assert html =~ "w-16 h-16"
    end

    test "renders initials fallback when no photo" do
      html = render_avatar(size: :md, has_photo: false)

      assert html =~ "bg-primary/10"
      assert html =~ "rounded-full"
      assert html =~ "T"
      refute html =~ "<img"
    end

    test "shows green dot when online=true" do
      html = render_avatar(online: true)
      assert html =~ "bg-success"
    end

    test "hides dot when online=false" do
      html = render_avatar(online: false)
      refute html =~ "bg-success"
    end

    test "hides dot when user has hide_online_status=true (non-privileged viewer)" do
      html = render_avatar(online: true, hide_online_status: true)
      refute html =~ "bg-success"
    end

    test "shows dot when viewer is moderator despite hide_online_status=true" do
      html = render_avatar(online: true, hide_online_status: true, viewer_role: "moderator")
      assert html =~ "bg-success"
    end

    test "shows dot when viewer is admin despite hide_online_status=true" do
      html = render_avatar(online: true, hide_online_status: true, viewer_role: "admin")
      assert html =~ "bg-success"
    end

    test "hides dot for self-avatar (user.id == current_scope.user.id)" do
      html = render_avatar(online: true, is_self: true)
      refute html =~ "bg-success"
    end

    test "renders badge slot content" do
      html = render_avatar_with_badge()
      assert html =~ "test-badge-content"
    end

    test "online dot has correct size for :xs avatar" do
      html = render_avatar(size: :xs, online: true)
      assert html =~ "w-2 h-2"
    end

    test "online dot has correct size for :lg avatar" do
      html = render_avatar(size: :lg, online: true)
      assert html =~ "w-3.5 h-3.5"
    end
  end

  # --- Test helpers ---

  defp render_avatar(opts) do
    size = Keyword.get(opts, :size, :md)
    online = Keyword.get(opts, :online, false)
    has_photo = Keyword.get(opts, :has_photo, false)
    hide_online_status = Keyword.get(opts, :hide_online_status, false)
    viewer_role = Keyword.get(opts, :viewer_role, "user")
    is_self = Keyword.get(opts, :is_self, false)

    user_id = "user-123"
    viewer_id = if is_self, do: user_id, else: "viewer-456"

    user = %{id: user_id, display_name: "TestUser", hide_online_status: hide_online_status}
    viewer_user = %{id: viewer_id}

    scope = %Scope{
      user: viewer_user,
      current_role: viewer_role,
      roles: [viewer_role]
    }

    photos =
      if has_photo do
        %{user_id => %Photo{id: Ecto.UUID.generate(), filename: "test.jpg"}}
      else
        %{}
      end

    assigns =
      assign(%Phoenix.LiveView.Socket{}, %{
        user: user,
        photos: photos,
        size: size,
        online: online,
        current_scope: scope
      })
      |> Map.get(:assigns)

    rendered_to_string(~H"""
    <AvatarComponents.user_avatar
      user={@user}
      photos={@photos}
      size={@size}
      online={@online}
      current_scope={@current_scope}
    />
    """)
  end

  defp render_avatar_with_badge do
    user = %{id: "user-123", display_name: "TestUser", hide_online_status: false}
    viewer_user = %{id: "viewer-456"}
    scope = %Scope{user: viewer_user, current_role: "user", roles: ["user"]}

    assigns =
      assign(%Phoenix.LiveView.Socket{}, %{
        user: user,
        scope: scope
      })
      |> Map.get(:assigns)

    rendered_to_string(~H"""
    <AvatarComponents.user_avatar
      user={@user}
      photos={%{}}
      current_scope={@scope}
    >
      <:badge>
        <span class="test-badge-content">!</span>
      </:badge>
    </AvatarComponents.user_avatar>
    """)
  end
end
