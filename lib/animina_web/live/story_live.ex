defmodule AniminaWeb.StoryLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Photo
  alias Animina.Narratives
  alias Animina.Narratives.Story
  alias Animina.Narratives.Headline
  alias AshPhoenix.Form

  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(active_tab: :home)
      |> assign(
        :photo,
        get_user_default_photo(socket)
      )
      |> assign(
        :position,
        get_user_story_position(socket)
      )
      |> assign(:errors, [])
      |> allow_upload(:photos, accept: ~w(.jpg .jpeg .png), max_entries: 1, id: "photo_file")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :about_me, _params) do
    form =
      Form.for_create(Story, :create,
        api: Narratives,
        as: "story",
        forms: [
          headline: [
            resource: Headline,
            create_action: :create
          ]
        ]
      )
      |> AshPhoenix.Form.add_form([:headline], params: %{subject: "About me"}, validate?: false)
      |> to_form()

    socket
    |> assign(page_title: gettext("Create your first story"))
    |> assign(form_id: "create-story-form")
    |> assign(title: gettext("Create your first story"))
    |> assign(:cta, gettext("Create about me story"))
    |> assign(info_text: gettext("Use stories to tell potential partners about yourself"))
    |> assign(form: form)
  end

  defp apply_action(socket, _, _params) do
    form =
      Form.for_create(Story, :create,
        api: Narratives,
        as: "story",
        forms: [
          headline: [
            resource: Headline,
            create_action: :create
          ],
          photo: [
            resource: Photo,
            create_action: :create
          ]
        ]
      )
      |> AshPhoenix.Form.add_form([:headline], params: %{subject: "About me"}, validate?: false)
      |> AshPhoenix.Form.add_form([:photo], validate?: false)
      |> to_form()

    socket
    |> assign(page_title: gettext("Create a story"))
    |> assign(form_id: "create-story-form")
    |> assign(title: gettext("Create your own story"))
    |> assign(:cta, gettext("Create new story"))
    |> assign(info_text: gettext("Use stories to tell potential partners about yourself"))
    |> assign(form: form)
  end

  @impl true
  def handle_event("validate", %{"story" => story}, socket) do
    form = Form.validate(socket.assigns.form, story, errors: true)

    {:noreply, socket |> assign(form: form)}
  end

  @impl true
  def handle_event("submit", %{"story" => story}, socket)
      when is_nil(socket.assigns.photo) == false do
    form = Form.validate(socket.assigns.form, story)

    with [] <- Form.errors(form), {:ok, story} <- Form.submit(form, params: story) do
      Ash.Changeset.for_update(socket.assigns.photo, :update, %{story_id: story.id})
      |> Accounts.update()

      {:noreply,
       socket
       |> assign(:errors, [])}
    else
      {:error, form} ->
        {:noreply, socket |> assign(:form, form)}

      errors ->
        {:noreply, socket |> assign(:errors, errors)}
    end
  end

  @impl true
  def handle_event("submit", %{"story" => story}, socket) do
    form = Form.validate(socket.assigns.form, story)

    socket =
      socket
      |> assign(:form, form)
      |> assign(:errors, Form.errors(form))

    {:noreply, socket}
  end

  defp get_user_default_photo(socket) do
    photos_results =
      Accounts.Photo
      |> Ash.Query.for_read(:read, %{user_id: socket.assigns.current_user.id})
      |> Accounts.read!(page: [limit: 1])

    case Map.get(photos_results, :results) do
      [photo | _] -> photo
      _ -> nil
    end
  end

  defp get_user_story_position(socket) do
    story_results =
      Narratives.Story
      |> Ash.Query.for_read(:read, %{user_id: socket.assigns.current_user.id})
      |> Narratives.read!(page: [limit: 1, count: true])

    Map.get(story_results, :count) + 1
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4 px-5">
      <h2 class="font-bold text-xl"><%= @title %></h2>

      <p><%= @info_text %></p>

      <.form
        :let={f}
        id={@form_id}
        for={@form}
        class="space-y-6 group"
        phx-change="validate"
        phx-submit="submit"
      >
        <%= text_input(f, :position, type: :hidden, value: @position) %>
        <%= text_input(f, :user_id, type: :hidden, value: @current_user.id) %>

        <.inputs_for :let={headline_form} field={@form[:headline]}>
          <%= text_input(headline_form, :position, type: :hidden, value: @position) %>

          <%= text_input(headline_form, :user_id, type: :hidden, value: @current_user.id) %>

          <div>
            <label for="story_headline" class="block text-sm font-medium leading-6 text-gray-900">
              <%= gettext("Headline") %>
            </label>

            <div phx-feedback-for={headline_form[:subject].name} class="mt-2">
              <%= text_input(
                headline_form,
                :subject,
                class:
                  "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                    unless(get_field_errors(headline_form[:subject], :subject) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    ),
                placeholder: gettext("About me"),
                value: headline_form[:subject].value,
                type: :text,
                "phx-debounce": "200"
              ) %>

              <.error :for={msg <- get_field_errors(headline_form[:subject], :subject)}>
                <%= gettext("Headline") <> " " <> msg %>
              </.error>
            </div>
          </div>
        </.inputs_for>

        <div>
          <label for="story_content" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("Content") %>
          </label>

          <div phx-feedback-for={f[:content].name} class="mt-2">
            <%= textarea(
              f,
              :content,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:content], :content) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("I like swimming"),
              value: f[:content].value,
              type: :text,
              "phx-debounce": "200",
              maxlength: "1024"
            ) %>

            <.error :for={msg <- get_field_errors(f[:content], :content)}>
              <%= gettext("Content") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div :if={@photo != nil} class="w-full space-y-2">
          <p class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("Photo") %>
          </p>

          <img
            class="object-cover h-200 drop-shadow border rounded-lg"
            src={AniminaWeb.Endpoint.url() <> "/uploads/" <> @photo.filename}
          />
        </div>

        <.inputs_for :let={photo_form} :if={@photo == nil} field={@form[:photo]}>
          <p class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("Photo") %>
          </p>

          <.live_file_input type="file" accept="image/*" upload={@uploads.photos} class="hidden" />

          <%= text_input(photo_form, :user_id, type: :hidden, value: @current_user.id) %>

          <div
            :if={Enum.count(@uploads.photos.entries) == 0}
            id={"photo-#{@uploads.photos.ref}"}
            phx-click={JS.dispatch("click", to: "##{@uploads.photos.ref}", bubbles: false)}
            phx-drop-target={@uploads.photos.ref}
            for={@uploads.photos.ref}
            data-upload-target="photos"
            data-input={@uploads.photos.ref}
            class="flex flex-col items-center max-w-2xl w-full py-8 px-6 mx-auto  text-center border-2 border-gray-300 border-dashed cursor-pointer bg-gray-50  rounded-md"
          >
            <.icon name="hero-cloud-arrow-up" class="w-8 h-8 mb-4 text-gray-500 dark:text-gray-400" />

            <p class="text-sm">Upload or drag & drop your photo file JPG, JPEG, PNG</p>
          </div>

          <%= for entry <- @uploads.photos.entries do %>
            <%= text_input(f, :filename, type: :hidden, value: entry.uuid <> "." <> ext(entry)) %>
            <%= text_input(f, :original_filename, type: :hidden, value: entry.client_name) %>
            <%= text_input(f, :ext, type: :hidden, value: ext(entry)) %>
            <%= text_input(f, :mime, type: :hidden, value: entry.client_type) %>
            <%= text_input(f, :size, type: :hidden, value: entry.client_size) %>

            <div class="flex space-x-8">
              <.live_img_preview class="inline-block object-cover h-32 w-32 rounded-md" entry={entry} />

              <div class="flex-1 flex flex-col justify-center">
                <p><%= entry.client_name %></p>
                <p class="text-sm text-gray-600">
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
                    Cancel
                  </button>
                </div>
              </div>
            </div>

            <div
              :if={Enum.count(upload_errors(@uploads.photos, entry))}
              class="danger mb-4"
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
        </.inputs_for>

        <div>
          <%= submit(@cta,
            class:
              "flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@form.source.valid?,
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                ),
            disabled: @form.source.valid?
          ) %>
        </div>
      </.form>
    </div>
    """
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
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
