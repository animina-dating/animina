defmodule AniminaWeb.MessageComponents do
  @moduledoc """
  Shared components for the messaging system.

  Used by both `MessagesLive` (full-page) and `ChatPanelComponent` (side panel).
  """

  use Phoenix.Component
  use Gettext, backend: AniminaWeb.Gettext

  import AniminaWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders a chat message input with auto-growing textarea and send button.

  ## Attributes

    * `form` — Phoenix form (required)
    * `input_id` — unique textarea HTML id (required)
    * `form_id` — unique form HTML id (required)
    * `draft_key` — localStorage draft key (required)
    * `blocked` — shows "cannot send" message instead of the input (default: false)
    * `size` — `:default` or `:sm` for compact panel use (default: `:default`)
    * `phx_target` — live component target for event routing (default: nil)
    * `typing_event` — phx-change event name (default: "typing")
  """
  attr :form, :any, required: true
  attr :input_id, :string, required: true
  attr :form_id, :string, required: true
  attr :draft_key, :string, required: true
  attr :blocked, :boolean, default: false
  attr :size, :atom, default: :default, values: [:default, :sm]
  attr :phx_target, :any, default: nil
  attr :typing_event, :string, default: "typing"
  attr :spellcheck_enabled, :boolean, default: false
  attr :spellcheck_loading, :boolean, default: false
  attr :spellcheck_has_undo, :boolean, default: false
  attr :greeting_guard_pending, :boolean, default: false

  def chat_input(assigns) do
    assigns =
      assigns
      |> assign(:textarea_class, textarea_class(assigns.size))
      |> assign(:btn_class, btn_class(assigns.size))
      |> assign(:icon_class, icon_class(assigns.size))
      |> assign(:wrapper_class, wrapper_class(assigns.size))

    ~H"""
    <div class={@wrapper_class}>
      <%= if @blocked do %>
        <div class={blocked_class(@size)}>
          {gettext("You cannot send messages in this conversation")}
        </div>
      <% else %>
        <.form
          for={@form}
          id={@form_id}
          phx-submit="send_message"
          phx-change={@typing_event}
          phx-target={@phx_target}
        >
          <div class="flex gap-2 items-end">
            <textarea
              id={@input_id}
              name="message[content]"
              placeholder={gettext("Type a message...")}
              class={@textarea_class}
              rows="1"
              phx-debounce="300"
              phx-hook="MessageInput"
              data-draft-key={@draft_key}
              style="overflow-y: hidden;"
            >{Phoenix.HTML.Form.normalize_value("textarea", @form[:content].value)}</textarea>
            <span :if={@spellcheck_enabled} class="self-end">
              <%= cond do %>
                <% @spellcheck_loading -> %>
                  <span class={["btn btn-ghost btn-circle", spellcheck_btn_class(@size)]}>
                    <span class={spellcheck_spinner_class(@size)} />
                  </span>
                <% @spellcheck_has_undo -> %>
                  <button
                    type="button"
                    phx-click="undo_spellcheck"
                    phx-target={@phx_target}
                    class={["btn btn-ghost btn-circle text-primary", spellcheck_btn_class(@size)]}
                    title={gettext("Undo correction")}
                  >
                    <.icon name="hero-arrow-uturn-left" class={@icon_class} />
                  </button>
                <% true -> %>
                  <button
                    type="button"
                    phx-click="spellcheck"
                    phx-target={@phx_target}
                    class={[
                      "btn btn-ghost btn-circle text-base-content/40 hover:text-primary",
                      spellcheck_btn_class(@size)
                    ]}
                    title={gettext("Check spelling & grammar")}
                  >
                    <.icon name="hero-sparkles" class={@icon_class} />
                  </button>
              <% end %>
            </span>
            <button
              type="submit"
              class={@btn_class}
              aria-label={gettext("Send message")}
              disabled={@greeting_guard_pending}
            >
              <%= if @greeting_guard_pending do %>
                <span class="loading loading-spinner loading-xs" />
              <% else %>
                <.icon name="hero-paper-airplane" class={@icon_class} />
              <% end %>
            </button>
          </div>
          <div class={hint_class(@size)}>
            <span class="truncate">
              {gettext("**bold** *italic* `code` — Enter to send, Shift+Enter for new line")}
            </span>
          </div>
        </.form>
      <% end %>
    </div>
    """
  end

  defp textarea_class(:default),
    do:
      "flex-1 textarea bg-base-200 rounded-xl border-base-300 focus:border-primary focus:ring-1 focus:ring-primary/30 resize-none leading-snug"

  defp textarea_class(:sm),
    do:
      "flex-1 textarea textarea-sm bg-base-200 rounded-xl border-base-300 focus:border-primary focus:ring-1 focus:ring-primary/30 resize-none leading-snug"

  defp btn_class(:default), do: "btn btn-primary btn-circle self-end"
  defp btn_class(:sm), do: "btn btn-primary btn-circle btn-sm self-end"

  defp icon_class(:default), do: "h-5 w-5"
  defp icon_class(:sm), do: "h-4 w-4"

  defp spellcheck_btn_class(:default), do: ""
  defp spellcheck_btn_class(:sm), do: "btn-sm"

  defp spellcheck_spinner_class(:default), do: "loading loading-spinner loading-xs"
  defp spellcheck_spinner_class(:sm), do: "loading loading-spinner loading-xs"

  defp wrapper_class(:default), do: "pt-4 border-t border-base-300"
  defp wrapper_class(:sm), do: "px-4 py-3 border-t border-base-300 shrink-0"

  defp hint_class(:default), do: "mt-1.5 text-xs text-base-content/70"
  defp hint_class(:sm), do: "mt-1 text-[11px] text-base-content/70"

  defp blocked_class(:default), do: "text-center text-base-content/50 py-4"
  defp blocked_class(:sm), do: "text-center text-base-content/50 py-2 text-sm"

  defdelegate render_markdown(content),
    to: AniminaWeb.Helpers.MarkdownHelpers,
    as: :render_message_markdown

  defdelegate strip_markdown(content), to: AniminaWeb.Helpers.MarkdownHelpers
end
