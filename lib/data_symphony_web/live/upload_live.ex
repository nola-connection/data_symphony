defmodule DataSymphonyWeb.UploadLive do
  @moduledoc """
  CSV-1: the dataset upload experience.

  Supports drag-and-drop and file-picker uploads via `allow_upload/3` aligned
  to `DataSymphony.Datasets.Limits`, surfaces those active limits in the UI so
  failures are understandable up front, and stages accepted files in blob
  storage for downstream parsing rather than holding them in memory.
  """
  use DataSymphonyWeb, :live_view

  alias DataSymphony.BlobStorage
  alias DataSymphony.Datasets.Limits

  @impl true
  def mount(_params, _session, socket) do
    limits = Limits.all()

    {:ok,
     socket
     |> assign(page_title: "Upload CSV", limits: limits, staged: [])
     |> allow_upload(:dataset,
       accept: [".csv", "text/csv"],
       max_entries: 1,
       max_file_size: limits.max_byte_size
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="ds-shell">
      <.page_header eyebrow="Data Symphony · CSV" title="Upload a dataset to begin." />

      <.panel id="upload" class="ds-upload-panel">
        <:title>Dataset upload</:title>
        <:meta>{length(@uploads.dataset.entries)} selected</:meta>

        <form id="upload-form" phx-change="validate" phx-submit="stage">
          <.dropzone
            id="dataset-dropzone"
            upload={@uploads.dataset}
            prompt="Drag & drop a CSV here, or click to choose a file"
            hint={"Accepts .csv — up to #{format_bytes(@limits.max_byte_size)}"}
          />

          <p :for={err <- upload_errors(@uploads.dataset)} class="ds-error">
            {error_to_string(err)}
          </p>

          <ul :if={@uploads.dataset.entries != []} class="ds-file-list">
            <li :for={entry <- @uploads.dataset.entries} class="ds-file" id={"entry-#{entry.ref}"}>
              <div>
                <p class="ds-file-name">{entry.client_name}</p>
                <p class="ds-file-meta">{format_bytes(entry.client_size)} · {entry.progress}%</p>
                <progress class="ds-progress" max="100" value={entry.progress}></progress>
                <p :for={err <- upload_errors(@uploads.dataset, entry)} class="ds-error">
                  {error_to_string(err)}
                </p>
              </div>
              <button
                type="button"
                class="ds-button"
                phx-click="cancel"
                phx-value-ref={entry.ref}
                aria-label="Remove selected file"
              >
                Remove
              </button>
            </li>
          </ul>

          <button
            type="submit"
            id="stage-button"
            class="ds-button ds-button--primary"
            disabled={@uploads.dataset.entries == []}
          >
            Stage for parsing
          </button>
        </form>
      </.panel>

      <.panel id="limits">
        <:title>Active limits</:title>
        <:meta>Runtime configured</:meta>
        <.stat_list>
          <.stat label="Max file size" value={format_bytes(@limits.max_byte_size)} />
          <.stat label="Max rows" value={format_count(@limits.max_row_count)} />
          <.stat label="Max columns" value={format_count(@limits.max_column_count)} />
          <.stat label="Max cell length" value={format_bytes(@limits.max_cell_length)} />
        </.stat_list>
      </.panel>

      <.panel id="staged">
        <:title>Staged for parsing</:title>
        <:meta>{length(@staged)} file(s)</:meta>
        <p :if={@staged == []} class="ds-empty">
          No files staged yet. Accepted files are written to temp storage for downstream parsing.
        </p>
        <ul :if={@staged != []} class="ds-file-list">
          <li :for={file <- @staged} class="ds-file" id={"staged-#{file.id}"}>
            <div>
              <p class="ds-file-name">{file.name}</p>
              <p class="ds-file-meta">{format_bytes(file.size)} · {file.ref}</p>
            </div>
          </li>
        </ul>
      </.panel>
    </main>
    """
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :dataset, ref)}
  end

  def handle_event("stage", _params, socket) do
    staged =
      consume_uploaded_entries(socket, :dataset, fn %{path: path}, entry ->
        token = Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false)
        ref = "uploads/#{token}/#{Path.basename(entry.client_name)}"
        {:ok, stored} = BlobStorage.put(ref, File.read!(path))
        {:ok, %{id: token, ref: stored, name: entry.client_name, size: entry.client_size}}
      end)

    {:noreply,
     socket
     |> update(:staged, &(staged ++ &1))
     |> put_flash(:info, "Staged #{length(staged)} file(s) for parsing.")}
  end

  defp format_bytes(bytes) when bytes >= 1_048_576, do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  defp format_bytes(bytes) when bytes >= 1_024, do: "#{Float.round(bytes / 1_024, 1)} KB"
  defp format_bytes(bytes), do: "#{bytes} B"

  defp format_count(count) do
    String.replace(Integer.to_string(count), ~r/\B(?=(\d{3})+(?!\d))/, ",")
  end

  defp error_to_string(:too_large), do: "File exceeds the maximum size limit."
  defp error_to_string(:too_many_files), do: "Only one file can be uploaded at a time."
  defp error_to_string(:not_accepted), do: "Only .csv files are accepted."
  defp error_to_string(_other), do: "This file could not be accepted."
end
