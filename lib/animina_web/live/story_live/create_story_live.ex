defmodule AniminaWeb.StoryLive.Create do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Photo
  alias Animina.Narratives
  alias Animina.Narratives.Story
  alias AshPhoenix.Form

  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(active_tab: :home)
      |> assign(:errors, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :about_me, _params) do
    socket
    |> assign(page_title: gettext("Create your first story"))
    |> assign(:form_id, "create-story-form")
    |> assign(title: gettext("Create your first story"))
    |> assign(info_text: gettext("Use stories to tell potential partners about yourself"))
    |> assign(
      :form,
      Form.for_create(Story, :create, api: Narratives, as: "story")
    )
  end

  defp apply_action(socket, _, _params) do
    socket
    |> assign(page_title: gettext("Create a story"))
    |> assign(form_id: "create-story-form")
    |> assign(title: gettext("Create your own story"))
    |> assign(info_text: gettext("Use stories to tell potential partners about yourself"))
    |> assign(
      :form,
      Form.for_create(Story, :create, api: Narratives, as: "story")
    )
  end

  @impl true
  def handle_event("validate", %{"story" => story}, socket) do
    form = Form.validate(socket.assigns.form, story, errors: true)

    {:noreply, socket |> assign(form: form)}
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
        <div>
          <label for="story_headline" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("Headline") %>
          </label>

          <div phx-feedback-for={f[:headline].name} class="mt-2">
            <%= text_input(
              f,
              :headline,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:headline], :headline) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("Pusteblume1977"),
              value: f[:headline].value,
              type: :text,
              required: true,
              autocomplete: :headline,
              "phx-debounce": "200"
            ) %>

            <.error :for={msg <- get_field_errors(f[:headline], :headline)}>
              <%= gettext("Username") <> " " <> msg %>
            </.error>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
  end
end
