defmodule AniminaWeb.SelectFlagsComponent do
  @moduledoc """
  This component renders flags which a user can click on.
  """
  use AniminaWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, socket |> assign(selected_flags: %{})}
  end

  @impl true
  def update(assigns, socket) do
    selected_flags =
      Enum.reduce(assigns.user_flags, socket.assigns.selected_flags, fn flag_id, acc ->
        Map.put_new(acc, flag_id, %{})
      end)

    socket =
      socket
      |> assign(assigns)
      |> assign(selected_flags: selected_flags)

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "select_flag",
        %{
          "flag" => flag,
          "flagid" => flag_id
        },
        socket
      ) do
    socket =
      case Map.get(socket.assigns.selected_flags, flag_id) do
        nil ->
          send(self(), {:flag_selected, flag_id})

          socket
          |> assign(
            :selected_flags,
            Map.merge(socket.assigns.selected_flags, %{
              "#{flag_id}" => %{
                "id" => flag_id,
                "name" => flag
              }
            })
          )

        _ ->
          send(self(), {:flag_unselected, flag_id})

          socket
          |> assign(
            :selected_flags,
            Map.drop(socket.assigns.selected_flags, [flag_id])
          )
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-4 space-y-2">
      <h3 class="font-semibold text-gray-800 dark:text-white truncate">
        <%= get_translation(@category.category_translations, @language) %>
      </h3>

      <ol class="flex flex-wrap gap-2 w-full">
        <li :for={flag <- @category.flags}>
          <div
            phx-value-flag={flag.name}
            phx-value-flagid={flag.id}
            phx-target={@myself}
            aria-label="button"
            phx-click={
              if(
                get_flag_styling(
                  @can_select,
                  @selected_flags,
                  flag.id,
                  @opposite_color_flags_selected,
                  flag,
                  @color
                ) != "cursor-not-allowed bg-gray-200 dark:bg-gray-100",
                do: "select_flag",
                else: nil
              )
            }
            class={"rounded-full flex gap-2 items-center  px-3 py-1.5 text-sm font-semibold leading-6  focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2  #{get_flag_styling(
              @can_select,
              @selected_flags,
              flag.id,
              @opposite_color_flags_selected,
              flag,
              @color

            )} "

            }
          >
            <span :if={flag.emoji} class="pr-1.5"><%= flag.emoji %></span>
            <%= get_translation(flag.flag_translations, @language) %>

            <span
              :if={Map.get(@selected_flags, flag.id) != nil}
              class={"inline-flex items-center justify-center w-4 h-4 ms-2 text-xs font-semibold rounded-full " <> get_position_colors(@color)}
            >
              <%= get_flag_index(@user_flags, flag.id) %>
            </span>

            <%= if Enum.member?(@opposite_color_flags_selected, flag.id) do %>
              <p class={get_dot_for_selected_opposite_selected_flag(@color)} />
            <% end %>
          </div>
        </li>
      </ol>
    </div>
    """
  end

  defp get_translation(translations, language) do
    language = String.split(language, "-") |> Enum.at(0)

    translation =
      Enum.find(translations, nil, fn translation -> translation.language == language end)

    translation.name
  end

  defp get_flag_styling(
         can_select,
         selected_flags,
         flag_id,
         opposite_color_flags_selected,
         flag,
         color
       ) do
    if (can_select && !Enum.member?(opposite_color_flags_selected, flag_id)) ||
         (can_select == false && Map.get(selected_flags, flag_id) != nil &&
            !Enum.member?(opposite_color_flags_selected, flag_id)) do
      "cursor-pointer #{if(Map.get(selected_flags, flag.id) != nil, do: "#{get_active_button_colors(color)} text-white shadow-sm", else: "#{get_inactive_button_colors(color)} shadow-none")}"
    else
      get_styling_if_flag_is_white(color, selected_flags, flag)
    end
  end

  defp get_styling_if_flag_is_white(:white, selected_flags, flag) do
    "#{if(Map.get(selected_flags, flag.id) != nil, do: "#{get_active_button_colors(:white)} text-white shadow-sm", else: "#{get_inactive_button_colors(:white)} shadow-none")}"
  end


  defp get_styling_if_flag_is_white(_color, _selected_flags, _flag) do

    "cursor-not-allowed bg-gray-200 dark:bg-gray-100"
  end

  defp get_flag_index(flags, flag_id) do
    case Enum.find_index(flags, fn id -> id == flag_id end) do
      nil -> 1
      index -> index + 1
    end
  end

  defp get_active_button_colors(color) do
    cond do
      color == :green -> "hover:bg-green-500  bg-green-600 focus-visible:outline-green-600"
      color == :red -> "hover:bg-rose-500  bg-rose-600 focus-visible:outline-rose-600"
      true -> "hover:bg-indigo-500  bg-indigo-600 focus-visible:outline-indigo-600"
    end
  end

  defp get_dot_for_selected_opposite_selected_flag(color) do
    cond do
      color == :green -> "w-3 h-3 bg-red-500 rounded-full"
      color == :red -> "w-3 h-3 bg-green-500 rounded-full"
      true -> ""
    end
  end

  defp get_inactive_button_colors(color) do
    cond do
      color == :green ->
        "hover:bg-green-50 bg-green-100 focus-visible:outline-green-100 text-green-600"

      color == :red ->
        "hover:bg-red-50 bg-red-100 focus-visible:outline-red-100 text-red-600"

      true ->
        "hover:bg-indigo-50 bg-indigo-100 focus-visible:outline-indigo-100 text-indigo-600"
    end
  end

  defp get_position_colors(color) do
    cond do
      color == :green -> "text-green-600 bg-green-200"
      color == :red -> "text-rose-600 bg-rose-200"
      true -> "text-indigo-600 bg-indigo-200"
    end
  end
end
