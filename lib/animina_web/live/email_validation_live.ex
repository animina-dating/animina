defmodule AniminaWeb.EmailValidationLive do
  use AniminaWeb, :live_view
  alias Animina.UserEmail
  alias Animina.Accounts.User

  @impl true
  def mount(_, %{"language" => language} = _session, socket) do
    socket =
      socket
      |> assign(active_tab: :home)
      |> assign(language: language)

    {:ok, socket}
  end

  @impl true

  def handle_event("verify_pin", %{"user" => %{"pin" => ""}}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Please enter the PIN")}
  end

  def handle_event("verify_pin", %{"user" => %{"pin" => pin}}, socket) do
    case String.to_integer(pin) == socket.assigns.current_user.confirmation_pin do
      true ->
        correct_pin_socket(socket)

      _ ->
        incorrect_pin_socket(socket)
    end
  end

  def handle_event("resend_pin", _params, socket) do
    UserEmail.send_pin(socket.assigns.current_user)

    {:noreply,
     socket
     |> put_flash(
       :info,
       with_locale(socket.assigns.language, fn -> gettext("Email Sent Successfully") end)
     )}
  end

  defp incorrect_pin_socket(socket) do
    if socket.assigns.current_user.confirmation_pin_attempts == 2 do
      User.destroy(socket.assigns.current_user)

      {:noreply,
       socket
       |> push_navigate(to: "/")
       |> put_flash(
         :error,
         with_locale(socket.assigns.language, fn ->
           gettext("Account Deleted , Kindly Sign Up Again")
         end)
       )}
    else
      User.update(socket.assigns.current_user, %{
        confirmation_pin_attempts: socket.assigns.current_user.confirmation_pin_attempts + 1
      })

      {:noreply,
       socket
       |> push_navigate(to: "/my/email-validation")
       |> put_flash(
         :error,
         with_locale(socket.assigns.language, fn -> gettext("Wrong PIN Entered !") end)
       )}
    end
  end

  defp correct_pin_socket(socket) do
    User.update(socket.assigns.current_user, %{confirmed_at: DateTime.utc_now()})

    {:noreply,
     socket
     |> push_navigate(to: "/my/potential-partner")
     |> put_flash(
       :info,
       with_locale(socket.assigns.language, fn -> gettext("Account Confirmed Successfully") end)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white dark:text-white text-gray-900  dark:bg-gray-900 antialiased">
      <div
        :if={@current_user.confirmation_pin_attempts == 2}
        class="bg-red-400 w-[60%] m-auto text-center p-4 text-white rounded-md"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("You have only one attempt remaining before we delete your account") %>
        <% end) %>

        <%= with_locale(@language, fn -> %>
          <%= gettext("Make sure you enter the right pin sent to your email") %>
        <% end) %>
      </div>
      <div class="w-[90%] flex flex-col  gap-3 justify-center items-center m-auto text-center pt-12">
        <p>
          <%= with_locale(@language, fn -> %>
            <%= gettext("We just send you an email to") %>
          <% end) %>
          <%= @current_user.email %>
          <%= with_locale(@language, fn -> %>
            <%= gettext("with a 6 digit PIN.") %>
          <% end) %>
        </p>
        <p>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Please enter the PIN to verify your email address.") %>
          <% end) %>
        </p>

        <p>
          <%= with_locale(@language, fn -> %>
            <%= gettext("You have") %> <%= 3 - @current_user.confirmation_pin_attempts %> <%= gettext(
              " attempts remaining !"
            ) %>
          <% end) %>
        </p>

        <form phx-submit="verify_pin" class="w-[60%] flex flex-col justify-center items-center gap-3">
          <input
            type="number"
            name="user[pin]"
            class="block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1  focus:ring-2 focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 "
          />

          <button class="flex hover:scale-105 transition-all ease-in-out duration-500 mx-auto justify-center rounded-md bg-indigo-600 dark:bg-indigo-500 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 ">
            <%= with_locale(@language, fn -> %>
              <%= gettext("Verify My Account") %>
            <% end) %>
          </button>

          <p
            phx-click="resend_pin"
            class="block text-sm leading-6 text-blue-600 transition-all duration-500 ease-in-out hover:text-blue-500 dark:hover:text-blue-500 hover:cursor-pointer hover:underline"
          >
            <%= with_locale(@language, fn -> %>
              <%= gettext("Did not receive the email? Click here to resend.") %>
            <% end) %>
          </p>
        </form>
      </div>
    </div>
    """
  end
end
