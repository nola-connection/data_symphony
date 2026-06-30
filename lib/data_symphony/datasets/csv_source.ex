defmodule DataSymphony.Datasets.CSVSource do
  @moduledoc """
  Source metadata for a dataset ingested from an uploaded CSV file.

  This is one variant of the polymorphic `source` embed on
  `DataSymphony.Datasets.Dataset` (see `docs/03-domain-model.md`). It captures
  where the upload came from — the user's original filename, when it was
  uploaded, and the reported MIME type — separate from the parsed shape of the
  data (headers, counts) which lives on the dataset row itself.

  Future source variants (`WeatherSource`, `StockSource`, …) will sit alongside
  this one under the same embed. Each variant is expected to expose a
  `default_mapping/1` returning a sensible starting mapping for its known
  columns; that helper is introduced with DS-2 (#15) and is intentionally not
  defined here yet.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          original_filename: String.t() | nil,
          uploaded_at: DateTime.t() | nil,
          mime_type: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :original_filename, :string
    field :uploaded_at, :utc_datetime
    field :mime_type, :string
  end

  @required_fields [:original_filename, :uploaded_at]
  @optional_fields [:mime_type]
  @all_fields @required_fields ++ @optional_fields

  @doc """
  Builds a changeset for a CSV source embed.
  """
  @spec changeset(t() | Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(source, params) do
    source
    |> cast(params, @all_fields)
    |> validate_required(@required_fields)
  end
end
