defmodule DataSymphony.Datasets.Limits do
  @moduledoc """
  Runtime-config-driven upload policy for datasets.

  Limits are *policy*, not data: they live in application config (overridable
  per environment and at runtime) rather than in the database. The upload UI
  surfaces these values so a rejected upload is understandable up front, and
  the parser enforces them when reading a file.

      config :data_symphony, DataSymphony.Datasets.Limits,
        max_byte_size: 10_485_760,
        max_row_count: 10_000,
        max_column_count: 64,
        max_cell_length: 1_024

  Defaults mirror the figures in `docs/03-domain-model.md`.
  """

  @type t :: %{
          max_byte_size: pos_integer(),
          max_row_count: pos_integer(),
          max_column_count: pos_integer(),
          max_cell_length: pos_integer()
        }

  @defaults [
    max_byte_size: 10_485_760,
    max_row_count: 10_000,
    max_column_count: 64,
    max_cell_length: 1_024
  ]

  @doc "Returns every configured limit as a map."
  @spec all() :: t()
  def all do
    Map.new(@defaults, fn {key, default} -> {key, get(key, default)} end)
  end

  @doc "Maximum accepted upload size, in bytes."
  @spec max_byte_size() :: pos_integer()
  def max_byte_size, do: get(:max_byte_size, @defaults[:max_byte_size])

  @doc "Maximum number of data rows in an accepted dataset."
  @spec max_row_count() :: pos_integer()
  def max_row_count, do: get(:max_row_count, @defaults[:max_row_count])

  @doc "Maximum number of columns in an accepted dataset."
  @spec max_column_count() :: pos_integer()
  def max_column_count, do: get(:max_column_count, @defaults[:max_column_count])

  @doc "Maximum length, in bytes, of any single cell."
  @spec max_cell_length() :: pos_integer()
  def max_cell_length, do: get(:max_cell_length, @defaults[:max_cell_length])

  defp get(key, default) do
    :data_symphony
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end
end
