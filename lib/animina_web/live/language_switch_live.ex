defmodule AniminaWeb.LanguageSwitchLive do
  use AniminaWeb, :live_view

  @impl true
  def mount(_, %{"language" => language} = _session, socket) do
    socket =
      socket
      |> assign(active_tab: :home)
      |> assign(language: language)

    {:ok, socket}
  end

  @impl true
  def handle_event("switch_language", %{"language" => language}, socket) do
    {:noreply,
     socket
     |> redirect(to: "/language-switch?locale=#{language}")
     |> put_flash(
       :info,
       with_locale(language, fn -> gettext("Language switched successfully") end)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white dark:text-white text-gray-900  dark:bg-gray-900 antialiased">
      <div class="w-[90%] flex flex-col md:text-xl gap-1 justify-center items-start m-auto  pt-4">
        <p>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Please select your preferred language") %>
          <% end) %>
        </p>
        <div
          phx-click="switch_language"
          phx-value-language="de"
          id="switch-language-de"
          class={"flex gap-4 cursor-pointer  #{if @language == "de" do "underline-offset-8 underline dark:decoration-white decoration-black " end}"}
        >
          🇩🇪  Deutsch
        </div>
        <div
          phx-click="switch_language"
          phx-value-language="en"
          id="switch-language-en"
          class={"flex gap-4 cursor-pointer  #{if @language == "en" do "underline-offset-8   underline dark:decoration-white decoration-black " end}"}
        >
          🇺🇸 English
        </div>
      </div>
    </div>
    """
  end
end
