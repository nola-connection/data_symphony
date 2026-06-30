defmodule DataSymphony.Datasets.LimitsTest do
  @moduledoc """
  Guards CSV-3: `Datasets.Limits` acceptance criteria.

  1. Exposes byte/row/column/cell-length limits.
  2. Values are runtime-config driven with defaults.
  3. Used by both the upload UI and the parser.
  """

  # async: false — these tests mutate the global `Limits` application env, which
  # would otherwise race other (async) suites that read the same config.
  use DataSymphonyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias DataSymphony.Datasets.{DatasetParser, Limits}

  # Mirrors the defaults in config/config.exs and docs/03-domain-model.md.
  @defaults %{
    max_byte_size: 10_485_760,
    max_row_count: 10_000,
    max_column_count: 64,
    max_cell_length: 1_024
  }

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

  defp put_limits(overrides) do
    base = Map.to_list(Limits.all())
    Application.put_env(:data_symphony, Limits, Keyword.merge(base, overrides))
  end

  defp write_csv(contents) do
    path = Path.join(System.tmp_dir!(), "ds_limits_#{System.unique_integer([:positive])}.csv")
    File.write!(path, contents)
    on_exit(fn -> File.rm_rf!(path) end)
    path
  end

  describe "criterion 1: exposes byte/row/column/cell-length limits" do
    test "all/0 returns every configured limit as a map" do
      assert Limits.all() == @defaults
    end

    test "each limit has a dedicated accessor" do
      assert Limits.max_byte_size() == @defaults.max_byte_size
      assert Limits.max_row_count() == @defaults.max_row_count
      assert Limits.max_column_count() == @defaults.max_column_count
      assert Limits.max_cell_length() == @defaults.max_cell_length
    end
  end

  describe "criterion 2: runtime-config driven with defaults" do
    test "falls back to the documented defaults when unconfigured" do
      Application.delete_env(:data_symphony, Limits)

      assert Limits.all() == @defaults
      assert Limits.max_byte_size() == @defaults.max_byte_size
      assert Limits.max_cell_length() == @defaults.max_cell_length
    end

    test "reflects a runtime config override without recompilation" do
      put_limits(max_row_count: 5, max_column_count: 3)

      assert Limits.max_row_count() == 5
      assert Limits.max_column_count() == 3
      assert Limits.all().max_row_count == 5
      # Untouched keys keep their defaults.
      assert Limits.max_byte_size() == @defaults.max_byte_size
    end
  end

  describe "criterion 3: used by both the upload UI and the parser" do
    test "the parser enforces a runtime-overridden limit" do
      put_limits(max_column_count: 1)
      path = write_csv("a,b\n1,2\n")

      assert {:error, errors} = DatasetParser.parse(path)
      assert Enum.any?(errors, &(&1.type == :column_count_exceeded))
    end

    test "the upload UI surfaces the runtime-overridden byte limit", %{conn: conn} do
      put_limits(max_byte_size: 2_048)

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "2.0 KB"
    end
  end
end
