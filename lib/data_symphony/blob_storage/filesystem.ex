defmodule DataSymphony.BlobStorage.Filesystem do
  @moduledoc """
  Filesystem-backed `DataSymphony.BlobStorage` adapter for development and test.

  Blobs are written under a configurable root directory:

      config :data_symphony, DataSymphony.BlobStorage.Filesystem,
        root: "priv/blob_storage"

  When no root is configured a per-host temporary directory is used. The root
  is meant to hold local, disposable artifacts and should be gitignored.

  References are treated as relative paths beneath the root. Any reference that
  would resolve outside the root (e.g. containing `..` or an absolute path) is
  rejected with `{:error, :invalid_reference}`.
  """

  @behaviour DataSymphony.BlobStorage

  @impl true
  def put(ref, contents) when is_binary(ref) and is_binary(contents) do
    with {:ok, path} <- resolve(ref),
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, contents) do
      {:ok, ref}
    end
  end

  @impl true
  def get(ref) when is_binary(ref) do
    with {:ok, path} <- resolve(ref) do
      case File.read(path) do
        {:error, :enoent} -> {:error, :not_found}
        result -> result
      end
    end
  end

  @impl true
  def url(ref) when is_binary(ref) do
    with {:ok, path} <- resolve(ref), do: {:ok, "file://" <> path}
  end

  @doc """
  Returns the configured root directory for stored blobs.

  Falls back to a `data_symphony_blobs` directory inside the system temp dir
  when unconfigured.
  """
  @spec root() :: String.t()
  def root do
    :data_symphony
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:root, Path.join(System.tmp_dir!(), "data_symphony_blobs"))
  end

  # Resolve a reference to an absolute path, refusing anything that escapes the
  # configured root (path traversal) or is empty.
  defp resolve(""), do: {:error, :invalid_reference}

  defp resolve(ref) do
    base = Path.expand(root())
    expanded = Path.expand(ref, base)

    if expanded == base or String.starts_with?(expanded, base <> "/") do
      {:ok, expanded}
    else
      {:error, :invalid_reference}
    end
  end
end
