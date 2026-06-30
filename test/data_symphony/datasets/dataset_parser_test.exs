defmodule DataSymphony.Datasets.DatasetParserTest do
  @moduledoc """
  Guards CSV-2: `DatasetParser.parse/1` acceptance criteria.

  1. Streams and validates row shape.
  2. Limits enforced during parsing.
  3. Returns aggregated, structured errors with row/column context.
  """

  use ExUnit.Case, async: false

  alias DataSymphony.Datasets.{DatasetParser, Limits}

  setup do
    # Restore any Limits config we override so tests stay independent.
    saved = Application.get_env(:data_symphony, Limits)

    on_exit(fn ->
      if saved do
        Application.put_env(:data_symphony, Limits, saved)
      else
        Application.delete_env(:data_symphony, Limits)
      end
    end)

    :ok
  end

  defp write_csv(contents) do
    path = Path.join(System.tmp_dir!(), "ds_parser_#{System.unique_integer([:positive])}.csv")
    File.write!(path, contents)
    on_exit(fn -> File.rm_rf!(path) end)
    path
  end

  defp put_limits(overrides) do
    base = Map.to_list(Limits.all())
    Application.put_env(:data_symphony, Limits, Keyword.merge(base, overrides))
  end

  describe "criterion 1: streams and validates row shape" do
    test "returns normalized attrs for a well-formed CSV" do
      contents = "name,age\nalice,30\nbob,40\n"
      path = write_csv(contents)

      assert {:ok, attrs} = DatasetParser.parse(path)
      assert attrs.column_headers == ["name", "age"]
      assert attrs.row_count == 2
      assert attrs.column_count == 2
      assert attrs.byte_size == byte_size(contents)
    end

    test "skips blank lines, including a leading one, without reporting them" do
      path = write_csv("\nname,age\nalice,30\n\nbob,40\n")

      assert {:ok, attrs} = DatasetParser.parse(path)
      assert attrs.row_count == 2
    end

    test "honors quoted fields so embedded commas do not create ragged rows" do
      path = write_csv(~s(name,note\n"alice","hi, there"\n))

      assert {:ok, attrs} = DatasetParser.parse(path)
      assert attrs.column_count == 2
      assert attrs.row_count == 1
    end

    test "reports a ragged row with its line number and expected width" do
      path = write_csv("name,age\nalice,30\nbob\n")

      assert {:error, [error]} = DatasetParser.parse(path)
      assert error.type == :ragged_row
      assert error.row == 3
      assert error.message =~ "expected 2"
    end
  end

  describe "criterion 2: limits enforced during parsing" do
    test "rejects an upload over the byte-size limit" do
      put_limits(max_byte_size: 8)
      path = write_csv("name,age\nalice,30\nbob,40\n")

      assert {:error, errors} = DatasetParser.parse(path)
      assert Enum.any?(errors, &(&1.type == :byte_size_exceeded))
    end

    test "rejects an upload over the row-count limit" do
      put_limits(max_row_count: 1)
      path = write_csv("name\na\nb\nc\n")

      assert {:error, errors} = DatasetParser.parse(path)
      assert Enum.any?(errors, &(&1.type == :row_count_exceeded))
    end

    test "rejects a header over the column-count limit" do
      put_limits(max_column_count: 2)
      path = write_csv("a,b,c\n1,2,3\n")

      assert {:error, errors} = DatasetParser.parse(path)
      assert Enum.any?(errors, &(&1.type == :column_count_exceeded))
    end

    test "reports an over-long cell with row and column context" do
      put_limits(max_cell_length: 3)
      path = write_csv("a,b\nalice,30\n")

      assert {:error, [error]} = DatasetParser.parse(path)
      assert error.type == :cell_too_long
      assert error.row == 2
      assert error.column == 1
      assert error.message =~ "maximum is 3"
    end
  end

  describe "criterion 3: aggregated, structured errors" do
    test "collects every problem instead of failing on the first" do
      path = write_csv("name,age\nbob\ncarol,1,2\n")

      assert {:error, errors} = DatasetParser.parse(path)
      assert length(errors) == 2
      assert Enum.map(errors, & &1.row) == [2, 3]
      assert Enum.all?(errors, &(&1.type == :ragged_row))
    end

    test "every error carries the structured shape" do
      path = write_csv("name,age\nbob\n")

      assert {:error, [error]} = DatasetParser.parse(path)
      assert %{type: type, message: message, row: row, column: column} = error
      assert is_atom(type)
      assert is_binary(message)
      assert row == 2
      assert is_nil(column)
    end

    test "an empty file is reported as :empty_file" do
      path = write_csv("")

      assert {:error, [error]} = DatasetParser.parse(path)
      assert error.type == :empty_file
    end
  end
end
