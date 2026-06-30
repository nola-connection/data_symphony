defmodule DataSymphony.Datasets.DatasetTest do
  @moduledoc """
  Guards DS-1: `Dataset` schema and migration acceptance criteria.

  1. Schema + migration with headers, counts, byte size, blob refs.
  2. Polymorphic `source` embed plus `source_type` discriminator.
  3. Migration runs cleanly and round-trips in a test.
  """

  use DataSymphony.DataCase, async: true

  alias DataSymphony.Datasets.{CSVSource, Dataset}

  @valid_attrs %{
    column_headers: ["date", "revenue"],
    row_count: 100,
    column_count: 2,
    byte_size: 2048,
    original_blob_ref: "datasets/1/original.csv",
    source: %{
      "__type__" => "csv",
      "original_filename" => "sales.csv",
      "uploaded_at" => ~U[2026-06-30 12:00:00Z],
      "mime_type" => "text/csv"
    }
  }

  describe "changeset/2" do
    test "is valid with a CSV source and derives source_type from the embed" do
      changeset = Dataset.changeset(%Dataset{}, @valid_attrs)

      assert changeset.valid?
      assert get_field(changeset, :source_type) == "csv"
      assert %CSVSource{original_filename: "sales.csv"} = get_field(changeset, :source)
    end

    test "requires the shape fields, blob ref, and source" do
      changeset = Dataset.changeset(%Dataset{}, %{})

      refute changeset.valid?
      errors = errors_on(changeset)

      for field <- [
            :column_headers,
            :row_count,
            :column_count,
            :byte_size,
            :original_blob_ref,
            :source
          ] do
        assert Map.has_key?(errors, field), "expected a required error on #{field}"
      end
    end

    test "rejects negative measurements" do
      attrs = %{@valid_attrs | row_count: -1, column_count: -2, byte_size: -3}
      changeset = Dataset.changeset(%Dataset{}, attrs)

      refute changeset.valid?
      errors = errors_on(changeset)
      assert "must be greater than or equal to 0" in errors.row_count
      assert "must be greater than or equal to 0" in errors.column_count
      assert "must be greater than or equal to 0" in errors.byte_size
    end

    test "treats derived_blob_ref as optional" do
      changeset = Dataset.changeset(%Dataset{}, @valid_attrs)

      assert changeset.valid?
      assert get_field(changeset, :derived_blob_ref) == nil
    end
  end

  describe "persistence" do
    test "round-trips the polymorphic source embed and source_type column" do
      {:ok, dataset} =
        %Dataset{}
        |> Dataset.changeset(@valid_attrs)
        |> Repo.insert()

      reloaded = Repo.get!(Dataset, dataset.id)

      assert reloaded.source_type == "csv"
      assert reloaded.column_headers == ["date", "revenue"]
      assert reloaded.row_count == 100
      assert reloaded.column_count == 2
      assert reloaded.byte_size == 2048
      assert reloaded.original_blob_ref == "datasets/1/original.csv"
      assert reloaded.derived_blob_ref == nil

      assert %CSVSource{
               original_filename: "sales.csv",
               mime_type: "text/csv",
               uploaded_at: ~U[2026-06-30 12:00:00Z]
             } = reloaded.source
    end

    test "persists an optional derived_blob_ref when present" do
      attrs = Map.put(@valid_attrs, :derived_blob_ref, "datasets/1/derived.bin")

      {:ok, dataset} =
        %Dataset{}
        |> Dataset.changeset(attrs)
        |> Repo.insert()

      assert Repo.get!(Dataset, dataset.id).derived_blob_ref == "datasets/1/derived.bin"
    end
  end
end
