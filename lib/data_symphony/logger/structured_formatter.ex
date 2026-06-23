defmodule DataSymphony.Logger.StructuredFormatter do
  @moduledoc """
  A structured logger formatter that outputs logs in a queryable format.

  Emits logs with key-value pairs including request/job metadata for production observability.
  """

  # Metadata keys surfaced in structured output (mirrors config/*.exs :metadata).
  @metadata_keys [:request_id, :user_id, :job_id, :duration_ms]

  def format(level, message, timestamp, metadata) do
    # Extract standard fields
    base_fields = %{
      "timestamp" => format_timestamp(timestamp),
      "level" => level,
      "message" => IO.chardata_to_string(message)
    }

    # Keep only the whitelisted metadata, stringifying keys in a single pass
    metadata_fields =
      for {key, value} <- metadata, key in @metadata_keys, into: %{} do
        {Atom.to_string(key), value}
      end

    # Combine all fields
    all_fields = Map.merge(base_fields, metadata_fields)

    # Format as JSON output for prod or readable format for dev. `:env` is set
    # from config_env() in config/config.exs; read at runtime (not compile time)
    # so the prod branch stays reachable in dev/test builds.
    case Application.get_env(:data_symphony, :env, :dev) do
      :prod -> format_json(all_fields)
      _ -> format_readable(all_fields)
    end
  rescue
    # A formatter must never raise, or logging breaks. Fall back to a safe line.
    _ -> "[#{level}] #{inspect(message)}\n"
  end

  defp format_json(fields) do
    fields
    |> Jason.encode!()
    |> then(&"#{&1}\n")
  rescue
    _ -> format_readable(fields)
  end

  defp format_readable(fields) do
    message = fields["message"]
    level = fields["level"]
    timestamp = fields["timestamp"]

    metadata_str =
      fields
      |> Map.drop(["timestamp", "level", "message"])
      |> Enum.map_join(" ", fn {k, v} -> "#{k}=#{inspect(v)}" end)

    base_log = "[#{timestamp}] [#{level}] #{message}"

    case metadata_str do
      "" -> "#{base_log}\n"
      _ -> "#{base_log} (#{metadata_str})\n"
    end
  end

  # Logger hands us Erlang's calendar tuple; NaiveDateTime renders it (with
  # zero-padding and the millisecond fraction) without hand-rolled helpers.
  defp format_timestamp({date, {hour, minute, second, millisecond}}) do
    {date, {hour, minute, second}}
    |> NaiveDateTime.from_erl!({millisecond * 1000, 3})
    |> NaiveDateTime.to_string()
  end
end
