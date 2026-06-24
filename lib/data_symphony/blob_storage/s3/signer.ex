defmodule DataSymphony.BlobStorage.S3.Signer do
  @moduledoc """
  AWS Signature Version 4 signing for S3-compatible requests.

  Implements the subset of [SigV4](https://docs.aws.amazon.com/general/latest/gr/sigv4_signing.html)
  needed by `DataSymphony.BlobStorage.S3`: an `Authorization` header for
  `PUT`/`GET` object requests and a presigned `GET` URL. Self-contained
  (uses only `:crypto` and `URI`) so the project needs no AWS SDK dependency.

  Configuration is a map with `:access_key_id`, `:secret_access_key`, and
  `:region` keys; the service is always `"s3"`.
  """

  @algorithm "AWS4-HMAC-SHA256"
  @service "s3"

  @type config :: %{
          access_key_id: String.t(),
          secret_access_key: String.t(),
          region: String.t()
        }

  @doc """
  Builds signed request headers for an object request.

  `payload` is the raw request body (`""` for `GET`). Returns the header list
  (string tuples) to send with the request, including `authorization`.
  """
  @spec headers(:get | :put, String.t(), String.t(), binary(), config()) ::
          [{String.t(), String.t()}]
  def headers(method, host, encoded_path, payload, config) do
    {amz_date, date_stamp} = timestamps()
    payload_hash = sha256_hex(payload)

    base = [
      {"host", host},
      {"x-amz-content-sha256", payload_hash},
      {"x-amz-date", amz_date}
    ]

    signed_headers = "host;x-amz-content-sha256;x-amz-date"
    canonical_headers = Enum.map_join(base, fn {k, v} -> "#{k}:#{v}\n" end)

    canonical_request =
      Enum.join(
        [
          method |> Atom.to_string() |> String.upcase(),
          encoded_path,
          "",
          canonical_headers,
          signed_headers,
          payload_hash
        ],
        "\n"
      )

    signature = sign(canonical_request, amz_date, date_stamp, config)
    scope = credential_scope(date_stamp, config.region)

    authorization =
      "#{@algorithm} Credential=#{config.access_key_id}/#{scope}, " <>
        "SignedHeaders=#{signed_headers}, Signature=#{signature}"

    [{"authorization", authorization} | base]
  end

  @doc """
  Builds a presigned `GET` URL valid for `expires_in` seconds.
  """
  @spec presigned_url(String.t(), String.t(), String.t(), pos_integer(), config()) ::
          String.t()
  def presigned_url(scheme, host, encoded_path, expires_in, config) do
    {amz_date, date_stamp} = timestamps()
    scope = credential_scope(date_stamp, config.region)

    query =
      [
        {"X-Amz-Algorithm", @algorithm},
        {"X-Amz-Credential", "#{config.access_key_id}/#{scope}"},
        {"X-Amz-Date", amz_date},
        {"X-Amz-Expires", Integer.to_string(expires_in)},
        {"X-Amz-SignedHeaders", "host"}
      ]
      |> Enum.map(fn {k, v} -> {encode(k), encode(v)} end)
      |> Enum.sort()
      |> Enum.map_join("&", fn {k, v} -> "#{k}=#{v}" end)

    canonical_request =
      Enum.join(
        ["GET", encoded_path, query, "host:#{host}\n", "host", "UNSIGNED-PAYLOAD"],
        "\n"
      )

    signature = sign(canonical_request, amz_date, date_stamp, config)
    "#{scheme}://#{host}#{encoded_path}?#{query}&X-Amz-Signature=#{signature}"
  end

  @doc "URI-encodes a path segment per RFC 3986 (unreserved characters only)."
  @spec encode(String.t()) :: String.t()
  def encode(value), do: URI.encode(value, &unreserved?/1)

  defp sign(canonical_request, amz_date, date_stamp, config) do
    string_to_sign =
      Enum.join(
        [
          @algorithm,
          amz_date,
          credential_scope(date_stamp, config.region),
          sha256_hex(canonical_request)
        ],
        "\n"
      )

    date_stamp
    |> signing_key(config)
    |> hmac(string_to_sign)
    |> Base.encode16(case: :lower)
  end

  defp signing_key(date_stamp, config) do
    ("AWS4" <> config.secret_access_key)
    |> hmac(date_stamp)
    |> hmac(config.region)
    |> hmac(@service)
    |> hmac("aws4_request")
  end

  defp credential_scope(date_stamp, region),
    do: "#{date_stamp}/#{region}/#{@service}/aws4_request"

  defp timestamps do
    now = DateTime.utc_now()
    amz_date = Calendar.strftime(now, "%Y%m%dT%H%M%SZ")
    date_stamp = Calendar.strftime(now, "%Y%m%d")
    {amz_date, date_stamp}
  end

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
  defp sha256_hex(data), do: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)

  defp unreserved?(c)
       when c in ?A..?Z or c in ?a..?z or c in ?0..?9 or c in [?-, ?_, ?., ?~],
       do: true

  defp unreserved?(_), do: false
end
