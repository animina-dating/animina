defmodule AniminaWeb.ProfileVisibilityLive do
  @moduledoc """
  User Profile Liveview
  """

  use AniminaWeb, :live_view
  alias Animina.Accounts.Photo
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
    if current_user.state in user_states_to_be_auto_logged_out() do
      {:noreply,
       socket
       |> push_navigate(to: "/auth/user/sign-out?auto_log_out=#{current_user.state}")}
    else
      {:noreply, socket |> assign(:current_user, current_user)}
    end
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

  @impl true
  def handle_event("change_user_state", %{"state" => _state, "action" => action}, socket) do
    maybe_change_user_state(
      action,
      socket,
      socket.assigns.current_user.profile_photo,
      Photo.user_has_an_about_me_story_with_image?(socket.assigns.current_user)
    )
  end

  @impl true
  def handle_event("redirect_to_delete_account_page", _params, socket) do
    {:noreply, socket |> push_navigate(to: "/my/profile/delete_account")}
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

  def change_user_state(_, user) do
    User.normalize(user)
  end

  defp maybe_change_user_state("normalize", socket, nil, false) do
    {:noreply,
     socket
     |> put_flash(
       :error,
       with_locale(socket.assigns.language, fn ->
         gettext("You need to have a profile photo and a photo for your about me story
      to change your profile visibility.")
       end)
     )}
  end

  defp maybe_change_user_state("normalize", socket, nil, true) do
    {:noreply,
     socket
     |> put_flash(
       :error,
       with_locale(socket.assigns.language, fn ->
         gettext("You need to have a profile photo to change your profile visibility.")
       end)
     )}
  end

  defp maybe_change_user_state("normalize", socket, _profile_photo, false) do
    {:noreply,
     socket
     |> put_flash(
       :error,
       with_locale(socket.assigns.language, fn ->
         gettext(
           "You need to have a photo for your about me story to change your profile visibility."
         )
       end)
     )}
  end

  defp maybe_change_user_state("normalize", socket, _profile_photo, true) do
    case change_user_state("normalize", socket.assigns.current_user) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(current_user: user)
         |> put_flash(
           :info,
           with_locale(socket.assigns.language, fn ->
             gettext("Profile visibility changed successfully.")
           end)
         )}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           with_locale(socket.assigns.language, fn ->
             gettext("Profile visibility change failed.")
           end)
         )}
    end
  end

  defp maybe_change_user_state("hibernate", socket, _profile_photo, _) do
    case change_user_state("hibernate", socket.assigns.current_user) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(current_user: user)
         |> put_flash(
           :info,
           with_locale(socket.assigns.language, fn ->
             gettext("Profile visibility changed successfully.")
           end)
         )}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           with_locale(socket.assigns.language, fn ->
             gettext("Profile visibility change failed.")
           end)
         )}
    end
  end

  defp user_states_to_be_auto_logged_out do
    [
      :under_investigation,
      :banned,
      :archived
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-5 flex flex-col gap-2 pb-8">
      <p class="text-xl text-black dark:text-white">
        <%= with_locale(@language, fn -> %>
          <%= gettext("Change Profile Visibility") %>
        <% end) %>
      </p>
      <p class="text-sm text-gray-500">
        <%= with_locale(@language, fn -> %>
          <%= gettext("Select And Change the visibility of your profile") %>
        <% end) %>
      </p>

      <.user_state_cards language={@language} current_user={@current_user} />
    </div>
    """
  end
end
