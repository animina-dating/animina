defmodule AniminaWeb.AniminaComponents do
  @moduledoc """
  Provides Animina UI components.
  """
  use Phoenix.Component

  # -------------------------------------------------------------
  @doc """
  Notification message box to communicate with the user.

  ## Examples

    <.notification_box avatar_url={"https://www.wintermeyer.de/assets/images/avatar.jpg"}>
      <h3 class="font-bold text-base text-brand-gray-700">
        Du hast 5 Punkte für die Erste Schritt erhalten!
      </h3>
      <p class="text-brand-gray-700 text-base font-normal">
        Nutze die Punkte, um neue Leute in deiner Umgebung
        zu entdecken.
      </p>
    </.notification_box>
  """
  attr :box_with_avatar, :boolean, default: true
  attr :avatar_url   , :string , default: nil, doc: "URL of the user's avatar"
  attr :avatar_url_b , :string , default: nil, doc: "URL of the user's avatar"
  attr :title        , :string , default: nil, doc: "title of the notification"
  attr :message      , :string , default: nil, doc: "message of the notification"
  slot :inner_block

  def notification_box(assigns) do
    ~H"""
    <div
      class="border border-purple-400 rounded-lg bg-blue-100 px-4 py-3.5 flex items-start gap-4 drop-shadow"
      phx-no-format
    >
      <%= if @box_with_avatar do %>
        <%= if @avatar_url_b do %>
          <div class="relative w-[4.7rem]">
            <.notification_box_avatar
              avatar_url={ @avatar_url   }
              classes={[
                "absolute", "top-0", "left-0",
                "opacity-50", "brightness-95", "border-neutral-100",
              ]}
            />
            <.notification_box_avatar
              avatar_url={ @avatar_url_b }
              classes={[
                "absolute", "top-0", "left-[1.875rem]",
                "outline", "outline-[0.6px]", "outline-white", "outline-offset-0",
              ]}
            />
          </div>
        <% else %>
          <.notification_box_avatar
            avatar_url={ @avatar_url }
          />
        <% end %>
      <% end %>
      <div>
        <.notification_title :if={@title}>
          <%= @title %>
        </.notification_title>
        <.notification_message :if={@message}>
          <%= @message %>
        </.notification_message>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  # -------------------------------------------------------------
  @doc """
  Avatar in a notification message box.
  """
  attr :avatar_url   , :string , default: nil, doc: "URL of the user's avatar"
  attr :classes      , :list   , default: [] , doc: "classes"
  
  def notification_box_avatar(assigns) do
    ~H"""
    <div
      class={[
        "w-11 h-11 shrink-0 rounded-full border border-white overflow-hidden drop-shadow-md text-center align-middle",
        @classes,
      ]}
      phx-no-format
    >
        <%= if @avatar_url do %>
          <img class="w-full h-full object-cover drop-shadow" alt=" " src={ @avatar_url } />
        <% else %>
          <div
            class="w-11 text-center align-middle text-4xl cursor-default select-none"
            aria-hidden="true"
          >?</div>
        <% end %>
    </div>
    """
  end

  # -------------------------------------------------------------
  @doc """
  Title within the notification box.

  ## Examples

    <.notification_title>
      Du hast 5 Punkte für die Erste Schritt erhalten!
    </.notification_title>
  """
  slot :inner_block

  def notification_title(assigns) do
    ~H"""
    <h3 class="font-bold text-base text-brand-gray-700">
      <%= render_slot(@inner_block) %>
    </h3>
    """
  end

  # -------------------------------------------------------------
  @doc """
  Content within a notification box.

  ## Examples

    <.notification_message>
      Nutze die Punkte, um neue Leute in deiner Umgebung zu entdecken.
    </.notification_message>
  """
  slot :inner_block

  def notification_message(assigns) do
    ~H"""
    <p class="text-brand-gray-700 text-base font-normal">
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  # -------------------------------------------------------------
  @doc """
  Status bar.

  ## Examples

    <.status_bar title="Dating-Präferenzen" percent={15} />
  """
  attr :title   , :string , default: nil, doc: "title of the status bar"
  attr :percent , :integer, default: 0  , doc: "percent"

  def status_bar(assigns) do
    ~H"""
    <div class="space-y-4">
      <p :if={@title} class="text-base font-bold text-gray-500"><%= @title %></p>
      <div class="h-2 w-full bg-blue-100 rounded-full relative overflow-hidden">
        <div class="h-full bg-blue-600 rounded-full" style={"width:#{@percent}%"}></div>
      </div>
    </div>
    """
  end

end
