# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

config :storage, provider: Storage.Provider.Dets
config :storage, dets_db_path: "/tmp/chains"

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

config :porcelain, driver: Porcelain.Driver.Basic

# Amount of time in ms process allowed to perform "blocking" work before supervisor will terminate it
config :chain, kill_timeout: 180_000

# URL that will be placed to chain.
# It's actually outside world URL to testchain.
# For local development it should be `localhost`
# For production instance in cloud it will be changed to real DNS address.
# NOTE: you don't need protocol here (`http:// | ws://`) it will be set by evm provider
config :chain, front_url: "localhost"
# config :chain, front_url: "host.docker.internal"

# Default folder where all chain db's will be created, please use full path
# Note that chain id will be added as final folder.
# Example: with `config :chain, base_path: "/tmp/chains"`
# Final chain path will be
# `/tmp/chains/some-id-here`
config :chain, base_path: "/tmp/chains"

# Default chainId that will be assigned to chain if it was not passed
# as parameter for chain on start
config :chain, default_chain_id: 999

# Default path where snapshots will be stored for chain
# chain id will be added as a target folder under this path
config :chain, snapshot_base_path: "/tmp/snapshots"

# Path whre snapshots DB will be stored
config :chain, snapshot_db_path: :"/tmp/db/snapshots"

# List of ports available for evm allocation
config :chain, evm_port_range: 8500..8600

config :chain, backend_proxy_node: :"testchain_backendgateway@127.0.0.1"
config :chain, backend_proxy_node_reconnection_timeout: 5_000

# Default location of account password file.
# For dev env it will be in related to project root. In Docker it will be replaced with
# file from `rel/config/config.exs`
config :chain,
  geth_executable: System.find_executable("geth"),
  # geth_executable: "/tmp/chains/test/go-ethereum/build/bin/geth",
  geth_vdb_executable: Path.expand("#{__DIR__}/../priv/presets/geth/geth_vdb"),
  geth_password_file: Path.expand("#{__DIR__}/../priv/presets/geth/account_password"),
  ganache_executable: Path.expand("#{__DIR__}/../priv/presets/ganache-cli/cli.js"),
  ganache_wrapper_file: Path.expand("#{__DIR__}/../priv/presets/ganache/wrapper.sh")

# Sample configuration (overrides the imported configuration above):
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]

import_config "#{Mix.env()}.exs"
