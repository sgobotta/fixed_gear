defmodule FixedGear.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FixedGearWeb.Telemetry,
      FixedGear.Repo,
      {DNSCluster,
       query: Application.get_env(:fixed_gear, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FixedGear.PubSub},
      # Start a worker by calling: FixedGear.Worker.start_link(arg)
      # {FixedGear.Worker, arg},
      # Start to serve requests, typically the last entry
      FixedGearWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FixedGear.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FixedGearWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
