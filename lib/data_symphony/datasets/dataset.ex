defmodule DataSymphony.Datasets.Dataset do
  @moduledoc """
  A parsed CSV upload.

  A dataset is immutable once accepted — re-uploading creates a new record
  (see `docs/03-domain-model.md`). The row stores the *shape* of the upload
  (header row, measured row/column counts, byte size) plus references to the
  raw and derived blobs; the cell bytes themselves live in blob storage, not
  the database.

  `source` is a polymorphic embed carrying variant-specific provenance
  (`CSVSource` today; `WeatherSource`, `StockSource`, … on the roadmap).
  `source_type` is a denormalized discriminator column kept alongside the
  JSONB embed so that "all datasets of type X" queries stay cheap; it is
  derived from `source` in `changeset/2` rather than cast from params.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import PolymorphicEmbed

  alias DataSymphony.Datasets.CSVSource

  @type t :: %__MODULE__{
          id: integer() | nil,
          source_type: String.t() | nil,
          source: CSVSource.t() | nil,
          column_headers: [String.t()] | nil,
          row_count: non_neg_integer() | nil,
          column_count: non_neg_integer() | nil,
          byte_size: non_neg_integer() | nil,
          original_blob_ref: String.t() | nil,
          derived_blob_ref: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "datasets" do
    field :source_type, :string
    field :column_headers, {:array, :string}
    field :row_count, :integer
    field :column_count, :integer
    field :byte_size, :integer
    field :original_blob_ref, :string
    field :derived_blob_ref, :string

    polymorphic_embeds_one(:source,
      types: [
        csv: CSVSource
      ],
      on_type_not_found: :raise,
      on_replace: :update
    )

    timestamps(type: :utc_datetime)
  end

  @required_fields [
    :column_headers,
    :row_count,
    :column_count,
    :byte_size,
    :original_blob_ref
  ]
  @optional_fields [:derived_blob_ref]
  @all_fields @required_fields ++ @optional_fields

  @doc """
  Builds a changeset for a dataset.

  `source_type` is not cast — it is derived from the polymorphic `source`
  embed so the column can never drift out of sync with the embed's type.
  """
  @spec changeset(t() | Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(dataset, params) do
    dataset
    |> cast(params, @all_fields)
    |> cast_polymorphic_embed(:source, required: true)
    |> put_source_type()
    |> validate_required(@required_fields)
    |> validate_number(:row_count, greater_than_or_equal_to: 0)
    |> validate_number(:column_count, greater_than_or_equal_to: 0)
    |> validate_number(:byte_size, greater_than_or_equal_to: 0)
  end

  # Mirror the embed's type onto the queryable `source_type` column.
  defp put_source_type(changeset) do
    case get_field(changeset, :source) do
      %module{} ->
        type = get_polymorphic_type(__MODULE__, :source, module)
        put_change(changeset, :source_type, to_string(type))

      _ ->
        changeset
    end
  end
end
