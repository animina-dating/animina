defmodule AniminaWeb.ReportComponents do
  @moduledoc """
  Provides Dashboard UI components.
  """
  use Phoenix.Component
  alias Animina.Markdown
  alias Animina.StringHelper
  import AniminaWeb.Gettext
  import AniminaWeb.CoreComponents
  import Phoenix.HTML.Form

  def reports_card(assigns) do
    ~H"""
    <div :if={@reports != []} class="w-[100%] my-8 grid md:grid-cols-3 grid-cols-1 gap-8">
      <%= for report <- @reports do %>
        <.report_card report={report} current_user={@current_user} />
      <% end %>
    </div>
    <div :if={@reports == []} class="w-[100%] my-8 grid md:grid-cols-3 grid-cols-1 gap-8">
      <%= gettext("No Reports Availabile") %>
    </div>
    """
  end

  defp report_card(assigns) do
    ~H"""
    <div class="h-[300px] rounded-md bg-gray-100 dark:bg-gray-800  p-4 flex justify-between flex-col shadow-sm">
      <div class="flex flex-col text-xs text-black dark:text-white  border-b-[0.3px] border-black outline-offset-2 dark:border-white gap-1">
        <div class="w-[100%]  flex justify-between items-center">
          <p>
            <%= format_date(@report.created_at) %>
          </p>

          <p class="capitalize">
            <%= @report.state %>
          </p>
        </div>

        <div class="w-[100%]  flex justify-between items-center">
          <div class="flex flex-col gap-1">
          <p class="italic">  <%= gettext("Accuser") %> </p>
            <.link class="text-blue-500 underline" navigate={"/#{@report.accuser.username}"}>
              <%= @report.accuser.username %>
            </.link>
          </div>

          <div class="flex flex-col justify-end items-end gap-1">
          <p class="italic">  <%= gettext("Accused") %> </p>
            <.link class="text-blue-500 underline" navigate={"/#{@report.accuser.username}"}>
              <%= @report.accused.username %>
            </.link>
          </div>
        </div>
      </div>

      <div class="dark:text-white text-black">
        <%= Markdown.format(
          @report.description
          |> Animina.StringHelper.slice_at_word_boundary(
            150,
            "...",
            true
          )
        ) %>
      </div>

      <div class="flex items-center dark:text-white text-black text-sm gap-4">
        <%= if @report.admin_id do %>
          <p>
            <%= gettext("Reviewed By") %> <span><%= @report.admin.name %></span>
          </p>
        <% else %>
          <button class="w-[100%] dark:bg-gray-900 bg-white  dark:text-white text-black cursor-pointer  rounded-md  flex justify-center items-center p-2">
            <%= gettext("Review Report") %>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_date(date) do
    Timex.format!(date, "{WDshort}, {Mshort} {D}, {YYYY}")
  end
end
