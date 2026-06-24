defmodule DataSymphony.BlobStorage.S3 do
  @moduledoc """
  S3-compatible `DataSymphony.BlobStorage` adapter for production.

  Works with Amazon S3 and any S3-compatible endpoint (MinIO, Cloudflare R2,
  Backblaze B2, …) using path-style addressing. Requests are signed with AWS
  Signature V4 (`DataSymphony.BlobStorage.S3.Signer`) and issued over OTP's
  built-in `:httpc`, so no AWS SDK dependency is required.

  Configuration (typically populated from environment variables in
  `config/runtime.exs`):

      config :data_symphony, DataSymphony.BlobStorage.S3,
        host: "s3.amazonaws.com",
        bucket: "data-symphony",
        region: "us-east-1",
        access_key_id: System.get_env("S3_ACCESS_KEY_ID"),
        secret_access_key: System.get_env("S3_SECRET_ACCESS_KEY")

  Optional keys: `:scheme` (default `"https"`) and `:url_expires_in` (presigned
  URL lifetime in seconds, default `3600`).
  """

  @behaviour DataSymphony.BlobStorage

  alias DataSymphony.BlobStorage.S3.Signer

  @impl true
  def put(ref, contents) when is_binary(ref) and is_binary(contents) do
    case request(:put, ref, contents) do
      {:ok, status, _body} when status in 200..299 -> {:ok, ref}
      {:ok, status, body} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get(ref) when is_binary(ref) do
    case request(:get, ref, "") do
      {:ok, status, body} when status in 200..299 -> {:ok, body}
      {:ok, 404, _body} -> {:error, :not_found}
      {:ok, status, body} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def url(ref) when is_binary(ref) do
    config = config()
    encoded_path = encoded_path(config.bucket, ref)

    {:ok,
     Signer.presigned_url(
       config.scheme,
       config.host,
       encoded_path,
       config.url_expires_in,
       config
     )}
  end

  defp request(method, ref, body) do
    config = config()
    encoded_path = encoded_path(config.bucket, ref)
    url = "#{config.scheme}://#{config.host}#{encoded_path}"
    headers = Signer.headers(method, config.host, encoded_path, body, config)
    http(method, url, headers, body)
  end

  defp http(:get, url, headers, _body) do
    :get
    |> :httpc.request({charlist(url), charlist_headers(headers)}, http_opts(),
      body_format: :binary
    )
    |> handle_response()
  end

  defp http(:put, url, headers, body) do
    request = {charlist(url), charlist_headers(headers), ~c"application/octet-stream", body}

    :put
    |> :httpc.request(request, http_opts(), body_format: :binary)
    |> handle_response()
  end

  defp handle_response({:ok, {{_version, status, _reason}, _headers, body}}),
    do: {:ok, status, body}

  defp handle_response({:error, reason}), do: {:error, reason}

  # Path-style addressing: /<bucket>/<key>, with each segment URI-encoded.
  defp encoded_path(bucket, ref) do
    key =
      ref
      |> String.trim_leading("/")
      |> String.split("/")
      |> Enum.map_join("/", &Signer.encode/1)

    "/" <> Signer.encode(bucket) <> "/" <> key
  end

  defp http_opts do
    [
      ssl: [
        verify: :verify_peer,
        cacertfile: CAStore.file_path(),
        depth: 4,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ],
      timeout: 30_000,
      connect_timeout: 10_000
    ]
  end

  defp config do
    raw = Application.get_env(:data_symphony, __MODULE__, [])

    %{
      bucket: fetch!(raw, :bucket),
      host: fetch!(raw, :host),
      access_key_id: fetch!(raw, :access_key_id),
      secret_access_key: fetch!(raw, :secret_access_key),
      region: Keyword.get(raw, :region, "us-east-1"),
      scheme: Keyword.get(raw, :scheme, "https"),
      url_expires_in: Keyword.get(raw, :url_expires_in, 3600)
    }
  end

  defp fetch!(raw, key) do
    case Keyword.fetch(raw, key) do
      {:ok, value} when not is_nil(value) ->
        value

      _ ->
        raise ArgumentError,
              "missing #{inspect(key)} for config :data_symphony, #{inspect(__MODULE__)}"
    end
  end

  defp charlist(value), do: String.to_charlist(value)

  defp charlist_headers(headers) do
    Enum.map(headers, fn {key, value} -> {charlist(key), charlist(value)} end)
  end
end
