defmodule SpexConverter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    flame_parent = FLAME.Parent.get()

    children =
      [
        SpexConverterWeb.Telemetry,
        !flame_parent &&
          {DNSCluster, query: Application.get_env(:thumbs, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: SpexConverter.PubSub},
        # Start the Finch HTTP client for sending emails
        !flame_parent && {Finch, name: SpexConverter.Finch},
        # Start a worker by calling: SpexConverter.Worker.start_link(arg)
        # {SpexConverter.Worker, arg},
        # Start to serve requests, typically the last entry
        {FLAME.Pool,
         name: SpexConverter.ConvertSpec,
         min: 0,
         max: 5,
         max_concurrency: 20,
         idle_shutdown_after: 10_000,
         log: :debug},
        !flame_parent && SpexConverterWeb.Endpoint
      ]
      |> Enum.filter(& &1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SpexConverter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SpexConverterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
