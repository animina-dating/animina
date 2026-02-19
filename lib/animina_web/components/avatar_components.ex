defmodule AniminaWeb.AvatarComponents do
  @moduledoc """
  Shared avatar component with optional online indicator.

  Usage:

      <.user_avatar user={user} photos={avatar_photos_map} online={true} current_scope={@current_scope} />

  The `photos` map is keyed by user ID, matching the format from `AvatarHelpers`.
  When a photo is found, it renders a signed URL image; otherwise, initials are shown.

  The green online dot respects privacy:
  - Hidden when `online` is false or not provided
  - Hidden for self-avatars (user.id == current_scope.user.id)
  - Hidden when the user has `hide_online_status: true`, unless the viewer is a moderator/admin
  """

  use Phoenix.Component

  alias Animina.Accounts.Scope
  alias Animina.Photos

  @size_classes %{
    xs: "w-8 h-8",
    sm: "w-10 h-10",
    md: "w-12 h-12",
    lg: "w-16 h-16"
  }

  @dot_classes %{
    xs: "w-2 h-2",
    sm: "w-2.5 h-2.5",
    md: "w-3 h-3",
    lg: "w-3.5 h-3.5"
  }

  @text_classes %{
    xs: "text-xs",
    sm: "text-sm",
    md: "text-base",
    lg: "text-lg"
  }

  attr :user, :map, required: true
  attr :photos, :map, default: %{}
  attr :size, :atom, default: :md
  attr :online, :boolean, default: false
  attr :current_scope, :any, default: nil
  attr :class, :string, default: nil
  slot :badge

  def user_avatar(assigns) do
    avatar_photo = Map.get(assigns.photos, assigns.user.id)
    size = assigns.size
    show_dot = show_online_dot?(assigns)

    assigns =
      assigns
      |> assign(:avatar_photo, avatar_photo)
      |> assign(:size_class, Map.fetch!(@size_classes, size))
      |> assign(:dot_class, Map.fetch!(@dot_classes, size))
      |> assign(:text_class, Map.fetch!(@text_classes, size))
      |> assign(:show_dot, show_dot)

    ~H"""
    <div class={["relative inline-flex flex-shrink-0", @class]}>
      <%= if @avatar_photo do %>
        <img
          src={Photos.signed_url(@avatar_photo)}
          alt={@user.display_name}
          class={[@size_class, "rounded-full object-cover"]}
        />
      <% else %>
        <div class={[@size_class, "rounded-full bg-primary/10 flex items-center justify-center"]}>
          <span class={["text-primary font-semibold", @text_class]}>
            {String.first(@user.display_name)}
          </span>
        </div>
      <% end %>
      <span
        :if={@show_dot}
        class={[
          @dot_class,
          "absolute bottom-0 right-0 rounded-full bg-success border-2 border-base-100"
        ]}
      />
      {render_slot(@badge)}
    </div>
    """
  end

  defp show_online_dot?(%{online: false}), do: false
  defp show_online_dot?(%{online: nil}), do: false

  defp show_online_dot?(assigns) do
    user = assigns.user
    scope = assigns.current_scope

    # Don't show dot for self
    is_self = scope && scope.user && scope.user.id == user.id
    if is_self, do: false, else: check_privacy(user, scope)
  end

  defp check_privacy(user, scope) do
    hide = Map.get(user, :hide_online_status, false)

    if hide do
      # Only moderators/admins can see through hidden status
      Scope.moderator?(scope)
    else
      true
    end
  end
end
