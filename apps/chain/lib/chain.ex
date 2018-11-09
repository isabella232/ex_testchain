defmodule Chain do
  @moduledoc """
  Default module for controlling different EVM's 
  """

  alias Chain.EVM.Implementation.{Geth, Ganache}
  alias Chain.EVM.Config

  @typedoc """
  Chain EVM type. 

  Available types are:
   - `:ganache` -  Ganache blockchain
   - `:geth` - Geth evm
   - `:parity` - Parity evm
  """
  @type evm_type :: :ganache | :geth | :parity

  @typedoc """
  Big integer generated by `Chain.unique_id/0` that identifiers new chain id
  """
  @type evm_id :: non_neg_integer()

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
  Generate uniq ID
  """
  @spec unique_id() :: non_neg_integer()
  def unique_id() do
    <<new_unique_id::big-integer-size(8)-unit(8)>> = :crypto.strong_rand_bytes(8)

    case get_pid(new_unique_id) do
      nil ->
        new_unique_id

      _ ->
        unique_id()
    end
  end

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
  """
  @spec take_snapshot(Chain.evm_id(), binary) :: :ok | {:error, term()}
  def take_snapshot(id, path_to),
    do: GenServer.cast(get_pid!(id), {:take_snapshot, path_to})

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

  # Try to start evm using given module/config
  defp start_evm(module, %Config{id: nil} = config) do
    id = unique_id()

    start_evm_process(module, %Config{config | id: id})
  end

  defp start_evm(module, config), do: start_evm_process(module, config)

  # Starts new EVM genserver inser default supervisor
  defp start_evm_process(module, %Config{id: id} = config) do
    {:ok, _pid} =
      %{id: id, start: {module, :start_link, [config]}, restart: :transient}
      |> Chain.EVM.Supervisor.start_child()

    {:ok, id}
  end
end
