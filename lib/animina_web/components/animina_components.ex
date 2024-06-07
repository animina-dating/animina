defmodule AniminaWeb.AniminaComponents do
  @moduledoc """
  Provides Animina UI components.
  """
  use Phoenix.Component

  @doc """
  Notification message box to communicate with the user.

  ## Examples

    <.notification_box avatars_urls={["https://www.wintermeyer.de/assets/images/avatar.jpg"]}>
      <h3 class="text-base font-bold text-brand-gray-700">
        Du hast 5 Punkte für die Erste Schritt erhalten!
      </h3>
      <p class="text-base font-normal text-brand-gray-700">
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
      class="border border-purple-400 md:w-[100%] w-[100%] mx-auto  rounded-lg bg-blue-100 px-4 py-3.5 flex items-start justify-between gap-8 drop-shadow xs:justify-start "
      phx-no-format
    >
      <%= unless Enum.empty?(@avatars_urls) do %>
        <div class="flex  xl:w-[10%] w-[20%]  -space-x-4">
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
    <h3 class="text-base font-bold text-brand-gray-700">
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
    <p class="text-base font-normal text-brand-gray-700">
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
      <div class="relative w-full h-2 overflow-hidden bg-blue-100 rounded-full">
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
    <div class="pb-4 rounded-lg shadow-sm animate-pulse">
      <div class="h-[200px] w-full rounded-md bg-gray-100 dark:bg-gray-800"></div>

      <div class="pt-4">
        <div class="w-2/3 h-4 bg-gray-200 rounded-full dark:bg-gray-700"></div>
      </div>

      <div class="mt-8 space-y-1">
        <div class="h-3 w-[90%] bg-gray-100 dark:bg-gray-800 rounded-full"></div>
        <div class="h-3 w-[80%] bg-gray-100 dark:bg-gray-800 rounded-full"></div>
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
    <div class="pb-4 animate-pulse">
      <div class="w-1/3 h-4 bg-gray-200 rounded-full dark:bg-gray-700"></div>

      <div class="flex flex-wrap w-full gap-2 mt-4">
        <div class="h-8 w-[60%] bg-gray-100 dark:bg-gray-700 rounded-full"></div>
        <div class="h-8 w-[30%] bg-gray-100 dark:bg-gray-700 rounded-full"></div>
        <div class="h-8 w-[40%] bg-gray-100 dark:bg-gray-700 rounded-full"></div>
        <div class="h-8 w-[50%] bg-gray-100 dark:bg-gray-700 rounded-full"></div>
      </div>
    </div>
    """
  end

  @doc """
  Story flags loading.

  ## Examples

    <.story_flags_loading />
  """

  def story_flags_loading(assigns) do
    ~H"""
    <div class="animate-pulse">
      <div class="flex flex-wrap w-full gap-2 mt-4">
        <div class="h-6 w-[60%] bg-gray-100 dark:bg-gray-700 rounded-md"></div>
        <div class="h-6 w-[30%] bg-gray-100 dark:bg-gray-700 rounded-md"></div>
        <div class="h-6 w-[40%] bg-gray-100 dark:bg-gray-700 rounded-md"></div>
        <div class="h-6 w-[50%] bg-gray-100 dark:bg-gray-700 rounded-md"></div>
      </div>
    </div>
    """
  end

  @doc """
  Bookmark card loading.

  ## Examples

    <.bookmark_card_loading />
  """

  def bookmark_card_loading(assigns) do
    ~H"""
    <div class="animate-pulse">
      <div class="w-full p-4">
        <div class="h-4 w-[80%] bg-gray-100 dark:bg-gray-700 rounded-md"></div>

        <div class="flex items-center justify-between mt-4 space-x-4">
          <div class="flex-shrink-0 w-12 h-12 bg-gray-100 rounded-md dark:bg-gray-700"></div>

          <div class="w-full space-y-2">
            <div class="h-3 w-[40%] bg-gray-100 dark:bg-gray-700 rounded-md"></div>
            <div class="h-3 w-[60%] bg-gray-100 dark:bg-gray-700 rounded-md"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Flag card loading.

  ## Examples

    <.flag_card_loading />
  """

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

  def footer(assigns) do
    ~H"""
    <footer class="bg-white" aria-labelledby="footer-heading">
      <h2 id="footer-heading" class="sr-only">Footer</h2>
      <div class="px-6 pt-16 pb-8 mx-auto max-w-7xl sm:pt-24 lg:px-8 lg:pt-32">
        <div class="xl:grid xl:grid-cols-3 xl:gap-8">
          <div class="space-y-8">
            <p class="text-sm leading-6 text-gray-600">
              Animina - Die faire Dating-Plattform.
            </p>
            <div class="flex space-x-6">
              <a href="#" class="text-gray-400 hover:text-gray-500">
                <span class="sr-only">Facebook</span>
                <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path
                    fill-rule="evenodd"
                    d="M22 12c0-5.523-4.477-10-10-10S2 6.477 2 12c0 4.991 3.657 9.128 8.438 9.878v-6.987h-2.54V12h2.54V9.797c0-2.506 1.492-3.89 3.777-3.89 1.094 0 2.238.195 2.238.195v2.46h-1.26c-1.243 0-1.63.771-1.63 1.562V12h2.773l-.443 2.89h-2.33v6.988C18.343 21.128 22 16.991 22 12z"
                    clip-rule="evenodd"
                  >
                  </path>
                </svg>
              </a>
              <a href="#" class="text-gray-400 hover:text-gray-500">
                <span class="sr-only">Instagram</span>
                <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path
                    fill-rule="evenodd"
                    d="M12.315 2c2.43 0 2.784.013 3.808.06 1.064.049 1.791.218 2.427.465a4.902 4.902 0 011.772 1.153 4.902 4.902 0 011.153 1.772c.247.636.416 1.363.465 2.427.048 1.067.06 1.407.06 4.123v.08c0 2.643-.012 2.987-.06 4.043-.049 1.064-.218 1.791-.465 2.427a4.902 4.902 0 01-1.153 1.772 4.902 4.902 0 01-1.772 1.153c-.636.247-1.363.416-2.427.465-1.067.048-1.407.06-4.123.06h-.08c-2.643 0-2.987-.012-4.043-.06-1.064-.049-1.791-.218-2.427-.465a4.902 4.902 0 01-1.772-1.153 4.902 4.902 0 01-1.153-1.772c-.247-.636-.416-1.363-.465-2.427-.047-1.024-.06-1.379-.06-3.808v-.63c0-2.43.013-2.784.06-3.808.049-1.064.218-1.791.465-2.427a4.902 4.902 0 011.153-1.772A4.902 4.902 0 015.45 2.525c.636-.247 1.363-.416 2.427-.465C8.901 2.013 9.256 2 11.685 2h.63zm-.081 1.802h-.468c-2.456 0-2.784.011-3.807.058-.975.045-1.504.207-1.857.344-.467.182-.8.398-1.15.748-.35.35-.566.683-.748 1.15-.137.353-.3.882-.344 1.857-.047 1.023-.058 1.351-.058 3.807v.468c0 2.456.011 2.784.058 3.807.045.975.207 1.504.344 1.857.182.466.399.8.748 1.15.35.35.683.566 1.15.748.353.137.882.3 1.857.344 1.054.048 1.37.058 4.041.058h.08c2.597 0 2.917-.01 3.96-.058.976-.045 1.505-.207 1.858-.344.466-.182.8-.398 1.15-.748.35-.35.566-.683.748-1.15.137-.353.3-.882.344-1.857.048-1.055.058-1.37.058-4.041v-.08c0-2.597-.01-2.917-.058-3.96-.045-.976-.207-1.505-.344-1.858a3.097 3.097 0 00-.748-1.15 3.098 3.098 0 00-1.15-.748c-.353-.137-.882-.3-1.857-.344-1.023-.047-1.351-.058-3.807-.058zM12 6.865a5.135 5.135 0 110 10.27 5.135 5.135 0 010-10.27zm0 1.802a3.333 3.333 0 100 6.666 3.333 3.333 0 000-6.666zm5.338-3.205a1.2 1.2 0 110 2.4 1.2 1.2 0 010-2.4z"
                    clip-rule="evenodd"
                  >
                  </path>
                </svg>
              </a>
              <a href="#" class="text-gray-400 hover:text-gray-500">
                <span class="sr-only">X</span>
                <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M13.6823 10.6218L20.2391 3H18.6854L12.9921 9.61788L8.44486 3H3.2002L10.0765 13.0074L3.2002 21H4.75404L10.7663 14.0113L15.5685 21H20.8131L13.6819 10.6218H13.6823ZM11.5541 13.0956L10.8574 12.0991L5.31391 4.16971H7.70053L12.1742 10.5689L12.8709 11.5655L18.6861 19.8835H16.2995L11.5541 13.096V13.0956Z">
                  </path>
                </svg>
              </a>
              <a href="#" class="text-gray-400 hover:text-gray-500">
                <span class="sr-only">GitHub</span>
                <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path
                    fill-rule="evenodd"
                    d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
                    clip-rule="evenodd"
                  >
                  </path>
                </svg>
              </a>
              <a href="#" class="text-gray-400 hover:text-gray-500">
                <span class="sr-only">YouTube</span>
                <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path
                    fill-rule="evenodd"
                    d="M19.812 5.418c.861.23 1.538.907 1.768 1.768C21.998 8.746 22 12 22 12s0 3.255-.418 4.814a2.504 2.504 0 0 1-1.768 1.768c-1.56.419-7.814.419-7.814.419s-6.255 0-7.814-.419a2.505 2.505 0 0 1-1.768-1.768C2 15.255 2 12 2 12s0-3.255.417-4.814a2.507 2.507 0 0 1 1.768-1.768C5.744 5 11.998 5 11.998 5s6.255 0 7.814.418ZM15.194 12 10 15V9l5.194 3Z"
                    clip-rule="evenodd"
                  >
                  </path>
                </svg>
              </a>
            </div>
          </div>
          <div class="grid grid-cols-2 gap-8 mt-16 xl:col-span-2 xl:mt-0">
            <div class="md:grid md:grid-cols-2 md:gap-8">
              <div>
                <h3 class="text-sm font-semibold leading-6 text-gray-900">Solutions</h3>
                <ul role="list" class="mt-6 space-y-4">
                  <li>
                    <a href="#" class="text-sm leading-6 text-gray-600 hover:text-gray-900">
                      Marketing
                    </a>
                  </li>
                  <li>
                    <a href="#" class="text-sm leading-6 text-gray-600 hover:text-gray-900">
                      Analytics
                    </a>
                  </li>
                </ul>
              </div>
              <div class="mt-10 md:mt-0">
                <h3 class="text-sm font-semibold leading-6 text-gray-900">Support</h3>
                <ul role="list" class="mt-6 space-y-4">
                  <li>
                    <a href="#" class="text-sm leading-6 text-gray-600 hover:text-gray-900">
                      Pricing
                    </a>
                  </li>
                  <li>
                    <a href="#" class="text-sm leading-6 text-gray-600 hover:text-gray-900">
                      Documentation
                    </a>
                  </li>
                </ul>
              </div>
            </div>
            <div class="md:grid md:grid-cols-2 md:gap-8">
              <div>
                <h3 class="text-sm font-semibold leading-6 text-gray-900">Company</h3>
                <ul role="list" class="mt-6 space-y-4">
                  <li>
                    <a href="#" class="text-sm leading-6 text-gray-600 hover:text-gray-900">About</a>
                  </li>
                  <li>
                    <a href="#" class="text-sm leading-6 text-gray-600 hover:text-gray-900">Blog</a>
                  </li>
                </ul>
              </div>
              <div class="mt-10 md:mt-0">
                <h3 class="text-sm font-semibold leading-6 text-gray-900">Legal</h3>
                <ul role="list" class="mt-6 space-y-4">
                  <li>
                    <a href="#" class="text-sm leading-6 text-gray-600 hover:text-gray-900">Claim</a>
                  </li>
                  <li>
                    <a href="#" class="text-sm leading-6 text-gray-600 hover:text-gray-900">
                      Privacy
                    </a>
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
        <div class="pt-8 mt-16 border-t border-gray-900/10 sm:mt-20 lg:mt-24">
          <p class="text-xs leading-5 text-gray-500">
            © 2024 <a
              href="https://www.wintermeyer-consulting.de"
              rel="noopener noreferrer"
              class="text-[#0077B6] dark:text-[#00A6D6]"
            >
        Wintermeyer Consulting
      </a>. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
    """
  end
end
