defmodule DataSymphony.Repo.Migrations.CreateDatasetsTable do
  use Ecto.Migration

  def change do
    create table(:datasets) do
      add :source_type, :string, null: false
      add :source, :map, null: false
      add :column_headers, {:array, :string}, null: false
      add :row_count, :integer, null: false
      add :column_count, :integer, null: false
      add :byte_size, :integer, null: false
      add :original_blob_ref, :string, null: false
      add :derived_blob_ref, :string

      timestamps(type: :utc_datetime)
    end

    # Discriminator queried on its own (e.g. "all datasets of a given source
    # type"); kept alongside the JSONB `source` embed per the domain model.
    create index(:datasets, [:source_type])
  end
end
