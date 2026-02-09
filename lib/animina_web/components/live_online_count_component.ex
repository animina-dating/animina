defmodule AniminaWeb.LiveOnlineCountComponent do
  @moduledoc """
  Live component that displays a real-time online user count in FIDS
  (Flight Information Display System) style — split-flap digit boxes.

  Shown only to admin users in the navigation bar. Updates in real-time
  via presence_diff forwarding from user_auth.ex. Excludes the admin
  themselves and hides when no other users are online.
  """

  use AniminaWeb, :live_component

  alias AniminaWeb.Presence

  @impl true
  def mount(socket) do
    {:ok, assign(socket, online_count: 0, digits: [0])}
  end

  @impl true
  def update(%{online_count: count} = assigns, socket) do
    digits = split_digits(count)
    {:ok, socket |> assign(assigns) |> assign(online_count: count, digits: digits)}
  end

  def update(%{user_id: user_id} = assigns, socket) do
    count = count_other_users(user_id)
    digits = split_digits(count)
    {:ok, socket |> assign(assigns) |> assign(online_count: count, digits: digits)}
  end

  def update(assigns, socket) do
    user_id = socket.assigns[:user_id]
    count = if user_id, do: count_other_users(user_id), else: Presence.online_user_count()
    digits = split_digits(count)
    {:ok, socket |> assign(assigns) |> assign(online_count: count, digits: digits)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class={if(@online_count > 0, do: "inline-flex items-center gap-1", else: "hidden")}
      title={if(@online_count > 0, do: "#{@online_count} #{gettext("online")}")}
    >
      <div class="inline-flex gap-0.5">
        <span
          :for={digit <- @digits}
          class="fids-digit inline-flex items-center justify-center w-5 h-6 bg-neutral text-neutral-content font-mono text-xs font-bold rounded"
        >
          {digit}
        </span>
      </div>
      <span class="text-[10px] font-semibold tracking-wider uppercase text-base-content/50">
        {gettext("online")}
      </span>
    </div>
    """
  end

  defp count_other_users(user_id) do
    Presence.topic()
    |> Presence.list()
    |> Map.delete(user_id)
    |> map_size()
  end

  defp split_digits(0), do: [0]

  defp split_digits(n) when n > 0 do
    n
    |> Integer.digits()
  end
end
