defmodule Chain do
  @moduledoc """
  Default module for controlling different EVM's 
  """

  alias Chain.EVM.Implementation.{Geth, Ganache}
  alias Chain.EVM.Config
  alias Chain.Watcher

  require Logger

  # get timeout for call requests
  @timeout Application.get_env(:chain, :kill_timeout)

  @typedoc """
  Chain EVM type. 

  Available types are:
   - `:ganache` -  Ganache blockchain
   - `:geth` - Geth evm
   - `:parity` - Parity evm
  """
  @type evm_type :: :ganache | :geth | :parity

  @typedoc """
  Big random number generated by `Chain.unique_id/0` that identifiers new chain id
  """
  @type evm_id :: binary()

  @typedoc """
  Default account definition for chain
  Might be in 2 different variants: 
   - `binary` - Just account address
   - `{binary, non_neg_integer()} - Address, balance.
  ```
  """
  @type account :: binary | {binary, non_neg_integer()}

  @doc """
  Start a new EVM using given configuration
  It will generate unique ID for new evm process
  """
  @spec start(Chain.EVM.Config.t()) :: {:ok, Chain.evm_id()} | {:error, term()}
  def start(%Config{type: :geth} = config), do: start_evm(Geth, config)

  def start(%Config{type: :ganache} = config), do: start_evm(Ganache, config)

  def start(%Config{type: _}), do: {:error, :unsuported_evm_type}

  @doc """
  Stop started EVM instance
  """
  @spec stop(Chain.evm_id()) :: :ok
  def stop(id),
    do: GenServer.cast(get_pid!(id), :stop)

  @doc """
  Check if chain with given id exist
  """
  @spec exists?(Chain.evm_id()) :: boolean()
  def exists?(id), do: nil != get_pid(id)

  @doc """
  Check if chain with given id exist and alive
  """
  @spec alive?(Chain.evm_id()) :: boolean()
  def alive?(id), do: nil != get_pid(id)

  @doc """
  Generate uniq ID

  It also checks if such ID exist in runing processes list
  and checks if chain db exist for this `id`
  """
  @spec unique_id() :: Chain.evm_id()
  def unique_id() do
    <<new_unique_id::big-integer-size(8)-unit(8)>> = :crypto.strong_rand_bytes(8)
    new_unique_id = to_string(new_unique_id)

    with nil <- get_pid(new_unique_id),
         false <- File.exists?(evm_db_path(new_unique_id)) do
      new_unique_id
    else
      _ ->
        unique_id()
    end
  end

  @doc """
  Load details for running chain.
  """
  @spec details(Chain.evm_id()) :: {:ok, Chain.EVM.Process.t()} | {:error, term()}
  def details(_id), do: {:error, "not implemented yet"}

  @doc """
  Clean everything related to this chain.
  If chain is running - it might cause some issues.
  Please validate before removing.
  """
  @spec clean(Chain.evm_id()) :: :ok | {:error, term()}
  def clean(_id), do: {:error, "not implemented yet"}

  @doc """
  Start automining feature
  """
  @spec start_mine(Chain.evm_id()) :: :ok | {:error, term()}
  def start_mine(id),
    do: GenServer.cast(get_pid!(id), :start_mine)

  @doc """
  Stop automining feature
  """
  @spec stop_mine(Chain.evm_id()) :: :ok | {:error, term()}
  def stop_mine(id),
    do: GenServer.cast(get_pid!(id), :stop_mine)

  @doc """
  Generates new chain snapshot and places it into given path
  If path does not exist - system will try to create this path

  **Note** this spanshot will be taken based on chain files. 
  For chains with internal shnapshot features - you might use `Chain.take_internal_snapshot/1`

  Function will return details about newly generated snapshot in format:
  `{:ok, Chain.Snapshot.Details.t()}`
  """
  @spec take_snapshot(Chain.evm_id(), binary) :: {:ok, binary} | {:error, term()}
  def take_snapshot(id, description \\ ""),
    do: GenServer.cast(get_pid!(id), {:take_snapshot, description})

  @doc """
  Revert previously generated snapshot.
  For `ganache` chain you could provide `id` for others - path to snapshot
  """
  @spec revert_snapshot(Chain.evm_id(), Chain.Snapshot.Details.t()) :: :ok | {:error, term()}
  def revert_snapshot(id, snapshot),
    do: GenServer.cast(get_pid!(id), {:revert_snapshot, snapshot})

  @doc """
  Take internal snapshot on chain. 
  That function should use internal chain snapshoting features
  For example for ganache there is `evm_snapshot` command
  """
  @spec take_internal_snapshot(Chain.evm_id()) :: {:ok, binary | number} | {:error, term()}
  def take_internal_snapshot(id),
    do: GenServer.call(get_pid!(id), :take_internal_snapshot, @timeout)

  @doc """
  Reverting chain to given shapshot id.
  If chain missing internal snapshoting features it might ignore this function.
  """
  @spec revert_internal_snapshot(Chain.evm_id(), binary | number) :: :ok | {:error, term()}
  def revert_internal_snapshot(id, snapshot_id),
    do: GenServer.call(get_pid!(id), {:revert_internal_snapshot, snapshot_id})

  @doc """
  Load list of evms version used in app
  """
  @spec version() :: binary
  def version() do
    {:ok, v} = :application.get_key(:chain, :vsn)

    """

    Application version: #{to_string(v)}

    ==========================================
    #{Chain.EVM.Implementation.Geth.version()}
    ==========================================
    #{Chain.EVM.Implementation.Ganache.version()}
    ==========================================
    """
  end

  # Try lo load pid by given id
  defp get_pid(id) do
    case Registry.lookup(Chain.EVM.Registry, id) do
      [{pid, _}] ->
        pid

      _ ->
        nil
    end
  end

  # Same as `get_pid\1` but will raise in case of issue
  defp get_pid!(id) do
    case get_pid(id) do
      nil ->
        raise "No pid found"

      pid ->
        pid
    end
  end

  # Generate EVM DB path for chain
  defp evm_db_path(id) do
    Application.get_env(:chain, :base_path, "/tmp")
    |> Path.expand()
    |> Path.join(id)
  end

  # Generate random port in range of 7000-8999
  # and checks if it's already in use - regenerate it
  defp unused_port() do
    port =
      7000..8999
      |> Enum.random()

    case Watcher.port_in_use?(port) do
      false ->
        port

      true ->
        unused_port()
    end
  end

  # Try to start evm using given module/config
  defp start_evm(module, %Config{id: nil} = config),
    do: start_evm(module, %Config{config | id: unique_id()})

  # if no db_path configured - system will geenrate new one
  defp start_evm(module, %Config{id: id, db_path: ""} = config) do
    path = evm_db_path(id)
    Logger.debug("#{id}: Chain DB path not configured will generate #{path}")
    start_evm(module, %Config{config | db_path: path})
  end

  # Check http_port and assign random one
  defp start_evm(module, %Config{http_port: nil} = config),
    do: start_evm(module, %Config{config | http_port: unused_port()})

  # For Ganache ws_port should be same as http_port
  # so in case of different we have to reconfigure them
  defp start_evm(Ganache, %Config{http_port: port, ws_port: ws_port} = config)
       when port != ws_port,
       do: start_evm(Ganache, %Config{config | ws_port: port})

  # Check ws_port and assign random one
  defp start_evm(module, %Config{ws_port: nil} = config),
    do: start_evm(module, %Config{config | ws_port: unused_port()})

  defp start_evm(module, config), do: start_evm_process(module, config)

  # Starts new EVM genserver inser default supervisor
  defp start_evm_process(module, %Config{} = config) do
    config = fix_path(config)

    %Config{id: id, http_port: http_port, ws_port: ws_port, db_path: db_path} = config

    unless File.exists?(db_path) do
      Logger.debug("#{id}: #{db_path} not exist, creating...")
      :ok = File.mkdir_p!(db_path)
    end

    with false <- Watcher.port_in_use?(http_port),
         false <- Watcher.port_in_use?(ws_port),
         false <- Watcher.path_in_use?(db_path),
         {:ok, _pid} <- Chain.EVM.Supervisor.start_evm(module, config) do
      {:ok, id}
    else
      true ->
        {:error, "port or path are in use"}

      _ ->
        {:error, "Something went wrong on starting chain"}
    end
  end

  # Expands path like `~/something` to normal path
  # This function is handler for `output: nil`
  defp fix_path(%{db_path: db_path, output: nil} = config),
    do: %Config{config | db_path: Path.expand(db_path)}

  defp fix_path(%{db_path: db_path, output: ""} = config),
    do: fix_path(%Config{config | output: "#{db_path}/out.log"})

  defp fix_path(%{db_path: db_path, output: output} = config),
    do: %Config{config | db_path: Path.expand(db_path), output: Path.expand(output)}
end
