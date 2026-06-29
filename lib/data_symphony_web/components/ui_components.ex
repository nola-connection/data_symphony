defmodule DataSymphonyWeb.UIComponents do
  @moduledoc """
  Reusable presentational building blocks for Data Symphony pages.

  These primitives back the CSV upload experience and are intentionally
  source-agnostic, so future ingestion pages (weather, traffic, finances)
  can reuse the same masthead, panels, drop zone, and stat readouts rather
  than re-styling each screen.
  """
  use Phoenix.Component

  @doc "Page masthead with an eyebrow, a title, and optional actions."
  attr :eyebrow, :string, default: nil
  attr :title, :string, required: true
  slot :actions

  def page_header(assigns) do
    ~H"""
    <header class="ds-masthead">
      <div>
        <p :if={@eyebrow} class="ds-eyebrow">{@eyebrow}</p>
        <h1 class="ds-title">{@title}</h1>
      </div>
      <div :if={@actions != []} class="ds-masthead-actions">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc "A bordered content panel with a heading and an optional meta badge."
  attr :id, :string, required: true
  attr :class, :string, default: nil
  slot :title, required: true
  slot :meta
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <section id={@id} class={["ds-panel", @class]} aria-labelledby={"#{@id}-title"}>
      <div class="ds-panel-heading">
        <h2 id={"#{@id}-title"}>{render_slot(@title)}</h2>
        <span :if={@meta != []} class="ds-meta">{render_slot(@meta)}</span>
      </div>
      {render_slot(@inner_block)}
    </section>
    """
  end

  @doc """
  Drag-and-drop plus file-picker drop zone bound to a LiveView upload.

  Pass the `Phoenix.LiveView.UploadConfig` from `@uploads`. Dropping a file
  onto the zone and clicking it to open the picker feed the same upload entry.
  """
  attr :id, :string, required: true
  attr :upload, Phoenix.LiveView.UploadConfig, required: true
  attr :prompt, :string, default: "Drag a file here, or click to browse"
  attr :hint, :string, default: nil

  def dropzone(assigns) do
    ~H"""
    <label id={@id} class="ds-dropzone" phx-drop-target={@upload.ref}>
      <.live_file_input upload={@upload} />
      <span class="ds-dropzone-prompt">{@prompt}</span>
      <span :if={@hint} class="ds-dropzone-hint">{@hint}</span>
    </label>
    """
  end

  @doc "A responsive grid of labelled stats; used for limits and metadata."
  slot :inner_block, required: true

  def stat_list(assigns) do
    ~H"""
    <ul class="ds-stat-list">{render_slot(@inner_block)}</ul>
    """
  end

  @doc "A single labelled value rendered inside a `stat_list/1`."
  attr :label, :string, required: true
  attr :value, :string, required: true

  def stat(assigns) do
    ~H"""
    <li class="ds-stat">
      <span class="ds-stat-label">{@label}</span>
      <span class="ds-stat-value">{@value}</span>
    </li>
    """
  end
end
