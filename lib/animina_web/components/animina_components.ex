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
  attr :points     , :integer, default: 0  , doc: "number of points the user has"
  attr :avatar_url , :string , default: nil, doc: "URL of the user's avatar"
  attr :title      , :string , default: nil, doc: "title of the notification"
  attr :message    , :string , default: nil, doc: "message of the notification"
  slot :inner_block

  def notification_box(assigns) do
    ~H"""
    <div class="border border-purple-400 rounded-lg bg-blue-100 px-4 py-3.5 flex items-start gap-4">
      <div
        :if={@avatar_url}
        class="w-11 h-11 shrink-0 rounded-full border border-white overflow-hidden"
      >
        <img class="w-full h-full object-cover" alt="Avatar" src={@avatar_url} />
      </div>
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
