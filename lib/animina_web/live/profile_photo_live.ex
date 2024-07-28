defmodule AniminaWeb.ProfilePhotoLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Photo
  alias Animina.Accounts.User
  alias Animina.GenServers.ProfileViewCredits
  alias Animina.Traits.UserFlags
  alias AshPhoenix.Form
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )
    end

    update_last_registration_page_visited(socket.assigns.current_user, "/my/profile-photo")

    socket =
      socket
      |> assign(active_tab: :home)
      |> assign(attachment: nil)
      |> assign(uploading: false)
      |> assign(preview_url: nil)
      |> assign(page_title: gettext("Upload a profile photo"))
      |> allow_upload(:photos, accept: ~w(.jpg .jpeg .png), max_entries: 1, id: "photo_file")
      |> assign(
        :form,
        Form.for_create(Photo, :create, domain: Accounts, as: "photo")
      )

    {:ok, socket}
  end

  defp update_last_registration_page_visited(user, page) do
    {:ok, _} =
      User.update_last_registration_page_visited(user, %{last_registration_page_visited: page})
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)

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
      {:noreply,
       socket
       |> assign(current_user: current_user)}
    end
  end

  @impl true
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
  def handle_event("validate_photo", %{"photo" => params}, socket) do
    form = Form.validate(socket.assigns.form, params, errors: true)

    {:noreply, socket |> assign(:form, form)}
  end

  @impl true
  def handle_event("submit_photo", %{"photo" => params}, socket) do
    consume_uploaded_entries(socket, :photos, fn %{path: path}, entry ->
      filename = entry.uuid <> "." <> ext(entry)

      dest =
        Path.join(Application.app_dir(:animina, "priv/static/uploads"), Path.basename(filename))

      File.cp!(path, dest)

      {:ok,
       %{
         "filename" => filename,
         "original_filename" => entry.client_name,
         "ext" => ext(entry),
         "mime" => entry.client_type,
         "size" => entry.client_size
       }}
    end)
    |> case do
      [] ->
        {:noreply, socket}

      [%{} = file] ->
        params = Map.merge(params, file)
        form = Form.validate(socket.assigns.form, params, errors: true)

        Photo.destroy(socket.assigns.current_user.profile_photo)

        with [] <- Form.errors(form), {:ok, _photo} <- Form.submit(form, params: params) do
          {:noreply,
           socket
           |> assign(:errors, [])
           |> assign(
             :form,
             Form.for_create(Photo, :create, domain: Accounts, as: "photo")
           )
           |> push_navigate(to: redirect_url_if_user_has_flags(socket.assigns.current_user))}
        else
          {:error, form} ->
            {:noreply, socket |> assign(:form, form)}

          errors ->
            {:noreply, socket |> assign(:errors, errors)}
        end
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref, "value" => _value}, socket) do
    {:noreply,
     socket
     |> cancel_upload(:photos, ref)
     |> assign(
       :form,
       Form.for_create(Photo, :create, domain: Accounts, as: "photo")
     )}
  end

  @impl true
  def handle_event("delete_photo", _, socket) do
    photo = socket.assigns.current_user.profile_photo

    Photo.destroy(photo)

    current_user = User.by_id!(socket.assigns.current_user.id)

    {:noreply,
     socket
     |> assign(current_user: current_user)
     |> put_flash(:info, gettext("Profile photo deleted successfully"))}
  end

  defp user_states_to_be_auto_logged_out do
    [
      :under_investigation,
      :banned,
      :archived
    ]
  end

  defp redirect_url_if_user_has_flags(current_user) do
    if get_user_flags(current_user) == [] do
      "/my/flags/white"
    else
      "/#{current_user.username}"
    end
  end

  defp get_user_flags(current_user) do
    case UserFlags.by_user_id(current_user.id) do
      {:ok, traits} ->
        traits

      _ ->
        []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-5 space-y-10">
      <%= if @current_user.profile_photo == nil do %>
        <.notification_box
          title={gettext("Hello %{name}!", name: @current_user.name)}
          message={gettext("To complete your profile upload a profile photo")}
        />
      <% else %>
        <.notification_box
          title={gettext("Hello %{name}!", name: @current_user.name)}
          message={gettext("Update your profile photo")}
        />
      <% end %>

      <%= if @current_user.profile_photo == nil do %>
        <h2 class="text-xl dark:text-white font-bold">
          <%= gettext("Upload an avatar photo for your account") %>
        </h2>
      <% else %>
        <h2 class="text-xl dark:text-white font-bold">
          <%= gettext("Update your avatar photo for your account") %>
        </h2>
      <% end %>

      <.form
        :let={f}
        for={@form}
        class="space-y-6"
        phx-change="validate_photo"
        phx-submit="submit_photo"
      >
        <.live_file_input type="file" accept="image/*" upload={@uploads.photos} class="hidden" />

        <%= text_input(f, :user_id, type: :hidden, value: @current_user.id) %>

        <div
          :if={Enum.count(@uploads.photos.entries) == 0}
          id={"photo-#{@uploads.photos.ref}"}
          phx-click={JS.dispatch("click", to: "##{@uploads.photos.ref}", bubbles: false)}
          phx-drop-target={@uploads.photos.ref}
          for={@uploads.photos.ref}
          data-upload-target="photos"
          data-input={@uploads.photos.ref}
          class="flex flex-col items-center w-full px-6 py-8 mx-auto text-center border-2 border-gray-300 border-dashed rounded-md cursor-pointer dark:bg-gray-700 bg-gray-50"
        >
          <.icon name="hero-cloud-arrow-up" class="w-8 h-8 mb-4 text-gray-500 dark:text-gray-400" />

          <p if={@current_user.profile_photo == nil} class="text-sm dark:text-white">
            <%= gettext("Upload or drag & drop your photo file JPG, JPEG, PNG") %>
          </p>
          <p if={@current_user.profile_photo != nil} class="text-sm dark:text-white">
            <%= gettext("Update your profile photo & drop your photo file JPG, JPEG, PNG") %>
          </p>
        </div>

        <%= for entry <- @uploads.photos.entries do %>
          <%= text_input(f, :filename, type: :hidden, value: entry.uuid <> "." <> ext(entry)) %>
          <%= text_input(f, :original_filename, type: :hidden, value: entry.client_name) %>
          <%= text_input(f, :ext, type: :hidden, value: ext(entry)) %>
          <%= text_input(f, :mime, type: :hidden, value: entry.client_type) %>
          <%= text_input(f, :size, type: :hidden, value: entry.client_size) %>

          <div class="flex space-x-8">
            <.live_img_preview class="inline-block object-cover w-32 h-32 rounded-md" entry={entry} />

            <div class="flex flex-col dark:text-white justify-center flex-1">
              <p><%= entry.client_name %></p>
              <p class="text-sm dark:text-gray-100 text-gray-600">
                <%= Size.humanize!(entry.client_size, output: :string) %>
              </p>

              <div class="mt-4">
                <button
                  type="button"
                  class="flex w-24 justify-center rounded-md border border-red-600 bg-red-100 px-3 py-1.5 text-sm font-semibold shadow-none leading-6 text-red-600 hover:bg-red-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-600"
                  phx-click="cancel_upload"
                  phx-value-ref={entry.ref}
                  aria-label="cancel"
                >
                  <%= gettext("Cancel") %>
                </button>
              </div>
            </div>
          </div>

          <div
            :if={Enum.count(upload_errors(@uploads.photos, entry))}
            class="mb-4 danger"
            role="alert"
          >
            <ul class="error-messages">
              <%= for err <- upload_errors(@uploads.photos, entry) do %>
                <li>
                  <p><%= error_to_string(err) %></p>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>

        <div
          :if={@current_user.profile_photo != nil && @uploads.photos.entries == []}
          class="w-full space-y-2"
        >
          <p class="block text-sm font-medium leading-6 text-gray-900 dark:text-white">
            <%= gettext("Current Photo") %>
          </p>
          <div class="w-[100%] h-200 relative">
            <p
              data-confirm={gettext("Are you sure you want to delete this photo?")}
              phx-click="delete_photo"
              class="bg-red-500 cursor-pointer text-white absolute right-4 top-4 z-10 md:w-[50px] md:h-[50px] w-[30px] h-[30px] flex justify-center items-center rounded-md"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
                class="p-2"
              >
                <path
                  fill-rule="evenodd"
                  d="M16.5 4.478v.227a48.816 48.816 0 013.878.512.75.75 0 11-.256 1.478l-.209-.035-1.005 13.07a3 3 0 01-2.991 2.77H8.084a3 3 0 01-2.991-2.77L4.087 6.66l-.209.035a.75.75 0 01-.256-1.478A48.567 48.567 0 017.5 4.705v-.227c0-1.564 1.213-2.9 2.816-2.951a52.662 52.662 0 013.369 0c1.603.051 2.815 1.387 2.815 2.951zm-6.136-1.452a51.196 51.196 0 013.273 0C14.39 3.05 15 3.684 15 4.478v.113a49.488 49.488 0 00-6 0v-.113c0-.794.609-1.428 1.364-1.452zm-.355 5.945a.75.75 0 10-1.5.058l.347 9a.75.75 0 101.499-.058l-.346-9zm5.48.058a.75.75 0 10-1.498-.058l-.347 9a.75.75 0 001.5.058l.345-9z"
                  clip-rule="evenodd"
                />
              </svg>
            </p>

            <img
              class="object-cover h-[100%]  drop-shadow border w-[100%] rounded-lg"
              src={Photo.get_optimized_photo_to_use(@current_user.profile_photo, :normal)}
            />
          </div>
        </div>

        <div>
          <%= submit(gettext("Upload"),
            class:
              "flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@uploads.photos.entries == [],
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                ),
            disabled: @uploads.photos.entries == []
          ) %>
        </div>
      </.form>
    </div>
    """
  end

  defp error_to_string(:too_large), do: gettext("Too large")
  defp error_to_string(:not_accepted), do: gettext("You have selected an unacceptable file type")
  defp error_to_string(:too_many_files), do: gettext("You have selected too many files")

  defp error_to_string(_),
    do: gettext("Something went wrong uploading your photo. Try again")

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end
end
