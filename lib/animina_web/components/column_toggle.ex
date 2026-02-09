defmodule AniminaWeb.ColumnToggle do
  @moduledoc """
  Shared column toggle button group for 1/2/3 column layouts.
  """

  use Phoenix.Component
  use Gettext, backend: AniminaWeb.Gettext

  attr :columns, :integer, required: true
  attr :event, :string, default: "change_columns"

  def column_toggle(assigns) do
    ~H"""
    <div class="flex justify-end mb-4">
      <div class="flex flex-row gap-1">
        <button
          type="button"
          phx-click={@event}
          phx-value-columns="1"
          class={["btn btn-sm", @columns == 1 && "btn-active"]}
          aria-label={gettext("Single column")}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <rect x="6" y="3" width="12" height="18" rx="1" stroke-width="2" />
          </svg>
        </button>
        <button
          type="button"
          phx-click={@event}
          phx-value-columns="2"
          class={["btn btn-sm", @columns == 2 && "btn-active"]}
          aria-label={gettext("Two columns")}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <rect x="3" y="3" width="7" height="18" rx="1" stroke-width="2" />
            <rect x="14" y="3" width="7" height="18" rx="1" stroke-width="2" />
          </svg>
        </button>
        <button
          type="button"
          phx-click={@event}
          phx-value-columns="3"
          class={["btn btn-sm hidden md:inline-flex", @columns == 3 && "btn-active"]}
          aria-label={gettext("Three columns")}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <rect x="2" y="3" width="5" height="18" rx="1" stroke-width="2" />
            <rect x="9.5" y="3" width="5" height="18" rx="1" stroke-width="2" />
            <rect x="17" y="3" width="5" height="18" rx="1" stroke-width="2" />
          </svg>
        </button>
      </div>
    </div>
    """
  end
end
