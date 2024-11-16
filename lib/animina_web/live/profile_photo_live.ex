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
  def mount(_params, %{"language" => language} = _session, socket) do
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
      |> assign(language: language)
      |> assign(uploading: false)
      |> assign(preview_url: nil)
      |> assign(page_title: with_locale(language, fn -> gettext("Upload a profile photo") end))
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
     |> put_flash(
       :info,
       with_locale(socket.assigns.language, fn ->
         gettext("Profile photo deleted successfully")
       end)
     )}
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
        <h2 class="text-xl font-bold dark:text-white">
          <%= with_locale(@language, fn -> %>
            <%= gettext("Upload an avatar photo for your account") %>
          <% end) %>
        </h2>
      <% else %>
        <h2 class="text-xl font-bold dark:text-white">
          <%= with_locale(@language, fn -> %>
            <%= gettext("Update your avatar photo for your account") %>
          <% end) %>
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
            <%= with_locale(@language, fn -> %>
              <%= gettext("Upload or drag & drop your photo file JPG, JPEG, PNG") %>
            <% end) %>
          </p>
          <p if={@current_user.profile_photo != nil} class="text-sm dark:text-white">
            <%= with_locale(@language, fn -> %>
              <%= gettext("Update your profile photo & drop your photo file JPG, JPEG, PNG") %>
            <% end) %>
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

            <div class="flex flex-col justify-center flex-1 dark:text-white">
              <p><%= entry.client_name %></p>
              <p class="text-sm text-gray-600 dark:text-gray-100">
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
                  <%= with_locale(@language, fn -> %>
                    <%= gettext("Cancel") %>
                  <% end) %>
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
                  <p><%= error_to_string(err, @language) %></p>
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
            <%= with_locale(@language, fn -> %>
              <%= gettext("Current Photo") %>
            <% end) %>
          </p>
          <div class="md:w-[300px] w-[100%] relative">
            <div
              class="absolute z-50 top-4 right-2 h-[40px] text-white w-[40px] bg-red-500 p-2 rounded-md "
              phx-click="delete_photo"
              data-confirm={
                with_locale(@language, fn ->
                  gettext(
                    "Are you sure you want to delete your profile photo ? This will hibernate your account until you upload another photo"
                  )
                end)
              }
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                aria-hidden="true"
              >
                <path
                  fill-rule="evenodd"
                  d="M8.75 1A2.75 2.75 0 006 3.75v.443c-.795.077-1.584.176-2.365.298a.75.75 0 10.23 1.482l.149-.022.841 10.518A2.75 2.75 0 007.596 19h4.807a2.75 2.75 0 002.742-2.53l.841-10.52.149.023a.75.75 0 00.23-1.482A41.03 41.03 0 0014 4.193V3.75A2.75 2.75 0 0011.25 1h-2.5zM10 4c.84 0 1.673.025 2.5.075V3.75c0-.69-.56-1.25-1.25-1.25h-2.5c-.69 0-1.25.56-1.25 1.25v.325C8.327 4.025 9.16 4 10 4zM8.58 7.72a.75.75 0 00-1.5.06l.3 7.5a.75.75 0 101.5-.06l-.3-7.5zm4.34.06a.75.75 0 10-1.5-.06l-.3 7.5a.75.75 0 101.5.06l.3-7.5z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>

            <img
              class="object-cover md:h-200  drop-shadow border md:w-[300px] w-[100%] rounded-lg"
              src={Photo.get_optimized_photo_to_use(@current_user.profile_photo, :normal)}
            />
          </div>
        </div>

        <div>
          <%= submit(with_locale(@language, fn -> gettext("Upload") end),
            phx_disable_with: with_locale(@language, fn -> gettext("Uploading...") end),
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

  defp error_to_string(:too_large, language),
    do: with_locale(language, fn -> gettext("Too large") end)

  defp error_to_string(:not_accepted, language),
    do: with_locale(language, fn -> gettext("You have selected an unacceptable file type") end)

  defp error_to_string(:too_many_files, language),
    do: with_locale(language, fn -> gettext("You have selected too many files") end)

  defp error_to_string(_, language),
    do:
      with_locale(language, fn ->
        gettext("Something went wrong uploading your photo. Try again")
      end)

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end
end
