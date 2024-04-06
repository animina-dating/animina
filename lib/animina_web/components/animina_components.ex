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

  @doc """
  Flag card loading.

  ## Examples

    <.flag_card_loading />
  """

  def height_visualization(assigns) do
    ~H"""
    <%= if @current_user.gender != "diverse"  &&  @profile_user != "diverse" do %>
      <div class="flex gap-12 bg-[#B2CCEF] dark:bg-gray-800 rounded-md p-4 py-8 justify-start items-end">
        <div class="flex z0 gap-0">
          <p class="h-[100px] dark:bg-white bg-black w-[2px] " />
          <div class="h-[100%] flex  relative">
            <p class="absolute  dark:text-white -top-[12px] text-xs  pb-2">200cm</p>

            <p class="w-[230px]   absolute top-[2px] mb-[180px] h-[1px] dark:bg-white bg-black" />
            <p class="absolute top-[16px] dark:text-white text-xs  pb-3">150cm</p>
            <p class="w-[230px]   absolute top-[30px]  h-[1px] dark:bg-white bg-black" />

            <p class="absolute top-[40px] dark:text-white  text-xs pb-3">100cm</p>
            <p class="w-[230px]   absolute top-[54px] h-[1px] dark:bg-white bg-black" />

            <p class="absolute top-[64px] dark:text-white text-xs  pb-3">50cm</p>
            <p
              class="w-[230px]   absolute top-[80px] h-[1px] dark:bg-white bg-black"
              style="z-index:1"
            />
          </div>
        </div>

        <div class="flex items-end gap-8">
          <.figure
            height={@current_user_height_for_figure}
            avatar={@current_user.profile_photo.filename}
            username={@current_user.username}
          />

          <.figure
            height={@profile_user_height_for_figure}
            username={@profile_user.username}
            avatar={@profile_user.profile_photo.filename}
          />
        </div>
      </div>
    <% end %>
    """
  end

  def figure(assigns) do
    ~H"""
    <div class="flex gap-2 items-end justify-end" style={"height:#{@height}px"}>
      <div class="md:w-[40px] dark:bg-white h-[100%] bg-black w-[35px] flex flex-col justify-end   items-center ">
        <div style="z-index:2" class="w-[100%]  pb-1 flex justify-center items-center">
          <div class="border-[1px] rounded-full bg-white h-[24px] w-[24px] border-[#1672DF]">
            <img src={"/uploads/#{@avatar}"} class="object-cover h-[100%]  w-[100%] object-cover  " />
          </div>
        </div>
      </div>
    </div>
    """
  end

  def current_user_figure(assigns) do
    ~H"""
    <%= if @gender == "male" do %>
      <.male_figure height={@height} />
    <% else %>
      <.female_figure height={@height} />
    <% end %>
    """
  end

  def potential_partner_figure(assigns) do
    ~H"""
    <%= if @partner_gender == "male" do %>
      <.male_figure height={@height} />
    <% else %>
      <.female_figure height={@height} />
    <% end %>
    """
  end

  def male_figure(assigns) do
    ~H"""
    <div
      class="md:w-[25px] w-[20px] flex flex-col justify-between  items-center "
      style={"height:#{@height}px"}
    >
      <p class="h-[13px] w-[13px] my-1  rounded-full dark:bg-white bg-black" />

      <div class="h-[55%]  flex gap-0">
        <p class="h-[100%] dark:bg-white bg-black rotate-12 w-[8px] rounded-b-full" />
        <p class="h-[100%] dark:bg-white bg-black w-[20px] md:w-[25px]" />
        <p class="h-[100%] dark:bg-white bg-black -rotate-12 w-[8px] rounded-b-full" />
      </div>
      <div class="h-[50%]  flex gap-0">
        <div class="md:w-[25px] w-[20px] flex justify-between">
          <p class="h-[100%] dark:bg-white bg-black rounded-b-full w-[40%]" />
          <p class="h-[100%] dark:bg-white bg-black rounded-b-full w-[40%]" />
        </div>
      </div>
    </div>
    """
  end

  def female_figure(assigns) do
    ~H"""
    <div
      class=" md:w-[40px] w-[35px] flex justify-between flex-col  items-center"
      style={"height:#{@height}px"}
    >
      <p class="h-[15px] w-[15px] my-1   rounded-full dark:bg-white bg-black" />

      <div class="h-[30%]  flex gap-0">
        <p class="h-[100%] dark:bg-white bg-black rotate-12 w-[8px] rounded-b-full" />
        <p class="h-[100%] dark:bg-white bg-black w-[20px] md:w-[25px]" />
        <p class="h-[100%] dark:bg-white bg-black -rotate-12 w-[8px] rounded-b-full" />
      </div>
      <div class="h-[5%] w-[20px] md:w-[25px] dark:bg-white bg-black " />
      <div class="h-[30%] dark:bg-white bg-black  w-[35px] md:w-[40px] flex gap-0" />

      <div class="h-[25%]  flex gap-0">
        <div class="md:w-[25px] w-[20px] flex justify-between">
          <p class="h-[100%] dark:bg-white bg-black w-[40%]" />
          <p class="h-[100%] dark:bg-white bg-black w-[40%]" />
        </div>
      </div>
    </div>
    """
  end
end
