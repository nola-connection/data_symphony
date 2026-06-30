defmodule DataSymphony.Datasets.DatasetParser do
  @moduledoc """
  Streaming reader and validator for uploaded CSV files.

  `parse/1` reads a CSV from disk one line at a time (never loading the whole
  file), validates row shape against the header, and enforces
  `DataSymphony.Datasets.Limits`. Rather than failing on the first bad row, it
  aggregates every problem into a list of structured errors carrying row and
  column context, so the upload UI (CSV-5) can surface them all at once.

  On success it returns a normalized `t:dataset_attrs/0` map — headers plus the
  measured row/column counts and byte size — ready to build a `Dataset`
  changeset. Writing the raw CSV to blob storage is handled separately (CSV-4);
  this module only reads and validates.

  Blank lines (including a leading blank line before the header) are skipped
  rather than reported, mirroring the client-side reference parser. A quoted
  field is parsed within a single physical line; a value with an embedded
  newline therefore reads as a ragged row and is reported as a structured
  error instead of crashing the parse.
  """

  alias DataSymphony.Datasets.Limits

  @typedoc "Normalized attributes for an accepted upload."
  @type dataset_attrs :: %{
          column_headers: [String.t()],
          row_count: non_neg_integer(),
          column_count: non_neg_integer(),
          byte_size: non_neg_integer()
        }

  @typedoc "Classification of a parse problem."
  @type error_type ::
          :empty_file
          | :byte_size_exceeded
          | :row_count_exceeded
          | :column_count_exceeded
          | :cell_too_long
          | :ragged_row

  @typedoc """
  A structured parse error. `row` is the 1-based line number in the file and
  `column` the 1-based column index; either is `nil` when not applicable.
  """
  @type error :: %{
          type: error_type(),
          message: String.t(),
          row: pos_integer() | nil,
          column: pos_integer() | nil
        }

  @doc """
  Streams and validates the CSV at `path`.

  Returns `{:ok, dataset_attrs}` when the file is well-formed and within limits,
  or `{:error, [error]}` with every problem found (aggregated, not fail-fast).
  """
  @spec parse(Path.t()) :: {:ok, dataset_attrs()} | {:error, [error(), ...]}
  def parse(path) when is_binary(path) do
    stream = File.stream!(path, [], :line)
    reduced = Enum.reduce_while(stream, initial_acc(), &reduce_line/2)
    finalize(reduced)
  end

  defp initial_acc do
    %{
      limits: Limits.all(),
      headers: nil,
      column_count: nil,
      row_count: 0,
      byte_size: 0,
      line: 0,
      errors: []
    }
  end

  defp reduce_line(raw, acc) do
    acc = %{acc | line: acc.line + 1, byte_size: acc.byte_size + byte_size(raw)}

    with {:ok, acc} <- enforce_byte_limit(acc),
         {:ok, acc} <- classify(acc, strip_eol(raw)) do
      {:cont, acc}
    end
  end

  defp enforce_byte_limit(acc) do
    if acc.byte_size > acc.limits.max_byte_size do
      {:halt, add_error(acc, byte_error(acc))}
    else
      {:ok, acc}
    end
  end

  defp classify(acc, line) do
    cond do
      String.trim(line) == "" -> {:ok, acc}
      is_nil(acc.headers) -> {:ok, set_header(acc, split_fields(line))}
      true -> validate_row(acc, split_fields(line))
    end
  end

  defp set_header(acc, fields) do
    acc = %{acc | headers: fields, column_count: length(fields)}
    acc = maybe_column_count_error(acc, length(fields))
    check_cells(acc, fields)
  end

  # Runs every per-row check in a single conditional. Returns `{:halt, acc}` for
  # the hard row-count limit (which stops the stream) and `{:ok, acc}` — with any
  # shape or cell errors accumulated — for everything else.
  defp validate_row(acc, fields) do
    acc = %{acc | row_count: acc.row_count + 1}

    cond do
      acc.row_count > acc.limits.max_row_count ->
        {:halt, add_error(acc, row_count_error(acc))}

      length(fields) != acc.column_count ->
        {:ok, add_error(acc, ragged_row_error(acc, length(fields)))}

      true ->
        {:ok, check_cells(acc, fields)}
    end
  end

  defp maybe_column_count_error(acc, count) do
    if count > acc.limits.max_column_count do
      add_error(acc, column_count_error(acc, count))
    else
      acc
    end
  end

  defp check_cells(acc, fields) do
    indexed = Enum.with_index(fields, 1)
    max = acc.limits.max_cell_length
    Enum.reduce(indexed, acc, &check_cell(&1, &2, max))
  end

  defp check_cell({cell, column}, acc, max) do
    size = byte_size(cell)

    if size > max do
      add_error(acc, cell_error(acc.line, column, size, max))
    else
      acc
    end
  end

  defp finalize(acc) do
    cond do
      acc.errors != [] -> {:error, Enum.reverse(acc.errors)}
      is_nil(acc.headers) -> {:error, [empty_file_error()]}
      true -> {:ok, to_attrs(acc)}
    end
  end

  defp to_attrs(acc) do
    %{
      column_headers: acc.headers,
      row_count: acc.row_count,
      column_count: acc.column_count,
      byte_size: acc.byte_size
    }
  end

  defp add_error(acc, error), do: %{acc | errors: [error | acc.errors]}

  defp empty_file_error do
    %{
      type: :empty_file,
      message: "the file is empty or has no header row",
      row: nil,
      column: nil
    }
  end

  defp byte_error(acc) do
    %{
      type: :byte_size_exceeded,
      message: "upload exceeds the maximum size of #{acc.limits.max_byte_size} bytes",
      row: nil,
      column: nil
    }
  end

  defp row_count_error(acc) do
    %{
      type: :row_count_exceeded,
      message: "dataset exceeds the maximum of #{acc.limits.max_row_count} rows",
      row: nil,
      column: nil
    }
  end

  defp column_count_error(acc, count) do
    %{
      type: :column_count_exceeded,
      message: "header has #{count} columns; the maximum is #{acc.limits.max_column_count}",
      row: acc.line,
      column: nil
    }
  end

  defp ragged_row_error(acc, count) do
    %{
      type: :ragged_row,
      message: "row has #{count} columns; expected #{acc.column_count}",
      row: acc.line,
      column: nil
    }
  end

  defp cell_error(row, column, size, max) do
    %{
      type: :cell_too_long,
      message: "cell is #{size} bytes; the maximum is #{max}",
      row: row,
      column: column
    }
  end

  defp strip_eol(line) do
    trimmed = String.trim_trailing(line, "\n")
    String.trim_trailing(trimmed, "\r")
  end

  # Splits a single CSV line into fields, honoring double-quoted values and
  # escaped quotes (`""`). Matching is byte-based: the comma and quote markers
  # are single-byte ASCII, so multi-byte UTF-8 characters pass through intact.
  defp split_fields(line), do: do_split(line, "", [], false)

  defp do_split(<<?", ?", rest::binary>>, current, acc, true) do
    do_split(rest, <<current::binary, ?">>, acc, true)
  end

  defp do_split(<<?", rest::binary>>, current, acc, quoted?) do
    do_split(rest, current, acc, not quoted?)
  end

  defp do_split(<<?,, rest::binary>>, current, acc, false) do
    do_split(rest, "", [current | acc], false)
  end

  defp do_split(<<char, rest::binary>>, current, acc, quoted?) do
    do_split(rest, <<current::binary, char>>, acc, quoted?)
  end

  defp do_split(<<>>, current, acc, _quoted?), do: Enum.reverse([current | acc])
end
