defmodule IndiesShuffle.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      IndiesShuffleWeb.Telemetry,
      IndiesShuffle.Repo,
      {DNSCluster, query: Application.get_env(:indies_shuffle, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: IndiesShuffle.PubSub},
      {Registry, keys: :unique, name: IndiesShuffle.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: IndiesShuffle.GameSupervisor},
      # Start a worker by calling: IndiesShuffle.Worker.start_link(arg)
      # {IndiesShuffle.Worker, arg},
      IndiesShuffle.BanManager,
      # Start to serve requests, typically the last entry
      IndiesShuffleWeb.Endpoint,
      IndiesShuffleWeb.Presence
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: IndiesShuffle.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    IndiesShuffleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
