defmodule AniminaWeb.TooSuccessFulLive do
  use AniminaWeb, :live_view

  @impl true
  def mount(_, _session, socket) do
    socket =
      socket
      |> assign(active_tab: :home)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white dark:text-white text-gray-900  dark:bg-gray-900 antialiased">
      <div class="w-[90%] flex flex-col md:text-xl gap-1 justify-center items-center m-auto text-center pt-12">
        <p>
          <%= gettext("Hi") %> <%= @current_user.name %> <%= gettext(
            "we currently have too many new registrations to handle. That is a good problem for us to have but for you it means that you just landed on a waiting list. We'll send you an email once our systems are ready. In case this is a spike we are talking minutes or hours. In case we need to add new server hardware this means days. Thank you for your patients. Viele Grüße Stefan Wintermeyer PS: Do not hesitate to complain by email to "
          ) %>
          <span>
            <a href="mailto:stefan@wintermeyer.de" class="text-blue-500 underline">
              stefan@wintermeyer.de
            </a>
          </span>
          <%= gettext("The buck stops in my inbox.") %>
        </p>
      </div>
    </div>
    """
  end
end
