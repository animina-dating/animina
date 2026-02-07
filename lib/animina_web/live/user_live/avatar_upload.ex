defmodule AniminaWeb.UserLive.AvatarUpload do
  use AniminaWeb, :live_view

  alias Animina.Moodboard
  alias Animina.Photos

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div
        id="avatar-upload-container"
        class="max-w-2xl mx-auto"
        phx-hook="ImageCropper"
        data-mandatory="true"
        data-aspect-ratio="1:1"
      >
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/users/settings"}>{gettext("Settings")}</.link>
            </li>
            <li>{gettext("Profile Photo")}</li>
          </ul>
        </div>

        <div class="text-center mb-8">
          <.header>
            {gettext("Profile Photo")}
            <:subtitle>{gettext("Upload a photo that shows your face clearly")}</:subtitle>
          </.header>
        </div>

        <%!-- Current Avatar Display --%>
        <div class="flex flex-col items-center mb-8">
          <div class="relative">
            <%= if @avatar && Photos.processed_file_available?(@avatar.state) do %>
              <img
                src={Photos.signed_url(@avatar)}
                alt={gettext("Profile Photo")}
                class="w-32 h-32 rounded-full object-cover border-4 border-base-300"
                data-role="avatar-image"
              />
            <% else %>
              <div
                class="w-32 h-32 rounded-full bg-primary text-primary-content flex items-center justify-center text-4xl font-bold border-4 border-base-300"
                data-role="avatar-placeholder"
              >
                {String.first(@user.display_name)}
              </div>
            <% end %>

            <%!-- Status Badge (hidden during processing since progress indicator shows status) --%>
            <%= if @avatar && @avatar.state != "approved" && !processing?(@avatar.state) do %>
              <div
                class="absolute -bottom-2 left-1/2 -translate-x-1/2 whitespace-nowrap"
                data-role="status-badge"
              >
                <span class={[
                  "badge badge-sm",
                  status_badge_class(@avatar.state)
                ]}>
                  {status_label(@avatar.state, @avatar)}
                </span>
              </div>
            <% end %>
          </div>

          <%!-- Processing Progress Indicator --%>
          <%= if @avatar && processing?(@avatar.state) do %>
            <div class="mt-4 w-full max-w-xs" data-role="processing-progress">
              <div class="flex items-center gap-2 mb-2">
                <span class="loading loading-spinner loading-sm"></span>
                <span class="text-sm font-medium">{status_label(@avatar.state, @avatar)}</span>
              </div>
              <div class="flex gap-1">
                <div
                  class={[
                    "h-1 flex-1 rounded-full transition-all duration-300",
                    if(step_completed?(@avatar.state, 1), do: "bg-primary", else: "bg-base-300")
                  ]}
                  title={gettext("Processing image")}
                >
                </div>
                <div
                  class={[
                    "h-1 flex-1 rounded-full transition-all duration-300",
                    if(step_completed?(@avatar.state, 2), do: "bg-primary", else: "bg-base-300")
                  ]}
                  title={gettext("Analyzing photo")}
                >
                </div>
              </div>
              <p class="text-xs text-base-content/60 mt-2 text-center">
                {gettext("This usually takes 40 seconds")}
              </p>
            </div>
          <% end %>

          <%!-- Error Message Display --%>
          <%= if @avatar && error_state?(@avatar.state) && @avatar.error_message do %>
            <div class="mt-4 w-full max-w-md" data-role="error-message">
              <div class="alert alert-error">
                <.icon name="hero-exclamation-circle" class="h-5 w-5 shrink-0" />
                <span class="text-sm">{@avatar.error_message}</span>
              </div>
            </div>
          <% end %>

          <%!-- Appeal Section --%>
          <%= if @avatar && can_request_appeal?(@avatar.state) do %>
            <div class="mt-6 text-center">
              <p class="text-sm text-base-content/70 mb-3">
                {gettext("Think this was a mistake? You can request a human review.")}
              </p>
              <button
                type="button"
                phx-click="request-appeal"
                class="btn btn-outline btn-sm"
                data-role="request-appeal-button"
              >
                <.icon name="hero-hand-raised" class="h-4 w-4 mr-1" />
                {gettext("Request Human Review")}
              </button>
            </div>
          <% end %>

          <%!-- Appeal Rejected Message --%>
          <%= if @avatar && @avatar.state == "appeal_rejected" do %>
            <div class="mt-6 text-center">
              <div class="alert alert-warning">
                <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
                <span>{gettext("Your appeal was rejected. Please upload a different photo.")}</span>
              </div>
            </div>
          <% end %>

          <%!-- Delete Button --%>
          <%= if @avatar do %>
            <div class="mt-6">
              <button
                type="button"
                phx-click="delete-avatar"
                data-confirm={gettext("Are you sure you want to delete your profile photo?")}
                class="btn btn-ghost btn-sm text-error"
                data-role="delete-avatar-button"
              >
                <.icon name="hero-trash" class="h-4 w-4 mr-1" />
                {gettext("Delete Photo")}
              </button>
            </div>
          <% end %>
        </div>

        <%!-- Upload Form --%>
        <div class="card bg-base-200/50 border border-base-300">
          <div class="card-body">
            <form
              id="avatar-upload-form"
              phx-submit="save"
              phx-change="validate"
              class="space-y-4"
            >
              <div
                class="border-2 border-dashed border-base-300 rounded-lg p-8 text-center hover:border-primary transition-colors cursor-pointer"
                phx-drop-target={@uploads.avatar.ref}
              >
                <.icon name="hero-cloud-arrow-up" class="h-12 w-12 mx-auto text-base-content/40 mb-4" />
                <p class="text-base-content/70 mb-2">
                  {gettext("Drag and drop your photo here, or")}
                </p>
                <label class="btn btn-primary btn-sm cursor-pointer">
                  {gettext("Choose file")}
                  <.live_file_input upload={@uploads.avatar} class="hidden" />
                </label>
                <p class="text-xs text-base-content/50 mt-3">
                  {gettext("JPG, PNG, WEBP or HEIC. Max 6MB.")}
                </p>
              </div>

              <%!-- Upload Preview with Crop Status --%>
              <%= for entry <- @uploads.avatar.entries do %>
                <div class="flex items-center gap-4 p-4 bg-base-100 rounded-lg">
                  <%= if @crop_preview do %>
                    <img
                      src={@crop_preview}
                      alt={gettext("Cropped preview")}
                      class="w-16 h-16 rounded-full object-cover"
                    />
                  <% else %>
                    <.live_img_preview entry={entry} class="w-16 h-16 rounded-lg object-cover" />
                  <% end %>
                  <div class="flex-1 min-w-0">
                    <p class="font-medium text-sm truncate">{entry.client_name}</p>
                    <%= if @crop_data do %>
                      <p class="text-xs text-success flex items-center gap-1 mt-1">
                        <.icon name="hero-check-circle" class="h-4 w-4" />
                        {gettext("Ready to upload")}
                      </p>
                    <% else %>
                      <p class="text-xs text-base-content/60 flex items-center gap-1 mt-1">
                        <span class="loading loading-spinner loading-xs"></span>
                        {gettext("Processing...")}
                      </p>
                    <% end %>
                    <div class="w-full bg-base-300 rounded-full h-2 mt-2">
                      <div
                        class="bg-primary h-2 rounded-full transition-all"
                        style={"width: #{entry.progress}%"}
                      >
                      </div>
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    class="btn btn-ghost btn-sm btn-circle"
                  >
                    <.icon name="hero-x-mark" class="h-5 w-5" />
                  </button>
                </div>

                <%!-- Upload Errors --%>
                <%= for err <- upload_errors(@uploads.avatar, entry) do %>
                  <p class="text-error text-sm">{error_to_string(err)}</p>
                <% end %>
              <% end %>

              <%!-- General Upload Errors --%>
              <%= for err <- upload_errors(@uploads.avatar) do %>
                <p class="text-error text-sm">{error_to_string(err)}</p>
              <% end %>

              <%!-- Submit Button (only enabled when crop is done) --%>
              <%= if length(@uploads.avatar.entries) > 0 do %>
                <button
                  type="submit"
                  class="btn btn-primary w-full"
                  disabled={is_nil(@crop_data)}
                >
                  {gettext("Upload Photo")}
                </button>
              <% end %>
            </form>
          </div>
        </div>

        <%!-- Crop Modal --%>
        <dialog data-cropper-modal class="modal">
          <div class="modal-box max-w-2xl max-h-[90vh]">
            <h3 class="font-bold text-lg mb-2">{gettext("Crop Photo")}</h3>
            <p class="text-sm text-base-content/70 mb-4">
              {gettext("Adjust the square to select the area for your profile photo.")}
            </p>

            <div class="w-full max-h-[60vh] overflow-hidden bg-base-200 rounded-lg">
              <img data-cropper-image src="" alt="" class="max-w-full" />
            </div>

            <div class="modal-action">
              <button
                type="button"
                class="btn btn-ghost"
                data-cropper-action="cancel"
              >
                {gettext("Cancel")}
              </button>
              <button
                type="button"
                class="btn btn-primary"
                data-cropper-action="apply"
              >
                {gettext("Apply Crop")}
              </button>
            </div>
          </div>
          <form method="dialog" class="modal-backdrop">
            <button type="button" data-cropper-action="cancel">close</button>
          </form>
        </dialog>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    avatar = Photos.get_user_avatar_any_state(user.id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Animina.PubSub, "photos:User:#{user.id}")
    end

    socket =
      socket
      |> assign(:page_title, gettext("Profile Photo"))
      |> assign(:user, user)
      |> assign(:avatar, avatar)
      |> assign(:crop_data, nil)
      |> assign(:crop_preview, nil)
      |> allow_upload(:avatar,
        accept: ~w(.jpg .jpeg .png .webp .heic),
        max_entries: 1,
        max_file_size: 6_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    user = socket.assigns.user
    crop_data = socket.assigns.crop_data

    results =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
        Photos.delete_user_avatars(user.id)

        result =
          Photos.upload_photo("User", user.id, path,
            original_filename: entry.client_name,
            content_type: entry.client_type,
            type: "avatar",
            crop_data: crop_data
          )

        # Link avatar to pinned moodboard item
        case result do
          {:ok, photo} ->
            Moodboard.link_avatar_to_pinned_item(user.id, photo.id)

          %Animina.Photos.Photo{} = photo ->
            Moodboard.link_avatar_to_pinned_item(user.id, photo.id)

          _ ->
            :ok
        end

        result
      end)

    socket =
      socket
      |> assign(:crop_data, nil)
      |> assign(:crop_preview, nil)

    handle_upload_results(socket, results)
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    socket =
      socket
      |> cancel_upload(:avatar, ref)
      |> assign(:crop_data, nil)
      |> assign(:crop_preview, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("crop-applied", %{"x" => x, "y" => y, "width" => w, "height" => h}, socket) do
    crop_data = %{x: x, y: y, width: w, height: h}
    {:noreply, assign(socket, :crop_data, crop_data)}
  end

  @impl true
  def handle_event("crop-preview", %{"previewUrl" => preview_url}, socket) do
    {:noreply, assign(socket, :crop_preview, preview_url)}
  end

  @impl true
  def handle_event("crop-cancelled", _params, socket) do
    # Cancel the upload when user cancels cropping (mandatory for avatars)
    socket =
      case socket.assigns.uploads.avatar.entries do
        [entry | _] ->
          socket
          |> cancel_upload(:avatar, entry.ref)
          |> assign(:crop_data, nil)
          |> assign(:crop_preview, nil)

        [] ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("request-appeal", _params, socket) do
    avatar = socket.assigns.avatar
    user = socket.assigns.user

    case Photos.create_appeal(avatar, user) do
      {:ok, %{photo: updated_photo}} ->
        {:noreply, assign(socket, :avatar, updated_photo)}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, gettext("Could not submit appeal. Please try again."))}
    end
  end

  @impl true
  def handle_event("delete-avatar", _params, socket) do
    case Photos.delete_photo(socket.assigns.avatar) do
      {:ok, _deleted_photo} ->
        socket =
          socket
          |> assign(:avatar, nil)
          |> put_flash(:info, gettext("Photo deleted."))

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, gettext("Could not delete photo. Please try again."))}
    end
  end

  @impl true
  def handle_info({:photo_approved, photo}, socket) do
    if photo.type == "avatar" do
      user = socket.assigns.user

      if user.state == "waitlisted" do
        socket =
          socket
          |> put_flash(:info, gettext("Your profile photo has been approved!"))
          |> push_navigate(to: ~p"/users/waitlist")

        {:noreply, socket}
      else
        {:noreply, assign(socket, :avatar, photo)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:photo_state_changed, photo}, socket) do
    if photo.type == "avatar" do
      {:noreply, assign(socket, :avatar, photo)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp status_label("pending", _photo), do: gettext("Pending review")
  defp status_label("processing", _photo), do: gettext("Processing")
  defp status_label("ollama_checking", _photo), do: gettext("Analyzing photo")

  defp status_label("no_face_error", photo) when not is_nil(photo) do
    # Use short label for badge; full message shown separately
    cond do
      photo.error_message && String.contains?(photo.error_message, "animal") ->
        gettext("Animal photo detected")

      photo.error_message && String.contains?(photo.error_message, "multiple") ->
        gettext("Multiple people detected")

      photo.error_message && String.contains?(photo.error_message, "children") ->
        gettext("Photo not allowed")

      true ->
        gettext("No face detected")
    end
  end

  defp status_label("no_face_error", _photo), do: gettext("No face detected")

  defp status_label("error", photo) when not is_nil(photo) do
    error_message_to_label(photo.error_message)
  end

  defp status_label("error", _photo), do: gettext("Upload failed")
  defp status_label("appeal_pending", _photo), do: gettext("Pending moderator review")
  defp status_label("appeal_rejected", _photo), do: gettext("Appeal rejected")
  defp status_label(_, _photo), do: gettext("Processing")

  defp error_message_to_label(nil), do: gettext("Upload failed")

  defp error_message_to_label(msg) do
    content_violation_keywords = ["nudity", "firearm", "hunting", "sexual"]

    cond do
      Enum.any?(content_violation_keywords, &String.contains?(msg, &1)) ->
        gettext("Content violation")

      String.contains?(msg, "attire") ->
        gettext("Attire violation")

      true ->
        gettext("Upload failed")
    end
  end

  defp status_badge_class("error"), do: "badge-error"
  defp status_badge_class("no_face_error"), do: "badge-error"
  defp status_badge_class("appeal_rejected"), do: "badge-error"
  defp status_badge_class("appeal_pending"), do: "badge-info"
  defp status_badge_class(_), do: "badge-warning"

  defp can_request_appeal?("no_face_error"), do: true
  defp can_request_appeal?("error"), do: true
  defp can_request_appeal?(_), do: false

  # Check if photo is in an error state that should show the error message
  defp error_state?("no_face_error"), do: true
  defp error_state?("error"), do: true
  defp error_state?("appeal_rejected"), do: true
  defp error_state?(_), do: false

  # Check if photo is in an active processing state
  defp processing?("pending"), do: true
  defp processing?("processing"), do: true
  defp processing?("ollama_checking"), do: true
  defp processing?(_), do: false

  # Check if a processing step has been completed
  # Step 1: Image processing
  # Step 2: Ollama analysis
  defp step_completed?("pending", _step), do: false
  defp step_completed?("processing", _step), do: false
  defp step_completed?("ollama_checking", step), do: step < 2
  defp step_completed?(_, _step), do: false

  defp handle_upload_results(socket, [{:ok, photo}]) do
    socket =
      socket
      |> assign(:avatar, photo)
      |> put_flash(:info, gettext("Photo uploaded! It will be reviewed shortly."))

    {:noreply, socket}
  end

  defp handle_upload_results(socket, [%Animina.Photos.Photo{} = photo]) do
    socket =
      socket
      |> assign(:avatar, photo)
      |> put_flash(:info, gettext("Photo uploaded! It will be reviewed shortly."))

    {:noreply, socket}
  end

  defp handle_upload_results(socket, [{:error, _reason}]) do
    {:noreply, put_flash(socket, :error, gettext("Upload failed. Please try again."))}
  end

  defp handle_upload_results(socket, []) do
    {:noreply, socket}
  end

  defp error_to_string(:too_large), do: gettext("File is too large (max 6MB)")
  defp error_to_string(:not_accepted), do: gettext("Invalid file type. Please upload an image.")
  defp error_to_string(:too_many_files), do: gettext("Only one file at a time")
  defp error_to_string(_), do: gettext("Upload error")
end
