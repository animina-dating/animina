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
    socket =
      socket
      |> assign(assigns)

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "select_flag",
        %{
          "category" => category,
          "categoryid" => category_id,
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
                "category" => %{
                  "id" => category_id,
                  "name" => category
                },
                "flag" => %{
                  "id" => flag_id,
                  "name" => flag
                }
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
      <h3 class="font-semibold text-gray-800 truncate">
        <%= get_translation(@category.category_translations, @language) %>
      </h3>

      <ol class="flex flex-wrap gap-2 w-full">
        <li :for={flag <- @category.flags}>
          <div
            phx-value-category={@category.name}
            phx-value-categoryid={@category.id}
            phx-value-flag={flag.name}
            phx-value-flagid={flag.id}
            phx-target={@myself}
            aria-label="button"
            phx-click={
              if(@can_select || Map.get(@selected_flags, flag.id) != nil,
                do: "select_flag",
                else: nil
              )
            }
            class={
              if(@can_select || (@can_select == false && Map.get(@selected_flags, flag.id) != nil), do: "cursor-pointer ", else: "cursor-not-allowed ") <>
              "rounded-full px-3 py-1.5 text-sm font-semibold leading-6  focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 "
              <> if(Map.get(@selected_flags, flag.id) != nil, do: "hover:bg-indigo-500  bg-indigo-600 focus-visible:outline-indigo-600 text-white shadow-sm", else: "hover:bg-indigo-50  bg-indigo-100 focus-visible:outline-indigo-100 text-indigo-600 shadow-none")
            }
          >
            <%= get_translation(flag.flag_translations, @language) %>
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
end
