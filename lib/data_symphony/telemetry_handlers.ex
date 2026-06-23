defmodule DataSymphony.TelemetryHandlers do
  @moduledoc """
  Attaches default telemetry event handlers for Phoenix and Ecto.

  This module is started in the supervision tree and subscribes to telemetry
  events emitted by Phoenix and Ecto, making them available for observation
  and metrics collection via LiveDashboard.
  """

  require Logger

  def start_link(_opts) do
    attach_phoenix_handlers()
    attach_ecto_handlers()
    :ignore
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :worker
    }
  end

  # Phoenix handlers - log request information with duration
  defp attach_phoenix_handlers do
    reattach("phoenix-request-stop", [:phoenix, :endpoint, :stop], &handle_phoenix_stop/4)

    reattach(
      "phoenix-router-exception",
      [:phoenix, :router_dispatch, :exception],
      &handle_phoenix_exception/4
    )
  end

  # Ecto handlers - log database query information
  defp attach_ecto_handlers do
    reattach("ecto-query-total-time", [:data_symphony, :repo, :query], &handle_ecto_query/4)
  end

  # Attach idempotently so a supervisor/app restart in the same VM does not
  # crash with {:error, :already_exists} on a duplicate handler id.
  defp reattach(id, event, fun) do
    :telemetry.detach(id)
    :telemetry.attach(id, event, fun, nil)
  end

  # Handle Phoenix endpoint stop events
  defp handle_phoenix_stop(_event, measurements, metadata, _config) do
    duration_ms = div(measurements[:duration], 1_000_000)
    log_phoenix_request(metadata, duration_ms)
  end

  defp log_phoenix_request(metadata, duration_ms) do
    Logger.debug("Phoenix request completed",
      request_id: metadata[:request_id],
      duration_ms: duration_ms
    )
  end

  # Handle Phoenix router exceptions
  defp handle_phoenix_exception(_event, measurements, metadata, _config) do
    duration_ms = div(measurements[:duration], 1_000_000)
    log_phoenix_exception(metadata, duration_ms)
  end

  defp log_phoenix_exception(metadata, duration_ms) do
    Logger.warning("Phoenix router exception",
      request_id: metadata[:request_id],
      duration_ms: duration_ms
    )
  end

  # Handle Ecto query events
  defp handle_ecto_query(_event, measurements, _metadata, _config) do
    query_time_ms = div(measurements[:query_time] || 0, 1_000_000)

    if query_time_ms > 100 do
      Logger.warning("Slow Ecto query",
        duration_ms: query_time_ms
      )
    else
      Logger.debug("Ecto query",
        duration_ms: query_time_ms
      )
    end
  end
end
