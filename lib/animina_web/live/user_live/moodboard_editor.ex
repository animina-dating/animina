defmodule AniminaWeb.UserLive.MoodboardEditor do
  @moduledoc """
  LiveView for editing a user's moodboard.

  Features:
  - Drag/drop reordering (SortableJS hook)
  - Add item modal (select type: photo, story, combined)
  - Photo upload with progress
  - Markdown story editor with preview
  - Delete with confirmation
  """

  use AniminaWeb, :live_view

  alias Animina.Moodboard
  alias AniminaWeb.ColumnToggle
  alias AniminaWeb.Helpers.ColumnPreferences

  import AniminaWeb.MoodboardComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="moodboard-editor-container" phx-hook="DeviceType">
        <!-- Header -->
        <div class="flex items-center justify-between mb-8">
          <div class="breadcrumbs text-sm">
            <ul>
              <li>
                <.link navigate={~p"/users/settings"}>{gettext("Settings")}</.link>
              </li>
              <li>{gettext("Moodboard")}</li>
            </ul>
          </div>

          <.link navigate={~p"/moodboard/#{@user.id}"} class="btn btn-ghost btn-sm">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4 mr-1"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
              />
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
              />
            </svg>
            {gettext("View Moodboard")}
          </.link>
        </div>

        <h1 class="text-3xl font-bold mb-2">{gettext("Edit Moodboard")}</h1>
        <p class="text-base-content/60 mb-8">
          {gettext("Add photos and text to present yourself. Drag to reorder.")}
        </p>
        
    <!-- Add item buttons -->
        <div class="flex flex-wrap gap-2 mb-8">
          <button
            type="button"
            class={["btn btn-primary", !@about_me_complete? && "btn-disabled"]}
            phx-click="show-add-modal"
            phx-value-type="photo"
            disabled={!@about_me_complete?}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 mr-2"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
            {gettext("Add Photo")}
          </button>
          <button
            type="button"
            class={["btn btn-secondary", !@about_me_complete? && "btn-disabled"]}
            phx-click="show-add-modal"
            phx-value-type="story"
            disabled={!@about_me_complete?}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 mr-2"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
            {gettext("Add Text")}
          </button>
          <button
            type="button"
            class={["btn btn-outline", !@about_me_complete? && "btn-disabled"]}
            phx-click="show-add-modal"
            phx-value-type="combined"
            disabled={!@about_me_complete?}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 mr-2"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
              />
            </svg>
            {gettext("Photo + Text")}
          </button>
        </div>
        
    <!-- Empty state -->
        <div :if={Enum.empty?(@items)} class="text-center py-16 bg-base-200 rounded-lg">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-16 w-16 mx-auto text-base-content/30 mb-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1.5"
              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
          <h2 class="text-xl font-semibold text-base-content/60">
            {gettext("Your moodboard is empty")}
          </h2>
          <p class="text-base-content/50 mt-2">
            {gettext("Click a button above to add your first item.")}
          </p>
        </div>
        
    <!-- Hint: encourage adding more items -->
        <div
          :if={length(@items) == 1}
          class="bg-info/10 border border-info/30 rounded-xl p-5 text-center mb-8"
        >
          <p class="text-base-content font-medium">
            {gettext("Profiles with more than one moodboard item are a lot more popular.")}
          </p>
          <p class="text-base-content/70 mt-1 text-sm">
            {gettext(
              "Write about your last trip or a hobby. Share a cooking recipe or a photo of your dog."
            )}
          </p>
        </div>
        
    <!-- Moodboard items (sortable) - Editorial card layout -->
        <div :if={!Enum.empty?(@items)}>
          <ColumnToggle.column_toggle columns={@columns} />
          
    <!-- Single column layout -->
          <div
            :if={@columns == 1}
            id="moodboard-items"
            phx-hook="SortableList"
            data-list_id="moodboard"
            class="pt-4 max-w-xl mx-auto space-y-8"
          >
            <%= for item <- @items do %>
              <.editorial_card_editor
                item={item}
                editing_item_id={@editing_item && @editing_item.id}
                edit_content={@edit_content}
              />
            <% end %>
          </div>
          
    <!-- Multi-column layout (2 or 3 columns) -->
          <div
            :if={@columns > 1}
            id="moodboard-columns"
            class={[
              "flex gap-4 md:gap-5 lg:gap-6 pt-4",
              @columns == 2 && "flex-row",
              @columns == 3 && "flex-row"
            ]}
          >
            <%= for {column_items, placeholders, col_idx} <- distribute_with_placeholders(@items, @columns) do %>
              <div
                id={"moodboard-column-#{col_idx}"}
                phx-hook="SortableList"
                data-multi-column="true"
                data-column-count={@columns}
                data-column-index={col_idx}
                data-group-id="moodboard"
                class="flex-1 flex flex-col gap-4 md:gap-5 lg:gap-6"
              >
                <%= for item <- column_items do %>
                  <.editorial_card_editor
                    item={item}
                    editing_item_id={@editing_item && @editing_item.id}
                    edit_content={@edit_content}
                  />
                <% end %>
                <!-- Placeholder cards for empty columns -->
                <%= for variant <- placeholders do %>
                  <.placeholder_card variant={variant} />
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Add Item Modal -->
        <dialog :if={@show_modal} id="add-item-modal" class="modal modal-open">
          <div
            id="moodboard-photo-cropper"
            class="modal-box max-w-2xl"
            phx-hook="ImageCropper"
            data-mandatory="false"
            data-aspect-ratio={@aspect_ratio}
            data-orientation={@orientation}
          >
            <h3 class="font-bold text-lg mb-4">
              {modal_title(@modal_type)}
            </h3>

            <form method="dialog">
              <button
                type="button"
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
                phx-click="close-modal"
              >
                ✕
              </button>
            </form>

            <form phx-submit="save-item" phx-change="validate-item">
              <!-- Photo upload -->
              <div :if={@modal_type in ["photo", "combined"]} class="mb-4">
                <!-- Aspect Ratio Selection -->
                <div class="mb-4">
                  <label class="label">
                    <span class="label-text">{gettext("Aspect Ratio")}</span>
                  </label>
                  <div class="flex flex-wrap gap-2">
                    <label class={[
                      "btn btn-sm",
                      @aspect_ratio == "original" && "btn-primary",
                      @aspect_ratio != "original" && "btn-outline"
                    ]}>
                      <input
                        type="radio"
                        name="aspect_ratio"
                        value="original"
                        checked={@aspect_ratio == "original"}
                        phx-click="set-aspect-ratio"
                        phx-value-ratio="original"
                        class="hidden"
                      />
                      {gettext("Original")}
                    </label>
                    <label class={[
                      "btn btn-sm",
                      @aspect_ratio == "16:9" && "btn-primary",
                      @aspect_ratio != "16:9" && "btn-outline"
                    ]}>
                      <input
                        type="radio"
                        name="aspect_ratio"
                        value="16:9"
                        checked={@aspect_ratio == "16:9"}
                        phx-click="set-aspect-ratio"
                        phx-value-ratio="16:9"
                        class="hidden"
                      /> 16:9
                    </label>
                    <label class={[
                      "btn btn-sm",
                      @aspect_ratio == "4:3" && "btn-primary",
                      @aspect_ratio != "4:3" && "btn-outline"
                    ]}>
                      <input
                        type="radio"
                        name="aspect_ratio"
                        value="4:3"
                        checked={@aspect_ratio == "4:3"}
                        phx-click="set-aspect-ratio"
                        phx-value-ratio="4:3"
                        class="hidden"
                      /> 4:3
                    </label>
                    <label class={[
                      "btn btn-sm",
                      @aspect_ratio == "1:1" && "btn-primary",
                      @aspect_ratio != "1:1" && "btn-outline"
                    ]}>
                      <input
                        type="radio"
                        name="aspect_ratio"
                        value="1:1"
                        checked={@aspect_ratio == "1:1"}
                        phx-click="set-aspect-ratio"
                        phx-value-ratio="1:1"
                        class="hidden"
                      />
                      {gettext("Square")}
                    </label>
                  </div>
                </div>
                
    <!-- Orientation Selection (only shown for non-original, non-square ratios) -->
                <div :if={@aspect_ratio not in ["original", "1:1"]} class="mb-4">
                  <label class="label">
                    <span class="label-text">{gettext("Orientation")}</span>
                  </label>
                  <div class="flex gap-2">
                    <label class={[
                      "btn btn-sm",
                      @orientation == "landscape" && "btn-primary",
                      @orientation != "landscape" && "btn-outline"
                    ]}>
                      <input
                        type="radio"
                        name="orientation"
                        value="landscape"
                        checked={@orientation == "landscape"}
                        phx-click="set-orientation"
                        phx-value-orientation="landscape"
                        class="hidden"
                      />
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4 mr-1"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <rect x="2" y="5" width="20" height="14" rx="2" stroke-width="2" />
                      </svg>
                      {gettext("Landscape")}
                    </label>
                    <label class={[
                      "btn btn-sm",
                      @orientation == "portrait" && "btn-primary",
                      @orientation != "portrait" && "btn-outline"
                    ]}>
                      <input
                        type="radio"
                        name="orientation"
                        value="portrait"
                        checked={@orientation == "portrait"}
                        phx-click="set-orientation"
                        phx-value-orientation="portrait"
                        class="hidden"
                      />
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-4 w-4 mr-1"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <rect x="5" y="2" width="14" height="20" rx="2" stroke-width="2" />
                      </svg>
                      {gettext("Portrait")}
                    </label>
                  </div>
                </div>

                <label class="label">
                  <span class="label-text">{gettext("Photo")}</span>
                </label>

                <div
                  class="border-2 border-dashed border-base-300 rounded-lg p-8 text-center hover:border-primary transition-colors"
                  phx-drop-target={@uploads.photo.ref}
                >
                  <.live_file_input upload={@uploads.photo} class="hidden" id="photo-upload-input" />

                  <%= for entry <- @uploads.photo.entries do %>
                    <div class="mb-4">
                      <%= if @crop_preview do %>
                        <img
                          src={@crop_preview}
                          alt={gettext("Cropped preview")}
                          class="max-w-xs mx-auto rounded-lg"
                        />
                        <p class="text-xs text-success flex items-center justify-center gap-1 mt-2">
                          <.icon name="hero-check-circle" class="h-4 w-4" />
                          {crop_success_message(@aspect_ratio)}
                        </p>
                      <% else %>
                        <.live_img_preview entry={entry} class="max-w-xs mx-auto rounded-lg" />
                      <% end %>
                      <div class="w-full max-w-xs mx-auto mt-2 bg-base-300 rounded-full h-2">
                        <div class="bg-primary h-2 rounded-full" style={"width: #{entry.progress}%"} />
                      </div>
                      <button
                        type="button"
                        class="btn btn-ghost btn-xs mt-2"
                        phx-click="cancel-upload"
                        phx-value-ref={entry.ref}
                      >
                        {gettext("Remove")}
                      </button>
                    </div>
                  <% end %>

                  <div :if={Enum.empty?(@uploads.photo.entries)}>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-12 w-12 mx-auto text-base-content/30 mb-2"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="1.5"
                        d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                      />
                    </svg>
                    <p class="text-base-content/60">
                      {gettext("Drag and drop or click to upload")}
                    </p>
                    <p class="text-sm text-base-content/40">
                      {gettext("JPG, PNG, WebP, HEIC up to 6MB")}
                    </p>
                    <div class="flex flex-wrap gap-2 justify-center mt-4">
                      <label for="photo-upload-input" class="btn btn-primary btn-sm cursor-pointer">
                        {gettext("Choose File")}
                      </label>
                      <label
                        for="photo-upload-input"
                        id="take-photo-btn"
                        class="btn btn-secondary btn-sm cursor-pointer"
                        phx-hook="CameraCapture"
                        data-input-id="photo-upload-input"
                        data-capture="environment"
                      >
                        <.icon name="hero-camera" class="h-4 w-4" />
                        {gettext("Take Photo")}
                      </label>
                    </div>
                  </div>
                </div>

                <%= for err <- upload_errors(@uploads.photo) do %>
                  <p class="text-error text-sm mt-1">{upload_error_message(err)}</p>
                <% end %>
              </div>
              
    <!-- Story editor -->
              <div :if={@modal_type in ["story", "combined"]} class="mb-4">
                <label class="label">
                  <span class="label-text">{gettext("Text")}</span>
                </label>

                <div
                  id="add-story-editor"
                  phx-hook="MarkdownEditor"
                  phx-update="ignore"
                  data-initial-value={@story_content}
                  data-max-length="2000"
                  data-input-name="story_content"
                  data-placeholder={gettext("Write your text here...")}
                >
                  <input type="hidden" name="story_content" value={@story_content} />
                  <p class="text-xs text-base-content/50 mt-2">
                    <span data-char-counter>{String.length(@story_content || "")}/2000</span>
                  </p>
                </div>
              </div>

              <div class="modal-action">
                <button type="button" class="btn" phx-click="close-modal">
                  {gettext("Cancel")}
                </button>
                <button
                  type="submit"
                  class="btn btn-primary"
                  disabled={!can_save?(@modal_type, @uploads, @story_content)}
                >
                  {gettext("Save")}
                </button>
              </div>
            </form>

            <%!-- Crop Modal for Moodboard Photos (optional) --%>
            <dialog data-cropper-modal class="modal">
              <div class="modal-box max-w-2xl max-h-[90vh]">
                <h3 class="font-bold text-lg mb-2">{gettext("Crop Photo")}</h3>
                <p class="text-sm text-base-content/70 mb-4">
                  {crop_modal_description(@aspect_ratio)}
                </p>

                <div class="w-full max-h-[60vh] overflow-hidden bg-base-200 rounded-lg">
                  <img data-cropper-image src="" alt="" class="max-w-full" />
                </div>

                <div class="modal-action">
                  <button
                    type="button"
                    class="btn btn-ghost"
                    data-cropper-action="skip"
                  >
                    {gettext("Use Full Image")}
                  </button>
                  <button
                    type="button"
                    class="btn btn-primary"
                    data-cropper-action="apply"
                  >
                    {crop_button_text(@aspect_ratio)}
                  </button>
                </div>
              </div>
              <form method="dialog" class="modal-backdrop">
                <button type="button" data-cropper-action="skip">close</button>
              </form>
            </dialog>
          </div>
          <form method="dialog" class="modal-backdrop">
            <button type="button" phx-click="close-modal">close</button>
          </form>
        </dialog>
        
    <!-- Delete Confirmation Modal -->
        <dialog :if={@deleting_item} id="delete-modal" class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg">{gettext("Delete Item")}</h3>
            <p class="py-4">
              {gettext("Are you sure you want to delete this item? This cannot be undone.")}
            </p>

            <div class="modal-action">
              <button type="button" class="btn" phx-click="cancel-delete">
                {gettext("Cancel")}
              </button>
              <button type="button" class="btn btn-error" phx-click="confirm-delete">
                {gettext("Delete")}
              </button>
            </div>
          </div>
          <form method="dialog" class="modal-backdrop">
            <button type="button" phx-click="cancel-delete">close</button>
          </form>
        </dialog>
        
    <!-- Edit Story Modal -->
        <dialog :if={@editing_item} id="edit-story-modal" class="modal modal-open">
          <div class="modal-box max-w-2xl">
            <h3 class="font-bold text-lg mb-4">
              {gettext("Edit Text")}
            </h3>

            <form method="dialog">
              <button
                type="button"
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
                phx-click="close-edit"
              >
                ✕
              </button>
            </form>

            <form phx-submit="update-story" phx-change="validate-edit">
              <div class="mb-4">
                <div
                  id="edit-story-editor"
                  phx-hook="MarkdownEditor"
                  phx-update="ignore"
                  data-initial-value={@edit_content}
                  data-max-length="2000"
                  data-input-name="content"
                  data-placeholder={edit_placeholder(@editing_item)}
                >
                  <input type="hidden" name="content" value={@edit_content} />
                  <p class="text-xs text-base-content/50 mt-2">
                    <span data-char-counter>{String.length(@edit_content || "")}/2000</span>
                  </p>
                </div>
              </div>

              <div class="modal-action">
                <button type="button" class="btn" phx-click="close-edit">
                  {gettext("Cancel")}
                </button>
                <button
                  type="submit"
                  class="btn btn-primary"
                  disabled={
                    !Map.get(@editing_item, :pinned, false) && String.trim(@edit_content || "") == ""
                  }
                >
                  {gettext("Save")}
                </button>
              </div>
            </form>
          </div>
          <form method="dialog" class="modal-backdrop">
            <button type="button" phx-click="close-edit">close</button>
          </form>
        </dialog>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    items = Moodboard.list_moodboard_with_hidden(user.id)

    # Subscribe to moodboard updates and photo approval notifications
    if connected?(socket) do
      # Subscribe to moodboard topic for item-level updates
      Phoenix.PubSub.subscribe(Animina.PubSub, "moodboard:#{user.id}")

      # Subscribe to photo topics for real-time photo state updates
      for item <- items, item.moodboard_photo do
        Phoenix.PubSub.subscribe(Animina.PubSub, "photos:MoodboardItem:#{item.id}")
      end
    end

    socket =
      socket
      |> assign(:page_title, gettext("Edit Moodboard"))
      |> assign(:user, user)
      |> assign(:items, items)
      |> assign(:about_me_complete?, about_me_complete?(items))
      |> assign(:show_modal, false)
      |> assign(:modal_type, nil)
      |> assign(:story_content, "")
      |> assign(:editing_item, nil)
      |> assign(:edit_content, "")
      |> assign(:deleting_item, nil)
      |> assign(:columns, ColumnPreferences.get_columns_for_user(user))
      |> assign(:crop_data, nil)
      |> assign(:crop_preview, nil)
      |> assign(:aspect_ratio, "original")
      |> assign(:orientation, "landscape")
      |> allow_upload(:photo,
        accept: ~w(.jpg .jpeg .png .webp .heic),
        max_entries: 1,
        max_file_size: 6_000_000
      )
      |> maybe_auto_open_about_me(user, items)

    {:ok, socket}
  end

  @impl true
  def handle_event("show-add-modal", %{"type" => type}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:modal_type, type)
     |> assign(:story_content, "")
     |> assign(:aspect_ratio, "original")
     |> assign(:orientation, "landscape")}
  end

  @impl true
  def handle_event("close-modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:modal_type, nil)
     |> assign(:story_content, "")
     |> assign(:crop_data, nil)
     |> assign(:crop_preview, nil)
     |> assign(:aspect_ratio, "original")
     |> assign(:orientation, "landscape")}
  end

  @impl true
  def handle_event("set-aspect-ratio", %{"ratio" => ratio}, socket) do
    {:noreply, assign(socket, :aspect_ratio, ratio)}
  end

  @impl true
  def handle_event("set-orientation", %{"orientation" => orientation}, socket) do
    {:noreply, assign(socket, :orientation, orientation)}
  end

  @impl true
  def handle_event("validate-item", %{"story_content" => content}, socket) do
    {:noreply, assign(socket, :story_content, content)}
  end

  @impl true
  def handle_event("validate-item", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply,
     socket
     |> cancel_upload(:photo, ref)
     |> assign(:crop_data, nil)
     |> assign(:crop_preview, nil)}
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
  def handle_event("crop-skipped", _params, socket) do
    # User chose to use full image - no crop data needed
    {:noreply, assign(socket, :crop_data, nil)}
  end

  @impl true
  def handle_event("crop-cancelled", _params, socket) do
    # For moodboard, cancel just closes the cropper, doesn't remove the file
    {:noreply, socket}
  end

  @impl true
  def handle_event("save-item", params, socket) do
    user = socket.assigns.user
    type = socket.assigns.modal_type
    story_content = params["story_content"] || ""
    crop_data = socket.assigns.crop_data

    result =
      case type do
        "photo" ->
          [result] =
            consume_uploaded_entries(socket, :photo, fn %{path: path}, entry ->
              result =
                Moodboard.create_photo_item(user, path,
                  original_filename: entry.client_name,
                  content_type: entry.client_type,
                  type: "moodboard",
                  crop_data: crop_data
                )

              {:ok, result}
            end)

          result

        "story" ->
          Moodboard.create_story_item(user, story_content)

        "combined" ->
          [result] =
            consume_uploaded_entries(socket, :photo, fn %{path: path}, entry ->
              result =
                Moodboard.create_combined_item(user, path, story_content,
                  original_filename: entry.client_name,
                  content_type: entry.client_type,
                  type: "moodboard",
                  crop_data: crop_data
                )

              {:ok, result}
            end)

          result
      end

    case result do
      {:ok, item} ->
        # Subscribe to photo approval notifications for the new item
        if item.moodboard_photo do
          Phoenix.PubSub.subscribe(Animina.PubSub, "photos:MoodboardItem:#{item.id}")
        end

        items = Moodboard.list_moodboard_with_hidden(user.id)

        {:noreply,
         socket
         |> assign(:items, items)
         |> assign(:about_me_complete?, about_me_complete?(items))
         |> assign(:show_modal, false)
         |> assign(:modal_type, nil)
         |> assign(:story_content, "")
         |> assign(:crop_data, nil)
         |> assign(:crop_preview, nil)
         |> put_flash(:info, gettext("Item added to moodboard"))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to add item"))}
    end
  end

  @impl true
  def handle_event("reposition", %{"id" => id, "new" => new_index, "old" => _old_index}, socket) do
    user = socket.assigns.user
    items = socket.assigns.items

    # Build new order: move the item to new position
    item_ids = Enum.map(items, & &1.id)

    new_order =
      item_ids
      |> List.delete(id)
      |> List.insert_at(new_index, id)

    Moodboard.update_positions(user.id, new_order)

    items = Moodboard.list_moodboard_with_hidden(user.id)

    {:noreply,
     socket
     |> assign(:items, items)
     |> assign(:about_me_complete?, about_me_complete?(items))}
  end

  @impl true
  def handle_event("edit-story", %{"id" => id}, socket) do
    item = Moodboard.get_item_with_preloads(id)
    content = (item.moodboard_story && item.moodboard_story.content) || ""

    # Clear default prompts so the editor placeholder shows instead
    content = clear_default_prompt(content)

    {:noreply,
     socket
     |> assign(:editing_item, item)
     |> assign(:edit_content, content)}
  end

  @impl true
  def handle_event("close-edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_item, nil)
     |> assign(:edit_content, "")}
  end

  @impl true
  def handle_event("cancel-inline-edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_item, nil)
     |> assign(:edit_content, "")}
  end

  @impl true
  def handle_event("update-story-inline", %{"content" => content}, socket) do
    item = socket.assigns.editing_item

    case Moodboard.update_story(item.moodboard_story, content) do
      {:ok, _story} ->
        items = Moodboard.list_moodboard_with_hidden(socket.assigns.user.id)

        {:noreply,
         socket
         |> assign(:items, items)
         |> assign(:about_me_complete?, about_me_complete?(items))
         |> assign(:editing_item, nil)
         |> assign(:edit_content, "")
         |> put_flash(:info, gettext("Text updated"))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update text"))}
    end
  end

  @impl true
  def handle_event("validate-edit", %{"content" => content}, socket) do
    {:noreply, assign(socket, :edit_content, content)}
  end

  @impl true
  def handle_event("update-story", %{"content" => content}, socket) do
    item = socket.assigns.editing_item

    case Moodboard.update_story(item.moodboard_story, content) do
      {:ok, _story} ->
        items = Moodboard.list_moodboard_with_hidden(socket.assigns.user.id)

        {:noreply,
         socket
         |> assign(:items, items)
         |> assign(:about_me_complete?, about_me_complete?(items))
         |> assign(:editing_item, nil)
         |> assign(:edit_content, "")
         |> put_flash(:info, gettext("Text updated"))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update text"))}
    end
  end

  @impl true
  def handle_event("delete-item", %{"id" => id}, socket) do
    item = Moodboard.get_item(id)
    {:noreply, assign(socket, :deleting_item, item)}
  end

  @impl true
  def handle_event("cancel-delete", _params, socket) do
    {:noreply, assign(socket, :deleting_item, nil)}
  end

  @impl true
  def handle_event("confirm-delete", _params, socket) do
    item = socket.assigns.deleting_item

    case Moodboard.delete_item(item) do
      {:ok, _} ->
        items = Moodboard.list_moodboard_with_hidden(socket.assigns.user.id)

        {:noreply,
         socket
         |> assign(:items, items)
         |> assign(:about_me_complete?, about_me_complete?(items))
         |> assign(:deleting_item, nil)
         |> put_flash(:info, gettext("Item deleted"))}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:deleting_item, nil)
         |> put_flash(:error, gettext("Failed to delete item"))}
    end
  end

  @impl true
  def handle_event("device_type_detected", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_columns", %{"columns" => columns_str}, socket) do
    {columns, updated_user} =
      ColumnPreferences.persist_columns(
        socket.assigns.user,
        columns_str
      )

    {:noreply,
     socket
     |> assign(columns: columns, user: updated_user)
     |> ColumnPreferences.update_scope_user(updated_user)}
  end

  # Handle moodboard_item_created - need to subscribe to photo updates for new item
  @impl true
  def handle_info({:moodboard_item_created, item}, socket) do
    if item.moodboard_photo do
      Phoenix.PubSub.subscribe(Animina.PubSub, "photos:MoodboardItem:#{item.id}")
    end

    {:noreply, reload_items(socket)}
  end

  # Handle all other moodboard and photo PubSub messages - all trigger a reload
  @impl true
  def handle_info({event, _payload}, socket)
      when event in [
             :photo_state_changed,
             :photo_approved,
             :moodboard_item_deleted,
             :moodboard_item_updated,
             :moodboard_positions_updated,
             :story_updated
           ] do
    {:noreply, reload_items(socket)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp reload_items(socket) do
    items = Moodboard.list_moodboard_with_hidden(socket.assigns.user.id)

    socket
    |> assign(:items, items)
    |> assign(:about_me_complete?, about_me_complete?(items))
  end

  # Helpers

  defp modal_title("photo"), do: gettext("Add Photo")
  defp modal_title("story"), do: gettext("Add Text")
  defp modal_title("combined"), do: gettext("Add Photo + Text")

  defp can_save?("photo", uploads, _) do
    has_valid_entries?(uploads.photo)
  end

  defp can_save?("story", _, content), do: content && String.trim(content) != ""

  defp can_save?("combined", uploads, content) do
    has_valid_entries?(uploads.photo) && content && String.trim(content) != ""
  end

  defp can_save?(_, _, _), do: false

  defp has_valid_entries?(upload_config) do
    Enum.any?(upload_config.entries, & &1.valid?)
  end

  defp upload_error_message(:too_large), do: gettext("File is too large (max 6MB)")
  defp upload_error_message(:not_accepted), do: gettext("Invalid file type")
  defp upload_error_message(:too_many_files), do: gettext("Too many files")
  defp upload_error_message(_), do: gettext("Upload error")

  # Distribute items to columns with placeholder cards for sparse moodboards.
  # When a user has fewer than 3 items, add placeholder cards to empty columns
  # to show what the moodboard could look like.
  # Returns: [{column_items, placeholder_variants, col_idx}, ...]
  defp distribute_with_placeholders(items, num_columns) do
    item_count = length(items)
    needs_placeholders? = item_count > 0 and item_count < 3

    # distribute_to_columns already returns all columns (including empty ones)
    distribute_to_columns(items, num_columns)
    |> Enum.map(fn {column_items, col_idx} ->
      placeholders = get_placeholders(needs_placeholders?, column_items, col_idx)
      {column_items, placeholders, col_idx}
    end)
  end

  defp get_placeholders(needs_placeholders?, column_items, col_idx) do
    if needs_placeholders? and Enum.empty?(column_items) do
      # Alternate between photo and text placeholders for visual variety
      if rem(col_idx, 2) == 0, do: [:photo], else: [:text]
    else
      []
    end
  end

  defp crop_success_message("original"), do: gettext("Photo ready")
  defp crop_success_message("1:1"), do: gettext("Cropped to square")
  defp crop_success_message("16:9"), do: gettext("Cropped to 16:9")
  defp crop_success_message("4:3"), do: gettext("Cropped to 4:3")
  defp crop_success_message(_), do: gettext("Photo ready")

  defp crop_modal_description("original") do
    gettext("Your photo doesn't need cropping. Click 'Use Full Image' to continue.")
  end

  defp crop_modal_description("1:1") do
    gettext("Crop your photo to a square, or skip to use the full image.")
  end

  defp crop_modal_description("16:9") do
    gettext("Crop your photo to 16:9 format, or skip to use the full image.")
  end

  defp crop_modal_description("4:3") do
    gettext("Crop your photo to 4:3 format, or skip to use the full image.")
  end

  defp crop_modal_description(_), do: gettext("Crop your photo or skip to use the full image.")

  defp crop_button_text("1:1"), do: gettext("Crop to Square")
  defp crop_button_text("16:9"), do: gettext("Crop to 16:9")
  defp crop_button_text("4:3"), do: gettext("Crop to 4:3")
  defp crop_button_text(_), do: gettext("Apply")

  # Check if the pinned "About Me" item is complete (has avatar photo + custom text)
  defp about_me_complete?(items) do
    pinned_item = Enum.find(items, &Map.get(&1, :pinned, false))

    case pinned_item do
      nil ->
        false

      item ->
        has_photo? = item.moodboard_photo != nil
        has_custom_text? = has_custom_about_me_text?(item)
        has_photo? and has_custom_text?
    end
  end

  defp maybe_auto_open_about_me(socket, %{state: "waitlisted"}, items) do
    pinned_item = Enum.find(items, &Map.get(&1, :pinned, false))

    if pinned_item && length(items) == 1 && !has_custom_about_me_text?(pinned_item) do
      item = Moodboard.get_item_with_preloads(pinned_item.id)
      content = (item.moodboard_story && item.moodboard_story.content) || ""
      content = clear_default_prompt(content)

      socket
      |> assign(:editing_item, item)
      |> assign(:edit_content, content)
    else
      socket
    end
  end

  defp maybe_auto_open_about_me(socket, _user, _items), do: socket

  # Check if the story content is not a default placeholder
  defp has_custom_about_me_text?(%{moodboard_story: nil}), do: false

  defp has_custom_about_me_text?(%{moodboard_story: %{content: content}}) do
    trimmed = String.trim(content || "")

    default_prompts = [
      "Tell us about yourself...",
      "Erzähl uns etwas über dich..."
    ]

    trimmed != "" and trimmed not in default_prompts
  end

  # Return the appropriate placeholder text for the edit story editor
  defp edit_placeholder(%{pinned: true}), do: gettext("Tell us about yourself...")
  defp edit_placeholder(_item), do: gettext("Write your text here...")

  # Clear known default prompts so the editor placeholder shows instead
  @default_prompts ["Tell us about yourself...", "Erzähl uns etwas über dich..."]
  defp clear_default_prompt(content) when content in @default_prompts, do: ""
  defp clear_default_prompt(content), do: content
end
