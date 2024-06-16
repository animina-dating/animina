defmodule AniminaWeb.PostLive do
  use AniminaWeb, :live_view

  alias Animina.GenServers.ProfileViewCredits
  alias Animina.Narratives
  alias Animina.Narratives.Post
  alias AshPhoenix.Form
  alias Phoenix.PubSub

  @impl true
  def mount(%{"id" => post_id}, %{"language" => language} = _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )
    end

    post = Post.by_id!(post_id)

    socket =
      socket
      |> assign(language: language)
      |> assign(post: post)
      |> assign(active_tab: :home)
      |> assign(errors: [])
      |> assign(content: post.content)

    {:ok, socket}
  end

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

    socket =
      socket
      |> assign(language: language)
      |> assign(active_tab: :home)
      |> assign(errors: [])
      |> assign(content: "")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  @impl true
  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  def handle_info({:user, current_user}, socket) do
    if current_user.state in user_states_to_be_auto_logged_out() do
      {:noreply, socket |> push_redirect(to: "/auth/user/sign-out")}
    else
      {:noreply, socket |> assign(:current_user, current_user)}
    end
  end

  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
  end

  defp apply_action(socket, :edit, _params) do
    form =
      Form.for_update(socket.assigns.post, :update,
        api: Narratives,
        as: "post",
        forms: [],
        actor: socket.assigns.current_user
      )
      |> to_form()

    socket
    |> assign(page_title: gettext("Edit your post"))
    |> assign(form_id: "edit-post-form")
    |> assign(title: gettext("Edit your post"))
    |> assign(:cta, gettext("Save post"))
    |> assign(info_text: gettext("Use posts to write about things that interest you"))
    |> assign(form: form)
  end

  defp apply_action(socket, _, _params) do
    form =
      Form.for_create(Post, :create,
        api: Narratives,
        as: "post",
        forms: [],
        actor: socket.assigns.current_user
      )
      |> to_form()

    socket
    |> assign(page_title: gettext("Create a post"))
    |> assign(form_id: "create-post-form")
    |> assign(title: gettext("Create your own post"))
    |> assign(:cta, gettext("Create new post"))
    |> assign(info_text: gettext("Use posts to write about things that interest you"))
    |> assign(form: form)
  end

  @impl true
  def handle_event("validate", %{"post" => post}, socket) do
    form = Form.validate(socket.assigns.form, post, errors: true)

    content =
      Map.get(post, "content")

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:content, content)}
  end

  @impl true
  def handle_event("submit", %{"post" => post}, socket) do
    form = Form.validate(socket.assigns.form, post)

    with [] <- Form.errors(form),
         {:ok, _post} <-
           Form.submit(form, params: post, api_opts: []) do
      {:noreply,
       socket
       |> assign(:errors, [])
       |> push_navigate(to: ~p"/#{socket.assigns.current_user.username}")}
    else
      {:error, form} ->
        {:noreply, socket |> assign(:form, form)}

      errors ->
        {:noreply, socket |> assign(:errors, errors)}
    end
  end

  defp user_states_to_be_auto_logged_out do
    [
      :under_investigation
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-5 space-y-4">
      <h2 class="text-xl font-bold dark:text-white"><%= @title %></h2>

      <p class="dark:text-white"><%= @info_text %></p>

      <.form
        :let={f}
        id={@form_id}
        for={@form}
        class="space-y-6 group"
        phx-change="validate"
        phx-submit="submit"
      >
        <%= if @form.source.type == :update do %>
          <%= text_input(f, :id, type: :hidden, value: f[:id].value) %>
        <% end %>

        <%!-- <%= text_input(f, :user_id, type: :hidden, value: @current_user.id) %> --%>

        <div>
          <label
            for="post_title"
            class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
          >
            <%= gettext("Title") %>
          </label>

          <div phx-feedback-for={f[:title].name} class="mt-2">
            <%= text_input(
              f,
              :title,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:title], :title) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("Your post title"),
              value: f[:title].value,
              type: :text,
              "phx-debounce": "200",
              maxlength: "120"
            ) %>

            <.error :for={msg <- get_field_errors(f[:title], :title)}>
              <%= gettext("Title") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <label
            for="post_content"
            class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
          >
            <%= gettext("Content") %>
          </label>

          <div phx-feedback-for={f[:content].name} class="mt-2">
            <%= textarea(
              f,
              :content,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:content], :content) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder:
                gettext(
                  "Use normal text or the Markdown format to write your post. You can use **bold**, *italic*, ~line-through~, [links](https://example.com) and more. Each post can be up to 8,192 characters long. Please do write multiple posts to share your thoughts."
                ),
              value: f[:content].value,
              rows: 16,
              type: :text,
              "phx-debounce": "200",
              maxlength: "8192"
            ) %>

            <.error :for={msg <- get_field_errors(f[:content], :content)}>
              <%= gettext("Content") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <%= submit(@cta,
            class:
              "flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@form.source.source.valid? == false,
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                ),
            disabled: @form.source.source.valid? == false
          ) %>
        </div>
      </.form>
    </div>
    """
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
  end
end
