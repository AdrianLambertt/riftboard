defmodule Riftboard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Endpoint is started separately below, after demo data (if enabled) has
    # been reset, so no request is ever served against stale/mid-reset data.
    core_children = [
      RiftboardWeb.Telemetry,
      Riftboard.Repo,
      {DNSCluster, query: Application.get_env(:riftboard, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Riftboard.PubSub},
      RiftboardWeb.Presence
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Riftboard.Supervisor]

    with {:ok, sup} <- Supervisor.start_link(core_children, opts) do
      maybe_reset_demo_data()

      case Supervisor.start_child(sup, RiftboardWeb.Endpoint) do
        {:ok, _} -> {:ok, sup}
        {:ok, _, _} -> {:ok, sup}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp maybe_reset_demo_data do
    if Application.get_env(:riftboard, :reset_demo_data_on_boot, false) do
      Riftboard.Seeds.reset()
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RiftboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
