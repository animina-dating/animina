defmodule AniminaWeb.ReportComponents do
  @moduledoc """
  Provides Dashboard UI components.
  """
  use Phoenix.Component
  alias Animina.Markdown
  import AniminaWeb.Gettext
  import Gettext, only: [with_locale: 2]

  def reports_card(assigns) do
    ~H"""
    <div :if={@reports != []} class="w-[100%] my-8 grid md:grid-cols-3 grid-cols-1 gap-8">
      <%= for report <- @reports do %>
        <.report_card language={@language} report={report} current_user={@current_user} />
      <% end %>
    </div>
    <div :if={@reports == []} class="w-[100%] my-8 dark:text-white text-black gap-8">
      <%= with_locale(@language, fn -> %>
        <%= gettext("No Reports Availabile") %>
      <% end) %>
    </div>
    """
  end

  defp report_card(assigns) do
    ~H"""
    <div class="h-[300px] rounded-md bg-gray-100 dark:bg-gray-800  p-4 flex justify-between flex-col shadow-sm">
      <div class="flex flex-col gap-2">
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
              <p class="italic">
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Accuser") %>
                <% end) %>
              </p>
              <.link
                class="text-blue-500 underline"
                id={"accuser-#{@report.accuser_id}-report-#{@report.id}"}
                navigate={"/#{@report.accuser.username}"}
              >
                <%= @report.accuser.username %>
              </.link>
            </div>

            <div class="flex flex-col justify-end items-end gap-1">
              <p class="italic">
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Accused") %>
                <% end) %>
              </p>
              <.link
                class="text-blue-500 underline"
                id={"accused-#{@report.accused_id}-report-#{@report.id}"}
                navigate={"/#{@report.accused.username}"}
              >
                <%= @report.accused.username %>
              </.link>
            </div>
          </div>
        </div>
        <div class="dark:text-white text-sm text-black">
          <%= Markdown.format(
            @report.description
            |> Animina.StringHelper.slice_at_word_boundary(
              200,
              "admin/reports/#{@report.id}",
              true
            )
          ) %>
        </div>
      </div>

      <div class="flex items-center dark:text-white text-black text-sm gap-4">
        <%= if @report.admin_id do %>
          <div class="flex w-[100%] flex-col gap-2">
            <p id={"#{@report.id}-reviewed-by-#{@report.admin_id}"}>
              <%= gettext("Reviewed By") %> <%= @report.admin.name %>
            </p>
            <.link
              id={"review-#{@report.id}"}
              navigate={"/admin/reports/#{@report.id}"}
              class="w-[100%] dark:bg-gray-900 bg-white  dark:text-white text-black cursor-pointer  rounded-md  flex justify-center items-center p-2"
            >
              <%= with_locale(@language, fn -> %>
                <%= gettext("view Report") %>
              <% end) %>
            </.link>
          </div>
        <% else %>
          <.link
            id={"review-#{@report.id}"}
            navigate={"/admin/reports/pending/#{@report.id}/review"}
            class="w-[100%] dark:bg-gray-900 bg-white  dark:text-white text-black cursor-pointer  rounded-md  flex justify-center items-center p-2"
          >
            <%= with_locale(@language, fn -> %>
              <%= gettext("Review Report") %>
            <% end) %>
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  def report_tabs(assigns) do
    ~H"""
    <div class="flex gap-4 items-center">
      <.link
        navigate="/admin/reports/all"
        id="all-reports-tab"
        class={" #{if @current_report_tab == "all" do "text-blue-500 underline" else "dark:text-white text-black" end }   md:text-xl"}
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("All Reports") %>
        <% end) %>
      </.link>
      <.link
        navigate="/admin/reports/pending"
        id="pending-reports-tab"
        class={" #{if @current_report_tab == "pending" do "text-blue-500 underline" else "dark:text-white text-black" end }   md:text-xl"}
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("Pending Reports") %>
        <% end) %>
      </.link>
    </div>
    """
  end

  def no_report(assigns) do
    ~H"""
    <div class="w-[100%] flex flex-col min-h-[30vh] justify-center dark:text-white items-center">
      <p>
        <%= with_locale(@language, fn -> %>
          <%= gettext("This report does not exist or you do not have permission to view it.") %>
        <% end) %>
      </p>
    </div>
    """
  end

  def report_show_card(assigns) do
    ~H"""
    <div>
      <div class="flex flex-col gap-2">
        <div class="flex flex-col  text-black dark:text-white  border-b-[0.3px] border-black outline-offset-2 dark:border-white gap-1">
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
              <p class="italic"><%= gettext("Accuser") %></p>
              <.link class="text-blue-500 underline" navigate={"/#{@report.accuser.username}"}>
                <%= @report.accuser.username %>
              </.link>
            </div>

            <div class="flex flex-col justify-end items-end gap-1">
              <p class="italic"><%= gettext("Accused") %></p>
              <.link class="text-blue-500 underline" navigate={"/#{@report.accuser.username}"}>
                <%= @report.accused.username %>
              </.link>
            </div>
          </div>
        </div>
        <div class="dark:text-white flex flex-col gap-1  text-black">
          <p class="font-medium ">
            <%= with_locale(@language, fn -> %>
              <%= gettext("Description :") %>
            <% end) %>
          </p>
          <p class="text-gray-900 text-sm ">
            <%= Markdown.format(@report.description) %>
          </p>
        </div>

        <div class="dark:text-white flex flex-col gap-1  text-black">
          <p class="font-medium ">
            <%= with_locale(@language, fn -> %>
              <%= gettext("Review :") %>
            <% end) %>
          </p>
          <p class="text-gray-900 text-sm ">
            <%= Markdown.format(@report.internal_memo) %>
          </p>
        </div>

        <%= if @report.admin_id do %>
          <div class="flex w-[100%] flex-col gap-2">
            <p class="italic dark:text-white">
              <%= with_locale(@language, fn -> %>
                <%= gettext("Reviewed By") %>
              <% end) %>
              <%= @report.admin.name %>
            </p>
          </div>
        <% else %>
          <.link
            navigate={"/admin/reports/pending/#{@report.id}/review"}
            class="w-[100%] dark:bg-gray-900 bg-white  dark:text-white text-black cursor-pointer  rounded-md  flex justify-center items-center p-2"
          >
            <%= with_locale(@language, fn -> %>
              <%= gettext("Review Report") %>
            <% end) %>
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_date(date) do
    Timex.format!(date, "{WDshort}, {Mshort} {D}, {YYYY}")
  end
end
