defmodule Animina.HotDeploy do
  @moduledoc """
  Watches for hot upgrade signals and applies code changes without restarting.

  This module implements filesystem-based hot code upgrades for Phoenix releases.
  The deploy script copies new beam files into the hot-upgrades directory and
  creates a `.reload` sentinel file. This GenServer detects the sentinel and
  loads the updated modules into the running VM.

  ## How it works

  1. `deploy.sh` extracts a new release and copies its `lib/` tree into
     the configured `upgrades_dir`.
  2. `deploy.sh` touches `upgrades_dir/.reload` to signal this process.
  3. This GenServer detects the sentinel, loads every `.beam` file found
     under `upgrades_dir/lib/`, purges old module versions, and deletes
     the sentinel so the same upgrade isn't applied twice.

  ## Configuration (config/runtime.exs)

      config :animina, Animina.HotDeploy,
        enabled: true,
        upgrades_dir: "/var/www/animina/shared/hot-upgrades",
        check_interval: 10_000

  ## Startup reapply

  On application boot `startup_reapply_current/0` is called so that a
  release that was deployed via hot upgrade and then cold-restarted still
  picks up the latest code from the upgrades directory.
  """

  use GenServer
  require Logger

  @default_check_interval 10_000

  # --- Public API -----------------------------------------------------------

  @doc """
  Called during Application.start/2 to reapply the most recent hot upgrade
  after a cold restart, ensuring the running code matches what was deployed.
  """
  def startup_reapply_current do
    config = Application.get_env(:animina, __MODULE__, [])
    lib_dir = reapply_lib_dir(config)

    if lib_dir do
      try do
        Logger.info("[HotDeploy] Reapplying current hot upgrade from #{lib_dir}")
        load_beam_files(lib_dir, purge: false)
      rescue
        e ->
          Logger.error("[HotDeploy] Startup reapply failed: #{Exception.message(e)}")
      catch
        kind, reason ->
          Logger.error("[HotDeploy] Startup reapply failed: #{inspect(kind)} #{inspect(reason)}")
      end
    end

    :ok
  end

  defp reapply_lib_dir(config) do
    upgrades_dir = config[:upgrades_dir]

    if config[:enabled] && upgrades_dir && File.dir?(upgrades_dir) do
      lib_dir = Path.join(upgrades_dir, "lib")
      if File.dir?(lib_dir), do: lib_dir
    end
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # --- GenServer callbacks ---------------------------------------------------

  @impl true
  def init(_opts) do
    config = Application.get_env(:animina, __MODULE__, [])

    if config[:enabled] do
      interval = config[:check_interval] || @default_check_interval
      upgrades_dir = config[:upgrades_dir]

      state = %{
        upgrades_dir: upgrades_dir,
        check_interval: interval
      }

      schedule_check(interval)
      Logger.info("[HotDeploy] Watching #{upgrades_dir} every #{interval}ms")
      {:ok, state}
    else
      Logger.info("[HotDeploy] Disabled, not starting watcher")
      :ignore
    end
  end

  @impl true
  def handle_info(:check_for_upgrade, state) do
    sentinel = Path.join(state.upgrades_dir, ".reload")

    if File.exists?(sentinel) do
      Logger.info("[HotDeploy] Upgrade signal detected, loading new code...")
      lib_dir = Path.join(state.upgrades_dir, "lib")

      if File.dir?(lib_dir) do
        {loaded, errors} = load_beam_files(lib_dir, purge: true)
        Logger.info("[HotDeploy] Loaded #{loaded} modules, #{errors} errors")
      end

      File.rm(sentinel)
      Logger.info("[HotDeploy] Hot upgrade complete")
    end

    schedule_check(state.check_interval)
    {:noreply, state}
  end

  # --- Private ---------------------------------------------------------------

  defp schedule_check(interval) do
    Process.send_after(self(), :check_for_upgrade, interval)
  end

  defp load_beam_files(lib_dir, opts) do
    purge? = Keyword.get(opts, :purge, true)

    beam_files =
      lib_dir
      |> Path.join("**/*.beam")
      |> Path.wildcard()

    results = Enum.map(beam_files, &load_beam_file(&1, purge?))

    loaded = Enum.count(results, &(&1 == :ok))
    errors = Enum.count(results, &(&1 == :error))
    {loaded, errors}
  end

  defp load_beam_file(beam_path, purge?) do
    module_name =
      beam_path
      |> Path.basename(".beam")
      |> String.to_atom()

    binary = File.read!(beam_path)

    case :code.load_binary(module_name, ~c"#{beam_path}", binary) do
      {:module, ^module_name} ->
        if purge?, do: :code.purge(module_name)
        :ok

      {:error, reason} ->
        Logger.warning("[HotDeploy] Failed to load #{module_name}: #{inspect(reason)}")
        :error
    end
  end
end
