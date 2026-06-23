defmodule DataSymphony.Logger.StructuredFormatter do
  @moduledoc """
  A structured logger formatter that outputs logs in a queryable format.

  Emits logs with key-value pairs including request/job metadata for production observability.
  """

  def format(level, message, timestamp, metadata) do
    # Extract standard fields
    base_fields = %{
      "timestamp" => format_timestamp(timestamp),
      "level" => level,
      "message" => to_string(message)
    }

    # Add optional metadata fields if present
    metadata_fields =
      metadata
      |> Enum.filter(fn {key, _} ->
        key in [:request_id, :user_id, :job_id, :duration_ms]
      end)
      |> Enum.into(%{})
      |> Enum.map(fn {k, v} -> {"#{k}", v} end)
      |> Enum.into(%{})

    # Combine all fields
    all_fields = Map.merge(base_fields, metadata_fields)

    # Format as JSON-like output for prod or readable format for dev
    case Application.get_env(:data_symphony, :env, :dev) do
      :prod -> format_json(all_fields)
      _ -> format_readable(all_fields)
    end
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

  defp format_timestamp({date, time}) do
    {year, month, day} = date
    {hour, minute, second, millisecond} = time

    "#{year}-#{pad(month)}-#{pad(day)} #{pad(hour)}:#{pad(minute)}:#{pad(second)}.#{pad_ms(millisecond)}"
  end

  defp pad(value) do
    value
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  defp pad_ms(millisecond) do
    millisecond
    |> Integer.to_string()
    |> String.pad_leading(3, "0")
  end
end
