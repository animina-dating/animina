defmodule AniminaWeb.UserLive.BlockedContacts do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.ContactBlacklist

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.settings_header
          title={gettext("Blocked Contacts")}
          subtitle={
            gettext(
              "Prevent ex-partners, friends, or colleagues from seeing your profile — and you won't see theirs."
            )
          }
        />

        <%!-- Add form --%>
        <form id="blocked-contact-form" phx-submit="add_entry" class="mb-8">
          <div class="flex flex-col sm:flex-row gap-3">
            <div class="flex-1">
              <input
                type="text"
                name="value"
                value=""
                placeholder={gettext("Phone number or email")}
                class="input input-bordered w-full"
                phx-blur="normalize_value"
                autocomplete="off"
              />
            </div>
            <div class="sm:w-48">
              <input
                type="text"
                name="label"
                value=""
                placeholder={gettext("Label (optional)")}
                class="input input-bordered w-full"
                maxlength="100"
              />
            </div>
            <button type="submit" class="btn btn-primary shrink-0">
              <.icon name="hero-plus" class="h-4 w-4 mr-1" />
              {gettext("Add")}
            </button>
          </div>
        </form>

        <%!-- Counter + Filter/Sort controls --%>
        <div class="flex flex-col sm:flex-row sm:items-center gap-3 mb-4">
          <div class="flex items-center gap-2 flex-1">
            <h2 class="text-xs font-semibold uppercase tracking-wider text-base-content/50">
              {gettext("Blocked contacts")}
            </h2>
            <span class="text-xs text-base-content/50">
              {@count}/{ContactBlacklist.max_entries()}
            </span>
          </div>

          <div :if={@count > 0} class="flex items-center gap-2">
            <form id="filter-form" phx-change="filter" class="flex-1 sm:flex-none">
              <input
                type="text"
                name="filter"
                value={@filter}
                placeholder={gettext("Filter...")}
                class="input input-bordered input-sm w-full sm:w-48"
                phx-debounce="200"
                autocomplete="off"
              />
            </form>

            <form id="sort-select" phx-change="sort">
              <select name="sort" class="select select-bordered select-sm">
                <option value="newest" selected={@sort == "newest"}>
                  {gettext("Newest first")}
                </option>
                <option value="oldest" selected={@sort == "oldest"}>
                  {gettext("Oldest first")}
                </option>
                <option value="value_asc" selected={@sort == "value_asc"}>
                  {gettext("A–Z")}
                </option>
                <option value="value_desc" selected={@sort == "value_desc"}>
                  {gettext("Z–A")}
                </option>
              </select>
            </form>
          </div>
        </div>

        <%!-- Entries list --%>
        <div :if={@filtered_entries != []} class="space-y-3">
          <div
            :for={entry <- @filtered_entries}
            class="flex items-center gap-4 p-4 rounded-lg border border-base-300"
          >
            <span class="text-base-content/60">
              <.icon
                name={if(entry.entry_type == "phone", do: "hero-phone", else: "hero-envelope")}
                class="h-5 w-5"
              />
            </span>
            <div class="flex-1 min-w-0">
              <div class="font-semibold text-sm text-base-content">
                {entry.label || display_value(entry)}
              </div>
              <div class="text-xs text-base-content/60 mt-0.5">
                <span :if={entry.label}>{display_value(entry)}<span> · </span></span>
                {gettext("Added %{date}", date: format_date(entry.inserted_at))}
              </div>
            </div>
            <button
              phx-click="delete_entry"
              phx-value-id={entry.id}
              data-confirm={gettext("Are you sure you want to unblock this contact?")}
              class="btn btn-ghost btn-sm text-error"
            >
              <.icon name="hero-trash" class="h-4 w-4" />
            </button>
          </div>
        </div>

        <%!-- No results from filter --%>
        <div
          :if={@filtered_entries == [] && @count > 0}
          class="text-center py-8 text-base-content/50"
        >
          <.icon name="hero-magnifying-glass" class="h-8 w-8 mx-auto mb-3 opacity-50" />
          <p class="text-sm">
            {gettext("No contacts match \"%{filter}\".", filter: @filter)}
          </p>
        </div>

        <%!-- Empty state --%>
        <div :if={@count == 0} class="text-center py-12 text-base-content/50">
          <.icon name="hero-shield-check" class="h-12 w-12 mx-auto mb-4 opacity-50" />
          <p class="text-sm">{gettext("No contacts blocked yet.")}</p>
          <p class="text-xs mt-1">
            {gettext("Add phone numbers or email addresses of people you want to hide from.")}
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    entries = ContactBlacklist.list_entries(user)

    socket =
      socket
      |> assign(:page_title, gettext("Blocked Contacts"))
      |> assign(:entries, entries)
      |> assign(:count, length(entries))
      |> assign(:filter, "")
      |> assign(:sort, "newest")
      |> assign(:filtered_entries, entries)

    {:ok, socket}
  end

  @impl true
  def handle_event("add_entry", %{"value" => value} = params, socket) do
    user = socket.assigns.current_scope.user
    label = params["label"]
    label = if label == "", do: nil, else: label

    attrs = %{value: String.trim(value), label: label}

    case Accounts.add_contact_blacklist_entry(user, attrs) do
      {:ok, _entry} ->
        entries = ContactBlacklist.list_entries(user)

        socket =
          socket
          |> assign(:entries, entries)
          |> assign(:count, length(entries))
          |> apply_filter_and_sort()
          |> put_flash(:info, gettext("Contact blocked."))

        {:noreply, socket}

      {:error, :limit_reached} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("You have reached the maximum of %{max} blocked contacts.",
             max: ContactBlacklist.max_entries()
           )
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        message =
          changeset
          |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
          |> Enum.map_join(", ", fn {_field, msgs} -> Enum.join(msgs, ", ") end)

        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("delete_entry", %{"id" => entry_id}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.remove_contact_blacklist_entry(user, entry_id) do
      {:ok, _} ->
        entries = ContactBlacklist.list_entries(user)

        socket =
          socket
          |> assign(:entries, entries)
          |> assign(:count, length(entries))
          |> apply_filter_and_sort()
          |> put_flash(:info, gettext("Contact unblocked."))

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not remove contact."))}
    end
  end

  def handle_event("filter", %{"filter" => filter}, socket) do
    socket =
      socket
      |> assign(:filter, filter)
      |> apply_filter_and_sort()

    {:noreply, socket}
  end

  def handle_event("sort", %{"sort" => sort}, socket) do
    socket =
      socket
      |> assign(:sort, sort)
      |> apply_filter_and_sort()

    {:noreply, socket}
  end

  def handle_event("normalize_value", %{"value" => value}, socket) do
    value = String.trim(value)

    if value != "" && !String.contains?(value, "@") do
      case ContactBlacklist.normalize_phone(value) do
        {:ok, normalized} ->
          {:noreply,
           push_event(socket, "set_input_value", %{selector: "[name=value]", value: normalized})}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  defp apply_filter_and_sort(socket) do
    entries = socket.assigns.entries
    filter = socket.assigns.filter
    sort = socket.assigns.sort

    filtered =
      if filter == "" do
        entries
      else
        term = String.downcase(filter)

        Enum.filter(entries, fn entry ->
          String.contains?(String.downcase(entry.value), term) ||
            (entry.label && String.contains?(String.downcase(entry.label), term))
        end)
      end

    sorted = sort_entries(filtered, sort)

    assign(socket, :filtered_entries, sorted)
  end

  defp sort_entries(entries, "newest"),
    do: Enum.sort_by(entries, & &1.inserted_at, {:desc, DateTime})

  defp sort_entries(entries, "oldest"),
    do: Enum.sort_by(entries, & &1.inserted_at, {:asc, DateTime})

  defp sort_entries(entries, "value_asc"), do: Enum.sort_by(entries, & &1.value)
  defp sort_entries(entries, "value_desc"), do: Enum.sort_by(entries, & &1.value, :desc)
  defp sort_entries(entries, _), do: entries

  defp display_value(%{entry_type: "phone", value: e164}) do
    format_phone(e164)
  end

  defp display_value(%{value: value}), do: value

  defp format_phone(e164) when is_binary(e164) do
    case ExPhoneNumber.parse(e164, nil) do
      {:ok, parsed} -> ExPhoneNumber.format(parsed, :international)
      _ -> e164
    end
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
