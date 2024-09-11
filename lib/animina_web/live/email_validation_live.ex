defmodule AniminaWeb.EmailValidationLive do
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
  def render(assigns) do
    ~H"""
    <div class="bg-white dark:text-white text-gray-900  dark:bg-gray-900 antialiased">
      <div class="w-[90%] flex flex-col md:text-xl gap-1 justify-center items-center m-auto text-center pt-12">
        <p>
          <%= gettext("We just send you an email to") %> <%= @current_user.email %> <%= gettext(
            "with a confirmation link. Please click it to confirm your email address. The email is already on its way to you. Please check your spam folder in case it doesn't show up in your inbox"
          ) %>
        </p>
      </div>
    </div>
    """
  end
end
