defmodule DataSymphony.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
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

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
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
