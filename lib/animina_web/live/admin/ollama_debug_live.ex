defmodule AniminaWeb.Admin.OllamaDebugLive do
  @moduledoc """
  Admin LiveView for viewing Ollama API call debug history.

  Shows live-updating list of recent Ollama calls with full debug info:
  - Timestamp, photo ID, status, duration
  - User info (email, display name)
  - Response, prompt, server URL, model
  - Truncated image data
  """

  use AniminaWeb, :live_view

  alias Animina.FeatureFlags
  alias Animina.FeatureFlags.OllamaDebugStore
  alias Animina.Photos
  alias Animina.Photos.FileManagement
  alias Animina.Photos.OllamaClient

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to new Ollama calls
      Phoenix.PubSub.subscribe(Animina.PubSub, OllamaDebugStore.pubsub_topic())
    end

    debug_enabled = FeatureFlags.ollama_debug_enabled?()
    max_entries = FeatureFlags.ollama_debug_max_entries()
    calls = if debug_enabled, do: OllamaDebugStore.get_recent_calls(max_entries), else: []

    {:ok,
     assign(socket,
       page_title: gettext("Ollama Debug"),
       debug_enabled: debug_enabled,
       max_entries: max_entries,
       calls: calls,
       selected_call: nil,
       selected_call_index: nil,
       prompt_editor: nil
     )}
  end

  @impl true
  def handle_info({:new_ollama_call, call}, socket) do
    # Prepend new call to the list and keep max entries
    max_entries = socket.assigns.max_entries
    calls = [call | socket.assigns.calls] |> Enum.take(max_entries)
    {:noreply, assign(socket, calls: calls)}
  end

  def handle_info({:execute_prompt, prompt, call}, socket) do
    model = call[:model]
    photo_id = call[:photo_id]

    # Fetch the actual image from the file system (stored images are truncated)
    images_result = fetch_image_for_photo(photo_id)

    prompt_editor =
      case images_result do
        {:ok, images} ->
          start_time = System.monotonic_time(:millisecond)

          result =
            OllamaClient.completion(
              model: model,
              prompt: prompt,
              images: images
            )

          duration_ms = System.monotonic_time(:millisecond) - start_time

          case result do
            {:ok, response, server_url} ->
              %{
                socket.assigns.prompt_editor
                | loading: false,
                  result: %{
                    response: response,
                    server_url: server_url,
                    duration_ms: duration_ms
                  },
                  error: nil
              }

            {:error, reason} ->
              %{
                socket.assigns.prompt_editor
                | loading: false,
                  result: nil,
                  error: inspect(reason)
              }
          end

        {:error, reason} ->
          %{
            socket.assigns.prompt_editor
            | loading: false,
              result: nil,
              error: "Could not load image: #{inspect(reason)}"
          }
      end

    {:noreply, assign(socket, prompt_editor: prompt_editor)}
  end

  defp fetch_image_for_photo(nil), do: {:error, :no_photo_id}

  defp fetch_image_for_photo(photo_id) do
    case Photos.get_photo(photo_id) do
      nil ->
        {:error, :photo_not_found}

      photo ->
        # Try original first, then fall back to processed version
        case read_image_file(photo) do
          {:ok, data} -> {:ok, [Base.encode64(data)]}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp read_image_file(photo) do
    # Try original file first
    case FileManagement.original_path(photo) do
      {:ok, path} ->
        File.read(path)

      {:error, :not_found} ->
        # Fall back to processed main version
        processed_path = FileManagement.processed_path(photo, :main)

        if File.exists?(processed_path) do
          File.read(processed_path)
        else
          {:error, :image_not_found}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def handle_event("clear-all", _params, socket) do
    OllamaDebugStore.clear_all()
    {:noreply, assign(socket, calls: [], selected_call: nil)}
  end

  @impl true
  def handle_event("select-call", %{"index" => index}, socket) do
    index = String.to_integer(index)
    call = Enum.at(socket.assigns.calls, index)
    {:noreply, assign(socket, selected_call: call, selected_call_index: index)}
  end

  @impl true
  def handle_event("close-modal", _params, socket) do
    {:noreply, assign(socket, selected_call: nil)}
  end

  @impl true
  def handle_event("toggle-debug", _params, socket) do
    if socket.assigns.debug_enabled do
      FeatureFlags.disable(:ollama_debug_display)
      {:noreply, assign(socket, debug_enabled: false)}
    else
      FeatureFlags.enable(:ollama_debug_display)
      max_entries = socket.assigns.max_entries
      calls = OllamaDebugStore.get_recent_calls(max_entries)
      {:noreply, assign(socket, debug_enabled: true, calls: calls)}
    end
  end

  @impl true
  def handle_event("open-prompt-editor", %{"index" => index}, socket) do
    index = String.to_integer(index)
    call = Enum.at(socket.assigns.calls, index)

    prompt_editor = %{
      call: call,
      edited_prompt: call[:prompt] || "",
      result: nil,
      loading: false,
      error: nil
    }

    {:noreply, assign(socket, prompt_editor: prompt_editor, selected_call: nil)}
  end

  @impl true
  def handle_event("close-prompt-editor", _params, socket) do
    {:noreply, assign(socket, prompt_editor: nil)}
  end

  @impl true
  def handle_event("update-prompt", %{"prompt" => prompt}, socket) do
    prompt_editor = Map.put(socket.assigns.prompt_editor, :edited_prompt, prompt)
    {:noreply, assign(socket, prompt_editor: prompt_editor)}
  end

  @impl true
  def handle_event("send-prompt", params, socket) do
    prompt_editor = socket.assigns.prompt_editor
    call = prompt_editor.call

    # Use prompt from form params if available, otherwise use stored edited_prompt
    prompt = Map.get(params, "prompt", prompt_editor.edited_prompt)

    # Mark as loading and update the edited_prompt
    prompt_editor = %{
      prompt_editor
      | loading: true,
        result: nil,
        error: nil,
        edited_prompt: prompt
    }

    socket = assign(socket, prompt_editor: prompt_editor)

    # Send request asynchronously
    send(self(), {:execute_prompt, prompt, call})

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <%!-- Header --%>
        <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 mb-6">
          <div>
            <h1 class="text-2xl font-bold text-base-content">{gettext("Ollama Debug")}</h1>
            <p class="text-sm text-base-content/70 mt-1">
              {gettext("Live view of Ollama API calls for debugging")}
            </p>
          </div>

          <div class="flex items-center gap-3">
            <label class="flex items-center gap-2 cursor-pointer">
              <span class={[
                "text-sm font-medium",
                if(@debug_enabled, do: "text-success", else: "text-base-content/60")
              ]}>
                {gettext("Debug")}
              </span>
              <input
                type="checkbox"
                class="toggle toggle-success"
                checked={@debug_enabled}
                phx-click="toggle-debug"
              />
            </label>
            <%= if @debug_enabled && length(@calls) > 0 do %>
              <button
                type="button"
                class="btn btn-sm btn-outline btn-error"
                phx-click="clear-all"
                data-confirm={gettext("Clear all debug entries?")}
              >
                <.icon name="hero-trash" class="h-4 w-4" />
                {gettext("Clear All")}
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Stats --%>
        <div class="stats shadow mb-6">
          <div class="stat">
            <div class="stat-title">{gettext("Total Calls")}</div>
            <div class="stat-value text-primary">{length(@calls)}</div>
            <div class="stat-desc">{gettext("Last %{count} stored", count: @max_entries)}</div>
          </div>

          <div class="stat">
            <div class="stat-title">{gettext("Success Rate")}</div>
            <div class="stat-value text-success">
              {calculate_success_rate(@calls)}%
            </div>
            <div class="stat-desc">
              {count_by_status(@calls, :success)} / {length(@calls)}
            </div>
          </div>

          <div class="stat">
            <div class="stat-title">{gettext("Errors")}</div>
            <div class="stat-value text-error">{count_by_status(@calls, :error)}</div>
          </div>
        </div>

        <%!-- Howto Section --%>
        <div class="collapse collapse-arrow bg-base-200 mb-6">
          <input type="checkbox" />
          <div class="collapse-title font-medium">
            <.icon name="hero-question-mark-circle" class="h-5 w-5 inline mr-2" />
            {gettext("How to replay an Ollama call")}
          </div>
          <div class="collapse-content">
            <div class="prose prose-sm max-w-none">
              <h4>{gettext("Using curl (recommended for images)")}</h4>
              <pre class="bg-base-300 p-3 rounded text-xs overflow-x-auto whitespace-pre-wrap"><%= raw(curl_example()) %></pre>

              <h4>{gettext("Using Ollama CLI (text only)")}</h4>
              <pre class="bg-base-300 p-3 rounded text-xs overflow-x-auto whitespace-pre-wrap"><%= raw(cli_example()) %></pre>

              <p class="text-base-content/70">
                {gettext(
                  "Tip: Use the 'Copy curl' button in the detail modal to get a pre-filled command for a specific call."
                )}
              </p>
            </div>
          </div>
        </div>

        <%= if @calls == [] do %>
          <div class="text-center py-16">
            <.icon name="hero-inbox" class="h-16 w-16 mx-auto text-base-content/30 mb-4" />
            <p class="text-lg text-base-content/70">{gettext("No Ollama calls recorded yet.")}</p>
            <p class="text-sm text-base-content/50 mt-1">
              {gettext("Calls will appear here automatically when photos are processed.")}
            </p>
          </div>
        <% else %>
          <%!-- Calls Table --%>
          <div class="overflow-x-auto">
            <table class="table table-zebra">
              <thead>
                <tr>
                  <th>{gettext("Time")}</th>
                  <th>{gettext("Status")}</th>
                  <th>{gettext("Duration")}</th>
                  <th>{gettext("User")}</th>
                  <th>{gettext("Photo ID")}</th>
                  <th>{gettext("Server")}</th>
                  <th>{gettext("Actions")}</th>
                </tr>
              </thead>
              <tbody id="ollama-calls-table" phx-update="stream">
                <%= for {call, index} <- Enum.with_index(@calls) do %>
                  <tr
                    id={"call-#{index}"}
                    class="hover cursor-pointer"
                    phx-click="select-call"
                    phx-value-index={index}
                  >
                    <td class="font-mono text-sm">
                      {format_timestamp(call[:timestamp])}
                    </td>
                    <td>
                      <span class={[
                        "badge badge-sm",
                        if(call[:status] == :success, do: "badge-success", else: "badge-error")
                      ]}>
                        {call[:status]}
                      </span>
                    </td>
                    <td>
                      <%= if call[:duration_ms] do %>
                        <span class={[
                          "font-mono text-sm",
                          duration_color(call[:duration_ms])
                        ]}>
                          {call[:duration_ms]}ms
                        </span>
                      <% else %>
                        <span class="text-base-content/50">-</span>
                      <% end %>
                    </td>
                    <td>
                      <%= if call[:user_display_name] || call[:user_email] do %>
                        <div class="flex flex-col">
                          <%= if call[:user_display_name] do %>
                            <span class="text-sm font-medium">{call[:user_display_name]}</span>
                          <% end %>
                          <%= if call[:user_email] do %>
                            <span class="text-xs text-base-content/60">{call[:user_email]}</span>
                          <% end %>
                        </div>
                      <% else %>
                        <span class="text-base-content/50">-</span>
                      <% end %>
                    </td>
                    <td>
                      <%= if call[:photo_id] do %>
                        <span class="font-mono text-xs">
                          {String.slice(call[:photo_id], 0, 8)}...
                        </span>
                      <% else %>
                        <span class="text-base-content/50">-</span>
                      <% end %>
                    </td>
                    <td>
                      <%= if call[:server_url] do %>
                        <span class="font-mono text-xs">{format_server_url(call[:server_url])}</span>
                      <% else %>
                        <span class="text-base-content/50">-</span>
                      <% end %>
                    </td>
                    <td>
                      <button
                        type="button"
                        class="btn btn-xs btn-ghost"
                        onclick={"copyOllamaDebug(#{index})"}
                        title={gettext("Copy to clipboard")}
                      >
                        <.icon name="hero-clipboard-document" class="h-4 w-4" />
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <%!-- Hidden data for copy functionality --%>
          <script id="ollama-debug-data" type="application/json">
            <%= raw(Jason.encode!(Enum.map(@calls, fn call -> %{
              timestamp: call[:timestamp],
              photo_id: call[:photo_id],
              model: call[:model],
              server_url: call[:server_url],
              duration_ms: call[:duration_ms],
              status: call[:status],
              prompt: call[:prompt],
              response: call[:response],
              error: call[:error],
              user_email: call[:user_email],
              user_display_name: call[:user_display_name],
              images: call[:images]
            } end))) %>
          </script>

          <script>
            function copyOllamaDebug(index) {
              const dataEl = document.getElementById('ollama-debug-data');
              if (dataEl) {
                const allData = JSON.parse(dataEl.textContent);
                const data = allData[index];
                if (data) {
                  const formatted = JSON.stringify(data, null, 2);
                  navigator.clipboard.writeText(formatted).then(() => {
                    // Brief visual feedback
                    const btn = event.currentTarget;
                    const icon = btn.querySelector('svg');
                    if (icon) {
                      icon.style.color = '#22c55e';
                      setTimeout(() => { icon.style.color = ''; }, 1000);
                    }
                  });
                }
              }
            }

            function copyCurlCommand(serverUrl, model, prompt) {
              // Escape prompt for shell
              const escapedPrompt = prompt.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');

              const curlCmd = "# First encode your image:\n" +
                "base64_image=$(base64 < /path/to/your/image.jpg)\n\n" +
                "# Then run:\n" +
                "curl -X POST " + serverUrl + "/api/generate \\\n" +
                "  -H \"Content-Type: application/json\" \\\n" +
                "  -d '{\n" +
                "    \"model\": \"" + model + "\",\n" +
                "    \"prompt\": \"" + escapedPrompt + "\",\n" +
                "    \"images\": [\"'\"$base64_image\"'\"],\n" +
                "    \"stream\": false\n" +
                "  }'";

              navigator.clipboard.writeText(curlCmd).then(() => {
                const btn = event.currentTarget;
                btn.classList.add('btn-success');
                btn.classList.remove('btn-primary');
                setTimeout(() => {
                  btn.classList.remove('btn-success');
                  btn.classList.add('btn-primary');
                }, 1500);
              });
            }
          </script>
        <% end %>

        <%!-- Detail Modal --%>
        <%= if @selected_call do %>
          <div class="modal modal-open" phx-window-keydown="close-modal" phx-key="escape">
            <div class="modal-box max-w-4xl max-h-[90vh]">
              <button
                type="button"
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
                phx-click="close-modal"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>

              <h3 class="font-bold text-lg mb-4">{gettext("Ollama Call Details")}</h3>

              <div class="space-y-4 overflow-y-auto">
                <%!-- Status Row --%>
                <div class="flex flex-wrap items-center gap-3">
                  <span class={[
                    "badge",
                    if(@selected_call[:status] == :success, do: "badge-success", else: "badge-error")
                  ]}>
                    {@selected_call[:status]}
                  </span>
                  <span class="font-mono text-sm">
                    {format_timestamp(@selected_call[:timestamp])}
                  </span>
                  <%= if @selected_call[:duration_ms] do %>
                    <span class="badge badge-ghost">
                      {@selected_call[:duration_ms]}ms
                    </span>
                  <% end %>
                </div>

                <%!-- Info Grid --%>
                <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
                  <div>
                    <div class="text-xs font-medium text-base-content/60 uppercase">
                      {gettext("Photo ID")}
                    </div>
                    <div class="font-mono text-sm break-all">{@selected_call[:photo_id] || "-"}</div>
                  </div>
                  <div>
                    <div class="text-xs font-medium text-base-content/60 uppercase">
                      {gettext("Model")}
                    </div>
                    <div class="font-mono text-sm">{@selected_call[:model] || "-"}</div>
                  </div>
                  <div>
                    <div class="text-xs font-medium text-base-content/60 uppercase">
                      {gettext("Server URL")}
                    </div>
                    <div class="font-mono text-sm break-all">
                      {@selected_call[:server_url] || "-"}
                    </div>
                  </div>
                  <div>
                    <div class="text-xs font-medium text-base-content/60 uppercase">
                      {gettext("User Email")}
                    </div>
                    <div class="text-sm">{@selected_call[:user_email] || "-"}</div>
                  </div>
                  <div>
                    <div class="text-xs font-medium text-base-content/60 uppercase">
                      {gettext("User Name")}
                    </div>
                    <div class="text-sm">{@selected_call[:user_display_name] || "-"}</div>
                  </div>
                </div>

                <%!-- Prompt --%>
                <div>
                  <div class="text-xs font-medium text-base-content/60 uppercase mb-1">
                    {gettext("Prompt")}
                  </div>
                  <pre class="text-sm bg-base-200 rounded p-3 overflow-x-auto whitespace-pre-wrap font-mono max-h-32">{@selected_call[:prompt]}</pre>
                </div>

                <%!-- Response --%>
                <%= if @selected_call[:response] do %>
                  <div>
                    <div class="text-xs font-medium text-base-content/60 uppercase mb-1">
                      {gettext("Response")}
                    </div>
                    <pre class="text-sm bg-base-200 rounded p-3 overflow-x-auto whitespace-pre-wrap font-mono max-h-48">{format_response(@selected_call[:response])}</pre>
                  </div>
                <% end %>

                <%!-- Error --%>
                <%= if @selected_call[:error] do %>
                  <div>
                    <div class="text-xs font-medium text-error uppercase mb-1">
                      {gettext("Error")}
                    </div>
                    <pre class="text-sm bg-error/10 text-error rounded p-3 overflow-x-auto whitespace-pre-wrap font-mono">{@selected_call[:error]}</pre>
                  </div>
                <% end %>

                <%!-- Images (truncated) --%>
                <%= if @selected_call[:images] && length(@selected_call[:images]) > 0 do %>
                  <div>
                    <div class="text-xs font-medium text-base-content/60 uppercase mb-1">
                      {gettext("Images")} ({length(@selected_call[:images])})
                    </div>
                    <div class="space-y-2">
                      <%= for {img, idx} <- Enum.with_index(@selected_call[:images]) do %>
                        <pre class="text-xs bg-base-200 rounded p-2 overflow-x-auto whitespace-pre-wrap font-mono text-base-content/70">
                          [{idx}] {img}
                        </pre>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>

              <div class="modal-action">
                <%= if @selected_call[:images] && length(@selected_call[:images]) > 0 do %>
                  <button
                    type="button"
                    class="btn btn-secondary"
                    phx-click="open-prompt-editor"
                    phx-value-index={@selected_call_index}
                  >
                    <.icon name="hero-pencil-square" class="h-4 w-4" />
                    {gettext("Edit & Resend")}
                  </button>
                <% end %>
                <button
                  type="button"
                  class="btn btn-primary"
                  onclick={"copyCurlCommand('#{escape_for_js(@selected_call[:server_url])}', '#{escape_for_js(@selected_call[:model])}', '#{escape_for_js(@selected_call[:prompt])}')"}
                >
                  <.icon name="hero-command-line" class="h-4 w-4" />
                  {gettext("Copy curl")}
                </button>
                <button type="button" class="btn btn-ghost" phx-click="close-modal">
                  {gettext("Close")}
                </button>
              </div>
            </div>
            <div class="modal-backdrop" phx-click="close-modal"></div>
          </div>
        <% end %>

        <%!-- Prompt Editor Modal --%>
        <%= if @prompt_editor do %>
          <div class="modal modal-open" phx-window-keydown="close-prompt-editor" phx-key="escape">
            <div class="modal-box max-w-4xl max-h-[90vh]">
              <button
                type="button"
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
                phx-click="close-prompt-editor"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>

              <h3 class="font-bold text-lg mb-4">
                <.icon name="hero-pencil-square" class="h-5 w-5 inline mr-2" />
                {gettext("Edit & Resend Prompt")}
              </h3>

              <div class="space-y-4 overflow-y-auto">
                <%!-- Original Info --%>
                <div class="grid grid-cols-2 md:grid-cols-3 gap-4 text-sm">
                  <div>
                    <span class="text-base-content/60">{gettext("Model")}:</span>
                    <span class="font-mono ml-1">{@prompt_editor.call[:model]}</span>
                  </div>
                  <div>
                    <span class="text-base-content/60">{gettext("Images")}:</span>
                    <span class="ml-1">{length(@prompt_editor.call[:images] || [])}</span>
                  </div>
                  <div>
                    <span class="text-base-content/60">{gettext("Original Duration")}:</span>
                    <span class="font-mono ml-1">{@prompt_editor.call[:duration_ms]}ms</span>
                  </div>
                </div>

                <%!-- Prompt Editor --%>
                <form phx-change="update-prompt" phx-submit="send-prompt">
                  <div>
                    <label class="label">
                      <span class="label-text font-medium">{gettext("Prompt")}</span>
                    </label>
                    <textarea
                      class="textarea textarea-bordered w-full font-mono text-sm"
                      rows="8"
                      phx-debounce="100"
                      name="prompt"
                    >{@prompt_editor.edited_prompt}</textarea>
                  </div>

                  <%!-- Send Button --%>
                  <div class="flex justify-end mt-4">
                    <button
                      type="submit"
                      class="btn btn-primary"
                      disabled={@prompt_editor.loading}
                    >
                      <%= if @prompt_editor.loading do %>
                        <span class="loading loading-spinner loading-sm"></span>
                        {gettext("Sending...")}
                      <% else %>
                        <.icon name="hero-paper-airplane" class="h-4 w-4" />
                        {gettext("Send to Ollama")}
                      <% end %>
                    </button>
                  </div>
                </form>

                <%!-- Result --%>
                <%= if @prompt_editor.result do %>
                  <div class="divider">{gettext("Result")}</div>
                  <div class="space-y-3">
                    <div class="flex items-center gap-3 text-sm">
                      <span class="badge badge-success">{gettext("Success")}</span>
                      <span class="font-mono">{@prompt_editor.result.duration_ms}ms</span>
                      <span class="text-base-content/60">
                        {gettext("via")} {@prompt_editor.result.server_url}
                      </span>
                    </div>
                    <div>
                      <div class="text-xs font-medium text-base-content/60 uppercase mb-1">
                        {gettext("Response")}
                      </div>
                      <pre class="text-sm bg-base-200 rounded p-3 overflow-x-auto whitespace-pre-wrap font-mono max-h-64">{format_response(@prompt_editor.result.response)}</pre>
                    </div>
                  </div>
                <% end %>

                <%!-- Error --%>
                <%= if @prompt_editor.error do %>
                  <div class="divider">{gettext("Result")}</div>
                  <div class="alert alert-error">
                    <.icon name="hero-exclamation-circle" class="h-5 w-5" />
                    <div>
                      <div class="font-bold">{gettext("Request Failed")}</div>
                      <pre class="text-xs mt-1 whitespace-pre-wrap">{@prompt_editor.error}</pre>
                    </div>
                  </div>
                <% end %>
              </div>

              <div class="modal-action">
                <button type="button" class="btn btn-ghost" phx-click="close-prompt-editor">
                  {gettext("Close")}
                </button>
              </div>
            </div>
            <div class="modal-backdrop" phx-click="close-prompt-editor"></div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp format_timestamp(nil), do: "-"

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp format_server_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host, port: port} when not is_nil(host) ->
        if port && port not in [80, 443] do
          "#{host}:#{port}"
        else
          host
        end

      _ ->
        url
    end
  end

  defp format_server_url(_), do: "-"

  defp format_response(%{"response" => response}) when is_binary(response), do: response

  defp format_response(response) when is_map(response) do
    case Jason.encode(response, pretty: true) do
      {:ok, json} -> json
      _ -> inspect(response)
    end
  end

  defp format_response(response), do: inspect(response)

  defp calculate_success_rate([]), do: 0

  defp calculate_success_rate(calls) do
    success_count = Enum.count(calls, fn c -> c[:status] == :success end)
    round(success_count / length(calls) * 100)
  end

  defp count_by_status(calls, status) do
    Enum.count(calls, fn c -> c[:status] == status end)
  end

  defp duration_color(ms) when ms < 1000, do: "text-success"
  defp duration_color(ms) when ms < 3000, do: "text-warning"
  defp duration_color(_ms), do: "text-error"

  defp escape_for_js(nil), do: ""

  defp escape_for_js(str) when is_binary(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
  end

  defp escape_for_js(other), do: escape_for_js(to_string(other))

  defp curl_example do
    model = FeatureFlags.ollama_model()

    """
    # 1. Encode your image to base64
    base64_image=$(base64 &lt; /path/to/image.jpg)

    # 2. Send the request
    curl -X POST http://localhost:11434/api/generate \\
      -H "Content-Type: application/json" \\
      -d '{
        "model": "#{model}",
        "prompt": "Your prompt here",
        "images": ["'"$base64_image"'"],
        "stream": false
      }'
    """
    |> String.trim()
  end

  defp cli_example do
    model = FeatureFlags.ollama_model()

    """
    # Note: ollama run does not support image input
    ollama run #{model} "Your prompt here"
    """
    |> String.trim()
  end
end
