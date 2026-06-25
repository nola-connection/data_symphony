defmodule DataSymphony.BlobStorageTest do
  @moduledoc """
  Guards F-6: Blob storage adapter acceptance criteria.

  1. Behaviour defined with documented callbacks.
  2. Filesystem (dev) and S3-compatible (prod) implementations exist.
  3. Adapter selected by config; covered by tests against the dev adapter.
  """

  use ExUnit.Case, async: false

  alias DataSymphony.BlobStorage
  alias DataSymphony.BlobStorage.{Filesystem, S3}

  setup do
    # Isolate each test behind a unique filesystem root and restore any config
    # we mutate so tests stay independent.
    root = Path.join(System.tmp_dir!(), "ds_blob_test_#{System.unique_integer([:positive])}")

    saved =
      for module <- [BlobStorage, Filesystem, S3],
          into: %{},
          do: {module, Application.get_env(:data_symphony, module)}

    Application.put_env(:data_symphony, Filesystem, root: root)

    on_exit(fn ->
      File.rm_rf!(root)

      for {module, value} <- saved do
        if value, do: Application.put_env(:data_symphony, module, value)
      end
    end)

    %{root: root}
  end

  describe "criterion 1: behaviour defined with documented callbacks" do
    test "declares put/2, get/1 and url/1 callbacks" do
      callbacks = BlobStorage.behaviour_info(:callbacks)
      assert {:put, 2} in callbacks
      assert {:get, 1} in callbacks
      assert {:url, 1} in callbacks
    end

    test "every callback carries documentation" do
      {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(BlobStorage)

      documented =
        for {{:callback, name, arity}, _, _, doc, _} <- docs, doc != :none, do: {name, arity}

      assert {:put, 2} in documented
      assert {:get, 1} in documented
      assert {:url, 1} in documented
    end
  end

  describe "criterion 2: filesystem and S3 implementations exist" do
    test "both adapters implement the behaviour and its callbacks" do
      for module <- [Filesystem, S3] do
        Code.ensure_loaded!(module)
        behaviours = Keyword.get(module.__info__(:attributes), :behaviour, [])
        assert BlobStorage in behaviours, "#{inspect(module)} must implement BlobStorage"
        assert function_exported?(module, :put, 2)
        assert function_exported?(module, :get, 1)
        assert function_exported?(module, :url, 1)
      end
    end

    test "S3 url/1 builds a presigned SigV4 URL (no network)" do
      Application.put_env(:data_symphony, S3,
        host: "s3.example.com",
        bucket: "bkt",
        region: "us-east-1",
        access_key_id: "AKIDEXAMPLE",
        secret_access_key: "secret"
      )

      assert {:ok, url} = S3.url("datasets/1/original.csv")
      assert String.starts_with?(url, "https://s3.example.com/bkt/datasets/1/original.csv?")
      assert url =~ "X-Amz-Algorithm=AWS4-HMAC-SHA256"
      assert url =~ "X-Amz-Credential=AKIDEXAMPLE%2F"
      assert url =~ "X-Amz-SignedHeaders=host"
      assert url =~ ~r/X-Amz-Signature=[0-9a-f]{64}/
    end
  end

  describe "criterion 3: adapter selected by config" do
    test "facade resolves the adapter from application config" do
      assert BlobStorage.adapter() == Filesystem

      Application.put_env(:data_symphony, BlobStorage, adapter: S3)
      assert BlobStorage.adapter() == S3
    end

    test "facade delegates to the configured adapter" do
      assert {:ok, "via/facade.txt"} = BlobStorage.put("via/facade.txt", "payload")
      assert {:ok, "payload"} = BlobStorage.get("via/facade.txt")
    end
  end

  describe "filesystem adapter behaviour (dev)" do
    test "put then get round-trips the stored bytes" do
      assert {:ok, "a/b/file.csv"} = Filesystem.put("a/b/file.csv", "id,name\n1,x\n")
      assert {:ok, "id,name\n1,x\n"} = Filesystem.get("a/b/file.csv")
    end

    test "get returns :not_found for an unknown reference" do
      assert {:error, :not_found} = Filesystem.get("missing.bin")
    end

    test "url returns a file:// URL under the configured root", %{root: root} do
      assert {:ok, "dir/x.txt"} = Filesystem.put("dir/x.txt", "ok")
      assert {:ok, url} = Filesystem.url("dir/x.txt")
      assert url == "file://" <> Path.join(Path.expand(root), "dir/x.txt")
    end

    test "rejects references that escape the root" do
      assert {:error, :invalid_reference} = Filesystem.put("../escape.txt", "nope")
      assert {:error, :invalid_reference} = Filesystem.get("../escape.txt")
      assert {:error, :invalid_reference} = Filesystem.url("/etc/passwd")
      assert {:error, :invalid_reference} = Filesystem.put("", "nope")
    end
  end
end
