defmodule DataSymphonyWeb.UploadLiveTest do
  @moduledoc """
  Guards CSV-1: LiveView upload UI acceptance criteria.

  1. Drag-and-drop and file-picker upload both work.
  2. Active limits are visible in the UI.
  3. Uploaded file lands in temp storage for downstream parsing.
  """
  use DataSymphonyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DataSymphony.BlobStorage
  alias DataSymphony.Datasets.Limits

  defp select_csv(view, name, contents) do
    entry = %{name: name, content: contents, type: "text/csv"}
    file_input(view, "#upload-form", :dataset, [entry])
  end

  describe "criterion 1: drag-and-drop and file-picker upload both work" do
    test "the drop zone is both a drop target and a file picker", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "label#dataset-dropzone[phx-drop-target]")
      assert has_element?(view, "#dataset-dropzone input[type='file']")
    end

    test "selecting a file registers an entry and enables staging", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#stage-button[disabled]")

      file = select_csv(view, "data.csv", "a,b\n1,2\n")
      assert render_upload(file, "data.csv") =~ "data.csv"

      assert has_element?(view, "#stage-button:not([disabled])")
    end
  end

  describe "criterion 2: active limits are visible in the UI" do
    test "every configured limit is rendered", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")
      limits = Limits.all()

      assert has_element?(view, "#limits")
      assert html =~ "Active limits"

      for label <- ["Max file size", "Max rows", "Max columns", "Max cell length"] do
        assert html =~ label
      end

      assert html =~ "10.0 MB"
      assert html =~ Integer.to_string(limits.max_column_count)
    end

    test "the configured byte limit drives allow_upload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      oversize = String.duplicate("x", Limits.max_byte_size() + 1)
      file = select_csv(view, "big.csv", oversize)

      assert {:error, [[_ref, :too_large]]} = render_upload(file, "big.csv")
    end
  end

  describe "criterion 3: uploaded file lands in temp storage for downstream parsing" do
    test "staging writes the file to blob storage and surfaces its reference", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      contents = "name,score\nada,42\n"

      file = select_csv(view, "scores.csv", contents)
      render_upload(file, "scores.csv")

      html = view |> form("#upload-form") |> render_submit()

      assert has_element?(view, "[id^='staged-']")
      assert html =~ "scores.csv"

      [ref] = Regex.run(~r{uploads/[^\s<"]+scores\.csv}, html)
      assert {:ok, ^contents} = BlobStorage.get(ref)
    end
  end
end
