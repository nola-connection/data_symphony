defmodule DataSymphony.BlobStorage do
  @moduledoc """
  Reference-based blob storage for raw CSV uploads and generated MIDI artifacts.

  The database stores only references and metadata; the bytes live in a blob
  store. A blob is addressed by an opaque `t:ref/0` string (e.g.
  `"datasets/<id>/original.csv"`), and the storage backend is selected per
  environment via application config:

      config :data_symphony, DataSymphony.BlobStorage,
        adapter: DataSymphony.BlobStorage.Filesystem

  The default adapter is `DataSymphony.BlobStorage.Filesystem` (used in dev and
  test); production selects `DataSymphony.BlobStorage.S3` from
  `config/runtime.exs`. Datasets and sequences should depend on this module
  rather than on a concrete adapter.

  ## Behaviour

  Adapters implement the three callbacks below. The API is intentionally
  minimal and reference-based:

    * `c:put/2` — store `contents` at `ref`, returning the stored `ref`.
    * `c:get/1` — read the bytes previously stored at `ref`.
    * `c:url/1` — resolve `ref` to a URL a client can fetch.
  """

  @typedoc "An opaque, backend-agnostic reference to a stored blob."
  @type ref :: String.t()

  @doc """
  Stores `contents` at `ref`.

  Returns `{:ok, ref}` with the (possibly normalized) reference on success, or
  `{:error, reason}` on failure.
  """
  @callback put(ref, contents :: binary()) :: {:ok, ref} | {:error, term()}

  @doc """
  Reads the bytes stored at `ref`.

  Returns `{:ok, binary}` on success, `{:error, :not_found}` when no blob is
  stored at `ref`, or `{:error, reason}` for other failures.
  """
  @callback get(ref) :: {:ok, binary()} | {:error, term()}

  @doc """
  Resolves `ref` to a URL a client can fetch.

  Returns `{:ok, url}` or `{:error, reason}`.
  """
  @callback url(ref) :: {:ok, String.t()} | {:error, term()}

  @default_adapter DataSymphony.BlobStorage.Filesystem

  @doc "See `c:put/2`. Delegates to the configured adapter."
  @spec put(ref, binary()) :: {:ok, ref} | {:error, term()}
  def put(ref, contents), do: adapter().put(ref, contents)

  @doc "See `c:get/1`. Delegates to the configured adapter."
  @spec get(ref) :: {:ok, binary()} | {:error, term()}
  def get(ref), do: adapter().get(ref)

  @doc "See `c:url/1`. Delegates to the configured adapter."
  @spec url(ref) :: {:ok, String.t()} | {:error, term()}
  def url(ref), do: adapter().url(ref)

  @doc """
  Returns the configured adapter module.

  Falls back to `DataSymphony.BlobStorage.Filesystem` when no adapter is
  configured, so dev and test work without extra setup.
  """
  @spec adapter() :: module()
  def adapter do
    :data_symphony
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:adapter, @default_adapter)
  end
end
