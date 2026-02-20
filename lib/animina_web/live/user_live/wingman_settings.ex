defmodule AniminaWeb.UserLive.WingmanSettings do
  use AniminaWeb, :live_view

  alias Animina.Accounts

  @styles [
    {"casual", "hero-chat-bubble-bottom-center"},
    {"funny", "hero-face-smile"},
    {"empathetic", "hero-heart"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.settings_header
          title={gettext("Wingman Style")}
          subtitle={gettext("Choose how your Wingman gives advice")}
        />

        <div class="grid grid-cols-1 gap-3">
          <%= for {style, icon} <- @styles do %>
            <button
              phx-click="select_style"
              phx-value-style={style}
              class={[
                "flex items-start gap-4 w-full px-4 py-4 rounded-lg border transition-colors text-start",
                if(style == @current_style,
                  do: "border-primary bg-primary/10",
                  else: "border-base-300 hover:border-primary"
                )
              ]}
            >
              <.icon
                name={icon}
                class={[
                  "h-6 w-6 mt-0.5 shrink-0",
                  if(style == @current_style, do: "text-primary", else: "text-base-content/50")
                ]}
              />
              <div>
                <p class={[
                  "font-medium text-sm",
                  if(style == @current_style, do: "text-primary", else: "text-base-content")
                ]}>
                  {style_label(style)}
                </p>
                <p class="text-xs text-base-content/60 mt-0.5">
                  {style_description(style)}
                </p>
              </div>
            </button>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:page_title, gettext("Wingman Style"))
      |> assign(:current_style, user.wingman_style || "casual")
      |> assign(:styles, @styles)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_style", %{"style" => style}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.update_wingman_style(user, style) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_style, updated_user.wingman_style)
         |> put_flash(:info, gettext("Wingman style updated"))}

      _ ->
        {:noreply, socket}
    end
  end

  defp style_label("casual"), do: gettext("Casual")
  defp style_label("funny"), do: gettext("Funny")
  defp style_label("empathetic"), do: gettext("Empathetic")
  defp style_label(_), do: ""

  defp style_description("casual"),
    do: gettext("Your buddy at the bar — direct, relaxed, a little cheeky")

  defp style_description("funny"),
    do: gettext("Humor-focused — playful, witty, finds the funny angle")

  defp style_description("empathetic"),
    do: gettext("Warm and thoughtful — gentle, encouraging, heartfelt")

  defp style_description(_), do: ""
end
