defmodule AniminaWeb.Helpers.FeatureFlagHelpers do
  @moduledoc """
  Shared helper functions and components for feature flag admin pages.
  """

  use Gettext, backend: AniminaWeb.Gettext
  use Phoenix.Component

  import AniminaWeb.CoreComponents, only: [icon: 1]
  import AniminaWeb.Helpers.AdminHelpers, only: [parse_integer: 2]

  alias Animina.FeatureFlags

  # --- Components ---

  def flag_toggle(assigns) do
    ~H"""
    <label class="swap swap-flip">
      <input
        type="checkbox"
        checked={@checked}
        phx-click={@event}
        phx-value-flag={@flag_name}
      />
      <div class={[
        "swap-on flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium",
        "bg-success/20 text-success"
      ]}>
        <.icon name="hero-check-circle-mini" class="h-4 w-4" />
        {gettext("On")}
      </div>
      <div class={[
        "swap-off flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium",
        "bg-base-300 text-base-content/50"
      ]}>
        <.icon name="hero-x-circle-mini" class="h-4 w-4" />
        {gettext("Off")}
      </div>
    </label>
    """
  end

  def search_bar(assigns) do
    ~H"""
    <div class="mb-6">
      <div class="relative">
        <.icon
          name="hero-magnifying-glass"
          class="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-base-content/40"
        />
        <input
          type="text"
          placeholder={gettext("Search flags and settings...")}
          value={@search_query}
          phx-keyup="search"
          phx-debounce="150"
          name="query"
          class="input input-bordered w-full pl-10 pr-10"
        />
        <%= if @search_query != "" do %>
          <button
            type="button"
            phx-click="clear-search"
            class="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/40 hover:text-base-content"
          >
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  # --- Search Helpers ---

  def matches_search?(_item, ""), do: true

  def matches_search?(item, query) do
    query = String.downcase(query)
    name = item.name |> to_string() |> String.downcase()
    label = item.label |> String.downcase()
    description = item.description |> String.downcase()

    String.contains?(name, query) ||
      String.contains?(label, query) ||
      String.contains?(description, query)
  end

  def filter_by_search(items, ""), do: items
  def filter_by_search(items, query), do: Enum.filter(items, &matches_search?(&1, query))

  # --- Value Parsing ---

  def parse_auto_approve_value("true"), do: true
  def parse_auto_approve_value("false"), do: false
  def parse_auto_approve_value(""), do: nil
  def parse_auto_approve_value(nil), do: nil
  def parse_auto_approve_value(value), do: value

  def parse_setting_value(value, %{type: :string}) do
    value |> to_string() |> String.trim()
  end

  def parse_setting_value(value, setting) do
    min_val = setting[:min_value] || 0
    max_val = setting[:max_value] || 999
    parsed = parse_integer(value, setting.default_value)
    max(min_val, min(max_val, parsed))
  end

  # --- Shared Save Logic ---

  def save_value_setting(socket, setting, raw_value, opts) do
    value = parse_setting_value(raw_value, setting)
    flag_name = "system:#{setting.name}"

    {:ok, flag_setting} =
      FeatureFlags.get_or_create_flag_setting(flag_name, %{
        description: setting.description,
        settings: %{value: setting.default_value}
      })

    case FeatureFlags.update_flag_setting(flag_setting, %{settings: %{value: value}}) do
      {:ok, _updated} ->
        assigns = Keyword.get(opts, :refresh, []) ++ Keyword.get(opts, :clear, [])

        socket =
          socket
          |> assign(assigns)
          |> Phoenix.LiveView.put_flash(:info, gettext("Setting saved."))

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, Phoenix.LiveView.put_flash(socket, :error, gettext("Could not save setting."))}
    end
  end
end
