defmodule AniminaWeb.SpotlightComponents do
  @moduledoc """
  Shared function components for rendering spotlight candidate cards.

  Used by both `SpotlightLive` and `MyHub` dashboard mode.
  """

  use AniminaWeb, :html

  import AniminaWeb.Helpers.UserHelpers, only: [get_location_info: 2, gender_symbol: 1]

  alias Animina.Accounts

  attr :candidate, :map, required: true
  attr :avatar, :map, default: nil
  attr :city_name, :string, default: nil
  attr :story_excerpt, :string, default: nil
  attr :wildcard?, :boolean, default: false
  attr :visited?, :boolean, default: false

  def spotlight_card(assigns) do
    assigns =
      assigns
      |> assign(:age, Accounts.compute_age(assigns.candidate.birthday))
      |> assign(:gender, gender_symbol(assigns.candidate.gender))
      |> assign(:truncated_story, truncate_story(assigns.story_excerpt))

    ~H"""
    <div class={[
      "rounded-lg overflow-hidden hover:shadow-md transition-shadow",
      if(@wildcard?,
        do: "border-2 border-accent/50",
        else: "border border-base-300"
      )
    ]}>
      <.link
        navigate={~p"/users/#{@candidate.id}" <> if(@wildcard?, do: "?ref=wildcard", else: "")}
        class="block relative"
      >
        <%= if @avatar do %>
          <.live_component
            module={AniminaWeb.LivePhotoComponent}
            id={"spotlight-avatar-#{@avatar.id}"}
            photo={@avatar}
            owner?={false}
            variant={:main}
            class="w-full aspect-[4/3] object-cover"
          />
        <% else %>
          <div class="w-full aspect-[4/3] bg-base-200 flex items-center justify-center">
            <.icon name="hero-user" class="h-10 w-10 text-base-content/30" />
          </div>
        <% end %>

        <%!-- Wildcard badge --%>
        <span
          :if={@wildcard?}
          class="absolute top-2 right-2 badge badge-accent badge-sm gap-1"
        >
          <.icon name="hero-bolt-mini" class="h-3 w-3" /> {gettext("Wildcard")}
        </span>

        <%!-- Visited badge --%>
        <span
          :if={@visited?}
          class="absolute top-2 left-2 badge badge-ghost badge-sm bg-black/40 text-white/80 border-0"
        >
          <.icon name="hero-eye-mini" class="h-3 w-3" /> {gettext("Visited")}
        </span>

        <%!-- Name/age overlay --%>
        <div class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/60 to-transparent pt-8 pb-2 px-3">
          <p class="text-white font-semibold text-sm drop-shadow-sm">
            {@candidate.display_name}<span :if={@age} class="font-normal text-white/80">, {@age}</span>
            <span class="text-white/70 ml-1">{@gender}</span>
          </p>
        </div>
      </.link>

      <div class="p-2">
        <p :if={@city_name} class="text-xs text-base-content/50 flex items-center gap-1">
          <.icon name="hero-map-pin-mini" class="h-3 w-3" />
          {@city_name}
        </p>
        <p :if={@truncated_story} class="text-xs text-base-content/60 mt-1 line-clamp-3">
          {@truncated_story}
        </p>
      </div>
    </div>
    """
  end

  attr :avatar_url, :string, default: nil
  attr :age, :integer, default: nil
  attr :gender, :string, default: nil
  attr :city_name, :string, default: nil
  attr :obfuscated_name, :string, default: nil

  def preview_card(assigns) do
    ~H"""
    <div class="rounded-lg overflow-hidden border border-base-300/50 bg-base-200">
      <%= if @avatar_url do %>
        <img
          src={@avatar_url}
          class="w-full aspect-[4/3] object-cover"
          loading="lazy"
          alt={gettext("Mystery candidate")}
        />
      <% else %>
        <div class="w-full aspect-[4/3] bg-base-200 flex items-center justify-center">
          <.icon name="hero-question-mark-circle" class="h-10 w-10 text-base-content/20" />
        </div>
      <% end %>

      <div :if={@obfuscated_name || @age || @city_name} class="p-2">
        <p class="text-sm font-medium text-base-content/70">
          {@obfuscated_name}<span :if={@age} class="font-normal text-base-content/50">, {@age}</span>
          <span :if={@gender} class="text-base-content/40 ml-1">{@gender}</span>
        </p>
        <p :if={@city_name} class="text-xs text-base-content/40 flex items-center gap-1 mt-0.5">
          <.icon name="hero-map-pin-mini" class="h-3 w-3" />
          {@city_name}
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Resolves a city name for a user given a map of preloaded city names.
  """
  def city_name_for(user, city_names) do
    {_zip, name} = get_location_info(user, city_names)
    name
  end

  @doc """
  Strips markdown and truncates story text to 80 characters.
  """
  def truncate_story(nil), do: nil

  def truncate_story(text) do
    text
    |> String.replace(~r/[#*_~`>\[\]()]/, "")
    |> String.trim()
    |> String.slice(0, 160)
  end
end
