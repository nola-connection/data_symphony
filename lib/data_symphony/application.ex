defmodule DataSymphony.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DataSymphonyWeb.Telemetry,
      DataSymphony.Repo,
      {DNSCluster, query: Application.get_env(:data_symphony, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DataSymphony.PubSub},
      # Start a worker by calling: DataSymphony.Worker.start_link(arg)
      # {DataSymphony.Worker, arg},
      # Start to serve requests, typically the last entry
      DataSymphonyWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: DataSymphony.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DataSymphonyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
