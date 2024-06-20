defmodule AniminaWeb.ProfileVisibilityLive do
  @moduledoc """
  User Profile Liveview
  """

  use AniminaWeb, :live_view
  alias Animina.Accounts
  alias Animina.Accounts.BasicUser
  alias Animina.Accounts.Points
  alias Animina.Accounts.User
  alias Animina.GenServers.ProfileViewCredits
  alias Phoenix.PubSub

  @impl true
  def mount(_params, %{"language" => language, "user" => _}, socket) do
    socket =
      socket
      |> assign(language: language)

    current_user =
      socket.assigns.current_user

    subscribe(socket, current_user)

    {
      :ok,
      socket |> assign(active_tab: :profile_visibility)
    }
  end

  defp subscribe(socket, _) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )
    end
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)
      |> Points.humanized_points()

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  def handle_info({:user, current_user}, socket) do
    {:noreply, socket |> assign(current_user: current_user)}
  end

  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
  end

  def handle_event("change_user_state", %{"state" => _state, "action" => action}, socket) do
    case change_user_state(action, socket.assigns.current_user) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(current_user: user)
         |> put_flash(:info, gettext("Profile visibility changed successfully."))}

      {:error, _} ->
        {:noreply, socket |> put_flash(:error, gettext("Profile visibility change failed."))}
    end
  end

  def change_user_state("normalize", user) do
    User.normalize(user)
  end

  def change_user_state("archive", user) do
    User.archive(user)
  end

  def change_user_state("hibernate", user) do
    User.hibernate(user)
  end

  def change_user_state("incognito", user) do
    User.incognito(user)
  end

  def change_user_state(_, user) do
    User.normalize(user)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-5 flex flex-col gap-2 pb-8">
      <p class="text-xl text-white dark:text-white"><%= gettext("Change Profile Visibility") %></p>
      <p class="text-sm text-gray-500">
        <%= gettext("Select And Change the visibility of your profile") %>
      </p>

      <.user_state_cards current_user={@current_user} />
    </div>
    """
  end
end
