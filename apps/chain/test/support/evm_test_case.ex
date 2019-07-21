defmodule Chain.Test.EVMTestCase do
  @moduledoc """
  Default test for every EVM.

  All EVMs (chains) have to pass this test
  """

  defmacro __using__(opts) do
    quote do
      use ExUnit.Case, async: true

      alias Chain.EVM.Config
      alias Chain.EVM.Notification
      alias Chain.Test.ChainHelper

      alias Chain.Snapshot.Details, as: SnapshotDetails

      @timeout unquote(opts)[:timeout] || Application.get_env(:chain, :kill_timeout)
      @chain unquote(opts)[:chain]

      setup_all do
        pid = spawn(&ChainHelper.receive_loop/0)

        ChainHelper.trace(pid)

        config = %Config{
          type: @chain,
          notify_pid: pid,
          clean_on_stop: true
        }

        {:ok, id} =
          config
          |> Chain.start()

        # Check for receiving notification about chain started
        assert_receive {:trace, ^pid, :receive,
                        %Notification{event: :started, id: ^id, data: data} = notification},
                       @timeout

        assert is_binary(Map.get(data, :rpc_url))
        assert is_binary(Map.get(data, :ws_url))

        ChainHelper.untrace(pid)

        on_exit(fn ->
          ChainHelper.trace(pid)
          :ok = Chain.stop(id)

          assert_receive {:trace, ^pid, :receive,
                          %Notification{id: ^id, event: :status_changed, data: :terminating}},
                         @timeout

          assert_receive {:trace, ^pid, :receive, %Notification{id: ^id, event: :stopped}},
                         @timeout

          ChainHelper.untrace(pid)

          refute Application.get_env(:chain, :base_path)
                 |> Path.join(id)
                 |> File.dir?()
        end)

        {:ok, %{id: id, config: config, data: data, pid: pid}}
      end

      @tag evm: @chain
      test "#{@chain} unquote() chain created new chain db", %{id: id} do
        # check for storage
        assert Application.get_env(:chain, :base_path)
               |> Path.join(id)
               |> File.dir?()
      end

      @tag evm: @chain
      test "#{@chain} take_snapshot/1 should create snapshot and revert_snapshot/2 should restore",
           %{
             id: id,
             pid: pid
           } do
        assert Chain.exists?(id)

        ChainHelper.trace(pid)
        :ok = Chain.take_snapshot(id)

        assert_receive {:trace, ^pid, :receive,
                        %Notification{id: ^id, event: :snapshot_taken, data: snapshot}},
                       @timeout

        %SnapshotDetails{chain: @chain, path: path} = snapshot
        assert File.exists?(path)

        assert_receive {:trace, ^pid, :receive,
                        %Notification{id: ^id, event: :status_changed, data: :active}},
                       @timeout

        :ok = Chain.revert_snapshot(id, snapshot)

        assert_receive {:trace, ^pid, :receive,
                        %Notification{id: ^id, event: :snapshot_reverted}},
                       @timeout

        assert_receive {:trace, ^pid, :receive,
                        %Notification{id: ^id, event: :status_changed, data: :active}},
                       @timeout

        ChainHelper.untrace(pid)
        # Remove snapshot
        File.rm(path)
      end

      @tag evm: @chain
      test "#{@chain} take_snaphost/2 should save snapshot in DB in case of description passed",
           %{
             id: id,
             pid: pid
           } do
        assert Chain.alive?(id)

        description = Faker.Lorem.sentence(7)
        ChainHelper.trace(pid)
        :ok = Chain.take_snapshot(id, description)

        assert_receive {:trace, ^pid, :receive,
                        %Notification{id: ^id, event: :snapshot_taken, data: snapshot}},
                       @timeout

        %SnapshotDetails{id: snap_id, chain: @chain, path: path, description: ^description} =
          snapshot

        assert File.exists?(path)

        %Chain.Snapshot.Details{id: ^snap_id} = Chain.SnapshotManager.by_id(snap_id)
        :ok = Chain.SnapshotManager.remove(snap_id)

        assert_receive {:trace, ^pid, :receive,
                        %Notification{id: ^id, event: :status_changed, data: :active}},
                       @timeout

        refute File.exists?(path)
      end

      @tag evm: @chain
      test "#{@chain} should load details with accounts", %{id: id} do
        assert Chain.alive?(id)

        {:ok, %Chain.EVM.Process{id: ^id, accounts: accounts} = info} = Chain.details(id)
        assert is_list(accounts)
        [%Chain.EVM.Account{} | _] = accounts
        assert Map.get(info, :rpc_url)
        assert Map.get(info, :ws_url)
      end

      @tag evm: @chain
      test "#{@chain} should store/load external data", %{id: id} do
        assert Chain.alive?(id)

        data = %{
          some: Faker.String.base64(),
          email: Faker.Internet.email()
        }

        assert :ok = Chain.write_external_data(id, data)
        assert {:ok, ^data} = Chain.read_external_data(id)
      end
    end
  end
end
