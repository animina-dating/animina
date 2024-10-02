defmodule AniminaWeb.StoriesComponents do
  @moduledoc """
  Provides Story UI components.
  """
  use Phoenix.Component
  alias Animina.Markdown
  import AniminaWeb.Gettext
  alias Animina.Accounts.Photo
  import Gettext, only: [with_locale: 2]

  attr :stories_and_flags, :list, required: true
  attr :current_user, :any, required: true
  attr :current_user_green_flags, :list, required: true
  attr :current_user_red_flags, :list, required: true
  attr :add_new_story_title, :string, required: true
  attr :delete_story_modal_text, :string, required: true
  attr :user, :any, required: false

  def stories_display(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <div class="gap-8 columns-1 md:columns-2 lg:columns-3">
        <%= for {story, flags} <- @stories_and_flags do %>
          <.story_card
            story={story}
            current_user={@current_user}
            flags={flags}
            delete_story_modal_text={@delete_story_modal_text}
            user={@user}
            current_user_green_flags={@current_user_green_flags}
            current_user_red_flags={@current_user_red_flags}
          />
        <% end %>
      </div>
    </div>
    """
  end

  attr :story, :any, required: true
  attr :photo, :any, required: false
  attr :dom_id, :any, required: false
  attr :flags, :list, required: false
  attr :current_user, :any, required: true
  attr :language, :any, required: true
  attr :user, :any, required: false
  attr :current_user_green_flags, :list, required: true
  attr :current_user_red_flags, :list, required: true
  attr :delete_story_modal_text, :string, required: true

  def story_card(assigns) do
    ~H"""
    <article>
      <div
        :if={@story.photo}
        class="relative flex flex-col justify-end px-8 pb-8 overflow-hidden bg-gray-900 isolate rounded-2xl pt-80 sm:pt-48 lg:pt-80"
      >
        <img
          :if={
            (@current_user && @story.user_id == @current_user.id) ||
              display_image(@story.photo.state, @current_user, @story)
          }
          src={Photo.get_optimized_photo_to_use(@story.photo, :normal)}
          alt={@story.headline.subject}
          class="absolute inset-0 object-cover w-full h-full -z-10"
        />

        <h3 class="mt-3 text-lg font-semibold leading-6 text-white">
          <span class="absolute inset-0"></span> <%= @story.headline.subject %>
          <p
            :if={
              @current_user && @story.photo.state != :approved &&
                (@story.user_id == @current_user.id || admin_user?(@current_user))
            }
            class={"p-1 text-[10px] #{get_photo_state_styling(@story.photo.state)} absolute top-2 left-2 rounded-md "}
          >
            <%= get_photo_state_name(@story.photo.state, @language) %>
          </p>
        </h3>
      </div>
      <div class="pb-2">
        <.story_body
          story={@story}
          user={@user}
          dom_id={@dom_id}
          current_user={@current_user}
          delete_story_modal_text={@delete_story_modal_text}
        />
      </div>
      <div class="pb-4" />
    </article>
    """
  end

  def empty_flags_array?(array) when is_list(array) do
    Enum.all?(array, fn x -> is_map(x) && Map.values(x) == [] end)
  end

  def display_image(:pending_review, _, _) do
    true
  end

  def display_image(:approved, _, _) do
    true
  end

  def display_image(:in_review, _, _) do
    true
  end

  def display_image(:error, nil, _) do
    false
  end

  def display_image(:nsfw, nil, _) do
    false
  end

  def display_image(:nsfw, current_user, story) do
    if story.user_id == current_user.id || admin_user?(current_user) do
      true
    else
      false
    end
  end

  def display_image(:error, current_user, story) do
    if story.user_id == current_user.id || admin_user?(current_user) do
      true
    else
      false
    end
  end

  def display_image(_, _, _) do
    false
  end

  def admin_user?(current_user) do
    case current_user.roles do
      [] ->
        false

      roles ->
        roles
        |> Enum.map(fn x -> x.name end)
        |> Enum.any?(fn x -> x == :admin end)
    end
  end

  defp get_photo_state_styling(:error) do
    "bg-red-500 text-white"
  end

  defp get_photo_state_styling(:nsfw) do
    "bg-red-500 text-white"
  end

  defp get_photo_state_styling(:rejected) do
    "bg-red-500 text-white"
  end

  defp get_photo_state_styling(:pending_review) do
    "bg-yellow-500 text-white"
  end

  defp get_photo_state_styling(:in_review) do
    "bg-blue-500 text-white"
  end

  defp get_photo_state_name(:error, language) do
    with_locale(language, fn -> gettext("Error") end)
  end

  defp get_photo_state_name(:nsfw, language) do
    with_locale(language, fn -> gettext("NSFW") end)
  end

  defp get_photo_state_name(:rejected, language) do
    with_locale(language, fn -> gettext("Rejected") end)
  end

  defp get_photo_state_name(:pending_review, language) do
    with_locale(language, fn -> gettext("Pending review") end)
  end

  defp get_photo_state_name(:in_review, language) do
    with_locale(language, fn -> gettext("In review") end)
  end

  defp get_photo_state_name(_, language) do
    with_locale(language, fn -> gettext("Error") end)
  end

  attr :story, :any, required: true
  attr :current_user, :any, required: true
  attr :dom_id, :string, required: false
  attr :delete_story_modal_text, :string, required: true

  def story(assigns) do
    ~H"""
    <div class="pb-4">
      <div :if={@story.photo} class="pb-4">
        <%= if @story.headline.subject == "About me" do %>
          <img
            class="object-cover rounded-lg aspect-square"
            src={Photo.get_optimized_photo_to_use(@story.photo, :normal)}
          />
        <% else %>
          <img
            class="object-cover rounded-lg"
            src={Photo.get_optimized_photo_to_use(@story.photo, :normal)}
          />
        <% end %>
      </div>
      <.story_body
        story={@story}
        user={@user}
        dom_id={@dom_id}
        current_user={@current_user}
        delete_story_modal_text={@delete_story_modal_text}
      />
      <hr />
    </div>
    """
  end

  attr :story, :any, required: true
  attr :user, :any, required: false
  attr :dom_id, :any, required: false
  attr :current_user, :any, required: true
  attr :delete_story_modal_text, :string, required: true

  def story_body(assigns) do
    ~H"""
    <div :if={@story.headline} class="pb-4">
      <h3 :if={@story.photo == nil} class="text-lg font-semibold dark:text-white">
        <%= @story.headline.subject %>
      </h3>
    </div>
    <.story_content story={@story} />
    <.story_action_icons
      story={@story}
      user={@user}
      dom_id={@dom_id}
      current_user={@current_user}
      delete_story_modal_text={@delete_story_modal_text}
    />
    """
  end

  def story_content(assigns) do
    ~H"""
    <div :if={@story.content} class="pb-2 text-justify text-gray-600 text-ellipsis dark:text-gray-100">
      <%= Markdown.format(@story.content) %>
    </div>
    """
  end

  @spec story_action_icons(any()) :: Phoenix.LiveView.Rendered.t()
  def story_action_icons(assigns) do
    ~H"""
    <div
      :if={@current_user && @user.id == @current_user.id && @story.headline != nil}
      class="flex justify-end gap-4 pb-4 text-justify text-gray-600 cursor-pointer dark:text-gray-100"
    >
      <.link navigate={"/my/stories/#{@story.id}/edit" }>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="25"
          height="24"
          viewBox="0 0 20 20"
          fill="currentColor"
          aria-hidden="true"
        >
          <path d="M2.695 14.763l-1.262 3.154a.5.5 0 00.65.65l3.155-1.262a4 4 0 001.343-.885L17.5 5.5a2.121 2.121 0 00-3-3L3.58 13.42a4 4 0 00-.885 1.343z" />
        </svg>
      </.link>

      <svg
        :if={@story.headline.subject != "About me"}
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 20 20"
        width="25"
        height="24"
        fill="currentColor"
        aria-hidden="true"
        phx-click="destroy_story"
        phx-value-id={@story.id}
        phx-value-dom_id={@dom_id}
        data-confirm={@delete_story_modal_text}
      >
        <path
          fill-rule="evenodd"
          d="M8.75 1A2.75 2.75 0 006 3.75v.443c-.795.077-1.584.176-2.365.298a.75.75 0 10.23 1.482l.149-.022.841 10.518A2.75 2.75 0 007.596 19h4.807a2.75 2.75 0 002.742-2.53l.841-10.52.149.023a.75.75 0 00.23-1.482A41.03 41.03 0 0014 4.193V3.75A2.75 2.75 0 0011.25 1h-2.5zM10 4c.84 0 1.673.025 2.5.075V3.75c0-.69-.56-1.25-1.25-1.25h-2.5c-.69 0-1.25.56-1.25 1.25v.325C8.327 4.025 9.16 4 10 4zM8.58 7.72a.75.75 0 00-1.5.06l.3 7.5a.75.75 0 101.5-.06l-.3-7.5zm4.34.06a.75.75 0 10-1.5-.06l-.3 7.5a.75.75 0 101.5.06l.3-7.5z"
          clip-rule="evenodd"
        />
      </svg>
    </div>
    """
  end

  attr :flag, :any, required: true
  attr :current_user_green_flags, :list, required: true
  attr :current_user_red_flags, :list, required: true

  def get_styling_for_matching_flags(assigns) do
    ~H"""
    <div :if={@flag.id in (@current_user_green_flags |> Enum.map(fn x -> x.id end))} class="pl-2">
      <p class="w-2 h-2 bg-green-500 rounded-full" />
    </div>
    <div :if={@flag.id in (@current_user_red_flags |> Enum.map(fn x -> x.id end))} class="pl-2">
      <p class="w-2 h-2 bg-red-500 rounded-full" />
    </div>
    """
  end
end
