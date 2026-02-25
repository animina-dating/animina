defmodule AniminaWeb.Admin.AdsLive do
  use AniminaWeb, :live_view

  alias Animina.ActivityLog
  alias Animina.Ads
  alias Animina.Ads.Ad
  alias Animina.Ads.QrCode
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.AdminHelpers, only: [parse_int: 2]

  use AniminaWeb.Helpers.PaginationHelpers, filter_events: []

  @default_per_page 25

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: gettext("Ad Campaigns"),
       show_form: false,
       form: to_form(%{"description" => "", "starts_on" => "", "ends_on" => ""})
     )
     |> stream(:ads, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_int(params["page"], 1)
    per_page = parse_int(params["per_page"], @default_per_page)

    result = Ads.list_ads(page: page, per_page: per_page)

    {:noreply,
     socket
     |> assign(
       page: result.page,
       per_page: result.per_page,
       total_count: result.total_count,
       total_pages: result.total_pages
     )
     |> stream(:ads, result.entries, reset: true)}
  end

  @impl true
  def handle_event("toggle-form", _params, socket) do
    if socket.assigns.show_form do
      # Closing the form — no check needed
      {:noreply, assign(socket, show_form: false)}
    else
      case QrCode.check_dependencies() do
        :ok ->
          {:noreply, assign(socket, show_form: true)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  def handle_event(
        "create-ad",
        %{"description" => desc, "starts_on" => starts, "ends_on" => ends},
        socket
      ) do
    attrs = %{
      description: if(desc == "", do: nil, else: desc),
      starts_on: parse_date(starts),
      ends_on: parse_date(ends)
    }

    case Ads.create_ad(attrs) do
      {:ok, ad} ->
        qr_result = generate_qr(ad)
        admin = socket.assigns.current_scope.user

        ActivityLog.log(
          "admin",
          "ad_created",
          "Admin #{admin.display_name} created ad ##{ad.number}",
          actor_id: admin.id,
          metadata: %{"ad_id" => ad.id, "ad_number" => ad.number}
        )

        socket =
          case qr_result do
            {:ok, _path} ->
              put_flash(
                socket,
                :info,
                gettext("Ad #%{number} created with QR code.", number: ad.number)
              )

            {:error, reason} ->
              put_flash(
                socket,
                :warning,
                gettext("Ad #%{number} created, but QR generation failed: %{reason}",
                  number: ad.number,
                  reason: reason
                )
              )
          end

        {:noreply,
         socket
         |> assign(show_form: false)
         |> push_patch(to: build_path(socket, %{}))}

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)

        {:noreply,
         put_flash(socket, :error, gettext("Failed to create ad: %{errors}", errors: errors))}
    end
  end

  defp generate_qr(ad) do
    case QrCode.generate(ad) do
      {:ok, path} ->
        case Ads.update_qr_code_path(ad, path) do
          {:ok, _updated_ad} -> {:ok, path}
          {:error, _changeset} -> {:error, "QR code generated but failed to save path"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil

  defp parse_date(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
  end

  defp build_path(socket, overrides) do
    params =
      %{
        "page" => socket.assigns[:page],
        "per_page" => socket.assigns[:per_page]
      }
      |> Map.merge(overrides)
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Map.new()

    ~p"/admin/ads?#{params}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto">
        <.breadcrumb_nav>
          <:crumb navigate={~p"/admin"}>{gettext("Admin")}</:crumb>
          <:crumb>{gettext("Ad Campaigns")}</:crumb>
        </.breadcrumb_nav>

        <div class="flex items-center justify-between mb-6">
          <.header>
            {gettext("Ad Campaigns")}
            <:subtitle>{gettext("%{count} total", count: @total_count)}</:subtitle>
          </.header>
          <button phx-click="toggle-form" class="btn btn-primary btn-sm">
            <.icon name="hero-plus-mini" class="w-4 h-4" />
            {gettext("New Ad")}
          </button>
        </div>

        <div :if={@show_form} class="card bg-base-200 p-6 mb-6">
          <h3 class="text-lg font-medium mb-4">{gettext("Create New Ad")}</h3>
          <form phx-submit="create-ad" class="space-y-4">
            <div class="fieldset">
              <label class="label">{gettext("Description")}</label>
              <input
                type="text"
                name="description"
                class="input input-bordered w-full"
                placeholder={gettext("e.g. Magazine ABC, page 12")}
              />
            </div>
            <div class="grid grid-cols-2 gap-4">
              <div class="fieldset">
                <label class="label">{gettext("Start date")}</label>
                <input type="date" name="starts_on" class="input input-bordered w-full" />
              </div>
              <div class="fieldset">
                <label class="label">{gettext("End date")}</label>
                <input type="date" name="ends_on" class="input input-bordered w-full" />
              </div>
            </div>
            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary btn-sm">{gettext("Create")}</button>
              <button type="button" phx-click="toggle-form" class="btn btn-ghost btn-sm">
                {gettext("Cancel")}
              </button>
            </div>
          </form>
        </div>

        <div class="overflow-x-auto">
          <table class="table table-zebra w-full">
            <thead>
              <tr>
                <th>#</th>
                <th>{gettext("Description")}</th>
                <th>{gettext("Status")}</th>
                <th>{gettext("Visits")}</th>
                <th></th>
              </tr>
            </thead>
            <tbody id="ads" phx-update="stream">
              <tr :for={{dom_id, ad} <- @streams.ads} id={dom_id} class="hover">
                <td class="font-mono">{ad.number}</td>
                <td>{ad.description || "—"}</td>
                <td>
                  <span class={[
                    "badge badge-sm",
                    if(Ad.active?(ad), do: "badge-success", else: "badge-neutral")
                  ]}>
                    {if(Ad.active?(ad), do: gettext("active"), else: gettext("inactive"))}
                  </span>
                </td>
                <td>{Ads.count_visits(ad.id)}</td>
                <td>
                  <.link navigate={~p"/admin/ads/#{ad.id}"} class="btn btn-ghost btn-xs">
                    {gettext("Details")}
                  </.link>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div :if={@total_count == 0} class="text-center py-12 text-base-content/50">
          {gettext("No ads created yet.")}
        </div>

        <div :if={@total_pages > 1} class="mt-6 flex items-center justify-between">
          <.per_page_selector per_page={@per_page} sizes={[10, 25, 50]} />
          <.pagination page={@page} total_pages={@total_pages} />
        </div>
      </div>
    </Layouts.app>
    """
  end
end
