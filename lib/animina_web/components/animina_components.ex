defmodule AniminaWeb.AniminaComponents do
  @moduledoc """
  Provides Animina UI components.
  """
  use Phoenix.Component

  @doc """
  Notification message box to communicate with the user.

  ## Examples

    <.notification_box avatars_urls={["https://www.wintermeyer.de/assets/images/avatar.jpg"]}>
      <h3 class="font-bold text-base text-brand-gray-700">
        Du hast 5 Punkte für die Erste Schritt erhalten!
      </h3>
      <p class="text-brand-gray-700 text-base font-normal">
        Nutze die Punkte, um neue Leute in deiner Umgebung
        zu entdecken.
      </p>
    </.notification_box>
  """
  attr :avatars_urls, :list, default: [], doc: "URLs of one or multiple avatars"
  attr :title, :string, default: nil, doc: "title of the notification"
  attr :message, :string, default: nil, doc: "message of the notification"
  slot :inner_block

  def notification_box(assigns) do
    ~H"""
    <div class="rotate-[24deg] w-[100%] rotate-[12deg] rotate-[0deg]" />
    <div
      class="border border-purple-400 md:w-[50%] w-[100%] mx-auto  rounded-lg bg-blue-100 px-4 py-3.5 flex items-start justify-between gap-8 drop-shadow xs:justify-start "
      phx-no-format
    >
      <%= unless Enum.empty?(@avatars_urls) do %>
        <div class="flex  xs:w-[25%] w-[20%]  -space-x-4">
          <%= for {avatar_url, index} <- Enum.with_index(@avatars_urls) do %>
            <% rotate_by = Integer.to_string(index * 12) %>
            <img
              class={[
                "w-16",
                "h-16",
                "border-2 object-cover",
                "border-white",
                "rotate-[" <> rotate_by <> "deg]"
              ]}
              src={avatar_url}
              alt=""
            />
          <% end %>
        </div>
      <% end %>

      <div class="xs:w-[65%] w-[70%] pl-4">
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

  @doc """
  Status bar.

  ## Examples

    <.status_bar title="Dating-Präferenzen" percent={15} />
  """
  attr :title, :string, default: nil, doc: "title of the status bar"
  attr :percent, :integer, default: 0, doc: "percent"

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

  @doc """
  Story card loading.

  ## Examples

    <.story_card_loading />
  """

  def story_card_loading(assigns) do
    ~H"""
    <div class="animate-pulse rounded-lg border border-gray-100 shadow-sm pb-4">
      <div class="h-[300px] w-full bg-gray-100"></div>

      <div class="pt-4 px-4">
        <div class="h-4 w-2/3 bg-gray-200 rounded-full"></div>
      </div>

      <div class="mt-4 px-4 space-y-1">
        <div class="h-3 w-[90%] bg-gray-100 rounded-full"></div>
        <div class="h-3 w-[80%] bg-gray-100 rounded-full"></div>
        <div class="h-3 w-[40%] bg-gray-100 rounded-full"></div>
      </div>
    </div>
    """
  end

  @doc """
  Flag card loading.

  ## Examples

    <.flag_card_loading />
  """

  def flag_card_loading(assigns) do
    ~H"""
    <div class="animate-pulse pb-4">
      <div class="h-4 w-1/3 bg-gray-200 rounded-full"></div>

      <div class="mt-4 flex flex-wrap gap-2 w-full">
        <div class="h-8 w-[60%] bg-gray-100 rounded-full"></div>
        <div class="h-8 w-[30%] bg-gray-100 rounded-full"></div>
        <div class="h-8 w-[40%] bg-gray-100 rounded-full"></div>
        <div class="h-8 w-[50%] bg-gray-100 rounded-full"></div>
      </div>
    </div>
    """
  end
end
