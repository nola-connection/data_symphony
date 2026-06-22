const sampleCsv = `date,revenue,orders,region
2026-01-01,1500,12,north
2026-01-02,1800,14,south
2026-01-03,1200,9,west
2026-01-04,2100,18,north
2026-01-05,2400,22,east
2026-01-06,1750,15,south
2026-01-07,2600,25,west
2026-01-08,2300,19,east`;

const scales = {
  major: [0, 2, 4, 5, 7, 9, 11],
  minor: [0, 2, 3, 5, 7, 8, 10],
  pentatonic: [0, 2, 4, 7, 9]
};

const state = {
  dataset: null,
  sequence: null,
  playing: false,
  pausedAtMs: 0,
  startedAt: 0,
  lastFrameMs: 0,
  timers: [],
  animationFrame: 0,
  audioContext: null,
  gain: null
};

const els = {
  file: document.querySelector("#csv-file"),
  loadSample: document.querySelector("#load-sample"),
  datasetSummary: document.querySelector("#dataset-summary"),
  previewCount: document.querySelector("#preview-count"),
  previewTable: document.querySelector("#preview-table"),
  mappingState: document.querySelector("#mapping-state"),
  mappingControls: document.querySelector("#mapping-controls"),
  tempo: document.querySelector("#tempo"),
  tempoOutput: document.querySelector("#tempo-output"),
  scale: document.querySelector("#scale"),
  noteDivision: document.querySelector("#note-division"),
  synth: document.querySelector("#synth"),
  generate: document.querySelector("#generate"),
  play: document.querySelector("#play"),
  pause: document.querySelector("#pause"),
  stop: document.querySelector("#stop"),
  save: document.querySelector("#save"),
  canvas: document.querySelector("#visualizer"),
  progress: document.querySelector("#progress"),
  timeReadout: document.querySelector("#time-readout"),
  sequenceSummary: document.querySelector("#sequence-summary"),
  savedList: document.querySelector("#saved-list"),
  clearLibrary: document.querySelector("#clear-library")
};

function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = "";
  let inQuotes = false;

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    const next = text[i + 1];

    if (char === '"' && inQuotes && next === '"') {
      cell += '"';
      i += 1;
    } else if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === "," && !inQuotes) {
      row.push(cell.trim());
      cell = "";
    } else if ((char === "\n" || char === "\r") && !inQuotes) {
      if (char === "\r" && next === "\n") i += 1;
      row.push(cell.trim());
      if (row.some((value) => value.length > 0)) rows.push(row);
      row = [];
      cell = "";
    } else {
      cell += char;
    }
  }

  row.push(cell.trim());
  if (row.some((value) => value.length > 0)) rows.push(row);

  if (rows.length < 2) {
    throw new Error("CSV needs a header row and at least one data row.");
  }

  const headers = rows[0].map((header, index) => header || `Column ${index + 1}`);
  const dataRows = rows.slice(1);
  const invalidRow = dataRows.findIndex((values) => values.length !== headers.length);

  if (invalidRow >= 0) {
    throw new Error(`Row ${invalidRow + 2} has ${dataRows[invalidRow].length} cells; expected ${headers.length}.`);
  }

  return {
    headers,
    rows: dataRows.map((values) =>
      Object.fromEntries(headers.map((header, index) => [header, values[index] ?? ""]))
    ),
    byteSize: new Blob([text]).size,
    columnTypes: inferTypes(headers, dataRows)
  };
}

function inferTypes(headers, rows) {
  return Object.fromEntries(
    headers.map((header, index) => {
      const values = rows.map((row) => row[index]).filter(Boolean);
      const numeric = values.length > 0 && values.every((value) => Number.isFinite(Number(value)));
      const dates = values.length > 0 && values.every((value) => !Number.isNaN(Date.parse(value)));
      return [header, numeric ? "number" : dates ? "date" : "text"];
    })
  );
}

function loadDataset(csvText, name = "Untitled CSV") {
  try {
    state.dataset = parseCsv(csvText);
    state.dataset.name = name;
    state.sequence = null;
    state.pausedAtMs = 0;
    stopPlayback();
    renderDataset();
    renderMapping();
    renderSequence();
  } catch (error) {
    els.datasetSummary.textContent = error.message;
  }
}

function renderDataset() {
  const { dataset } = state;
  els.datasetSummary.textContent = `${dataset.name}: ${dataset.rows.length} rows, ${dataset.headers.length} columns, ${dataset.byteSize.toLocaleString()} bytes`;
  els.previewCount.textContent = `${dataset.rows.length} rows`;

  const head = dataset.headers.map((header) => `<th>${escapeHtml(header)}</th>`).join("");
  const body = dataset.rows
    .slice(0, 10)
    .map((row) => `<tr>${dataset.headers.map((header) => `<td>${escapeHtml(row[header])}</td>`).join("")}</tr>`)
    .join("");

  els.previewTable.className = "table-wrap";
  els.previewTable.innerHTML = `<table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
}

function renderMapping() {
  const { dataset } = state;
  if (!dataset) return;

  els.mappingState.textContent = "Ready";
  els.generate.disabled = false;
  const numericHeaders = dataset.headers.filter((header) => dataset.columnTypes[header] === "number");

  els.mappingControls.className = "mapping-list";
  els.mappingControls.innerHTML = dataset.headers
    .map((header, index) => {
      const defaultRole =
        index === 0 && dataset.columnTypes[header] === "date"
          ? "duration"
          : header === numericHeaders[0]
            ? "pitch"
            : header === numericHeaders[1]
              ? "velocity"
              : "ignore";
      const defaultStrategy = dataset.columnTypes[header] === "number" ? "linear" : "string_sum";

      return `
        <div class="mapping-row" data-column="${escapeAttr(header)}">
          <div class="column-name">
            <strong>${escapeHtml(header)}</strong>
            <span>${dataset.columnTypes[header]}</span>
          </div>
          <label>
            Role
            <select class="role">
              ${option("ignore", "Ignore", defaultRole)}
              ${option("pitch", "Pitch", defaultRole)}
              ${option("velocity", "Velocity", defaultRole)}
              ${option("duration", "Duration", defaultRole)}
              ${option("gate", "Gate", defaultRole)}
            </select>
          </label>
          <label>
            Strategy
            <select class="strategy">
              ${option("linear", "Linear", defaultStrategy)}
              ${option("string_sum", "String sum", defaultStrategy)}
              ${option("bucketed", "Bucketed", defaultStrategy)}
              ${option("parity_gate", "Parity gate", defaultStrategy)}
            </select>
          </label>
        </div>`;
    })
    .join("");
}

function option(value, label, selected) {
  return `<option value="${value}"${value === selected ? " selected" : ""}>${label}</option>`;
}

function currentMapping() {
  const columns = {};
  document.querySelectorAll(".mapping-row").forEach((row) => {
    columns[row.dataset.column] = {
      role: row.querySelector(".role").value,
      strategy: row.querySelector(".strategy").value
    };
  });

  return {
    tempoBpm: Number(els.tempo.value),
    scale: els.scale.value,
    noteDivision: els.noteDivision.value,
    synth: els.synth.value,
    columns
  };
}

function generateSequence() {
  const { dataset } = state;
  if (!dataset) return;

  els.mappingState.textContent = "Generating...";
  els.generate.disabled = true;

  window.setTimeout(() => {
    const mapping = currentMapping();
    const notes = deriveNotes(dataset, mapping);
    state.sequence = {
      id: crypto.randomUUID(),
      datasetName: dataset.name,
      mapping,
      notes,
      durationMs: sequenceDuration(notes, mapping),
      createdAt: new Date().toISOString()
    };

    els.mappingState.textContent = "Generated";
    els.generate.disabled = false;
    state.pausedAtMs = 0;
    renderSequence();
  }, 450);
}

function deriveNotes(dataset, mapping) {
  const roleColumns = Object.entries(mapping.columns).reduce((acc, [column, config]) => {
    if (config.role !== "ignore") acc[config.role] = { column, ...config };
    return acc;
  }, {});

  const numericStats = Object.fromEntries(
    dataset.headers.map((header) => {
      const nums = dataset.rows.map((row) => Number(row[header])).filter(Number.isFinite);
      return [header, { min: Math.min(...nums, 0), max: Math.max(...nums, 1) }];
    })
  );

  return dataset.rows.slice(0, 2000).map((row, index) => {
    const pitchRaw = deriveValue(row, roleColumns.pitch, numericStats);
    const velocityRaw = deriveValue(row, roleColumns.velocity, numericStats);
    const durationRaw = deriveValue(row, roleColumns.duration, numericStats);
    const gateRaw = deriveValue(row, roleColumns.gate, numericStats);
    const gatedOff = roleColumns.gate && gateRaw % 2 === 0;
    const baseDurationMs = quantizeDuration(mapRange(durationRaw ?? index, 0, 127, 170, 760), "1/4", 120);
    const pitch = gatedOff || pitchRaw == null ? null : quantizePitch(mapRange(pitchRaw, 0, 127, 48, 84), mapping.scale);

    return {
      rowIndex: index + 1,
      pitch,
      velocity: pitch == null ? 0 : Math.round(mapRange(velocityRaw ?? pitchRaw ?? 80, 0, 127, 38, 118)),
      baseDurationMs,
      label: dataset.headers.map((header) => row[header]).join(" | ")
    };
  });
}

function deriveValue(row, config, numericStats) {
  if (!config) return null;
  const value = row[config.column] ?? "";
  const number = Number(value);

  if (config.strategy === "linear" && Number.isFinite(number)) {
    const stats = numericStats[config.column];
    return mapRange(number, stats.min, stats.max, 0, 127);
  }

  const stringTotal = [...String(value)].reduce((sum, char) => sum + char.charCodeAt(0), 0);
  if (config.strategy === "bucketed") return (stringTotal % 12) * 10;
  if (config.strategy === "parity_gate") return stringTotal % 2;
  return stringTotal % 128;
}

function mapRange(value, inMin, inMax, outMin, outMax) {
  if (!Number.isFinite(value) || inMax === inMin) return (outMin + outMax) / 2;
  return outMin + ((value - inMin) / (inMax - inMin)) * (outMax - outMin);
}

function quantizePitch(value, scaleName) {
  const midi = Math.round(value);
  const octave = Math.floor(midi / 12);
  const note = midi % 12;
  const scale = scales[scaleName] ?? scales.major;
  const closest = scale.reduce((best, candidate) =>
    Math.abs(candidate - note) < Math.abs(best - note) ? candidate : best
  );
  return octave * 12 + closest;
}

function quantizeDuration(ms, quantize, tempoBpm) {
  if (quantize === "none") return Math.round(ms);
  const beatMs = 60000 / tempoBpm;
  const divisions = { "1/4": 1, "1/8": 2, "1/16": 4 };
  const step = beatMs / (divisions[quantize] ?? 4);
  return Math.max(step, Math.round(ms / step) * step);
}

function tempoFactor(tempoBpm) {
  return 120 / tempoBpm;
}

function divisionFactor(noteDivision) {
  return {
    "1/2": 2,
    "1/4": 1,
    "1/8": 0.5,
    "1/16": 0.25
  }[noteDivision] ?? 1;
}

function activeMapping(overrides = {}) {
  return {
    tempoBpm: state.sequence?.mapping.tempoBpm ?? 120,
    noteDivision: state.sequence?.mapping.noteDivision ?? state.sequence?.mapping.quantize ?? "1/4",
    ...overrides
  };
}

function noteDuration(note, mapping = activeMapping()) {
  return Math.round(
    (note.baseDurationMs ?? note.durationMs ?? 250) *
      tempoFactor(mapping.tempoBpm) *
      divisionFactor(mapping.noteDivision)
  );
}

function sequenceDuration(notes, mapping = activeMapping()) {
  return notes.reduce((sum, note) => sum + noteDuration(note, mapping), 0);
}

function refreshSequenceTiming(updates) {
  if (!state.sequence) return;
  const wasPlaying = state.playing;
  const previousDuration = state.sequence.durationMs;
  const currentPosition = wasPlaying
    ? Math.min(performance.now() - state.startedAt, state.sequence.durationMs)
    : state.pausedAtMs;

  if (wasPlaying) pausePlayback();

  state.sequence.mapping = { ...activeMapping(), ...state.sequence.mapping, ...updates };
  state.sequence.durationMs = sequenceDuration(state.sequence.notes, state.sequence.mapping);
  state.pausedAtMs = Math.min(
    previousDuration ? currentPosition * (state.sequence.durationMs / previousDuration) : 0,
    state.sequence.durationMs
  );
  updateSequenceSummary();
  drawVisualizer(state.pausedAtMs);
  updateTimeline(state.pausedAtMs, state.sequence.durationMs);

  if (wasPlaying) playSequence();
}

function updateSequenceSummary() {
  const { sequence } = state;
  sequence.mapping.noteDivision = sequence.mapping.noteDivision ?? sequence.mapping.quantize ?? "1/4";
  els.sequenceSummary.textContent = `${sequence.notes.length} notes, ${formatTime(sequence.durationMs)}, ${sequence.mapping.tempoBpm} BPM, ${sequence.mapping.noteDivision}`;
}

function renderSequence() {
  const { sequence } = state;
  stopPlayback();

  if (!sequence) {
    els.sequenceSummary.textContent = "Generate a sequence to play it here.";
    [els.play, els.pause, els.stop, els.save].forEach((button) => {
      button.disabled = true;
    });
    drawEmptyVisualizer();
    updateTimeline(0, 0);
    return;
  }

  updateSequenceSummary();
  [els.play, els.stop, els.save].forEach((button) => {
    button.disabled = false;
  });
  els.pause.disabled = true;
  drawVisualizer(0);
  updateTimeline(0, sequence.durationMs);
}

function ensureAudio() {
  if (!state.audioContext) {
    state.audioContext = new AudioContext();
    state.gain = state.audioContext.createGain();
    state.gain.gain.value = 0.18;
    state.gain.connect(state.audioContext.destination);
  }
  return state.audioContext;
}

function playSequence() {
  if (!state.sequence) return;
  const context = ensureAudio();
  context.resume();
  stopTimers();

  const startOffsetMs = state.pausedAtMs;
  state.startedAt = performance.now() - startOffsetMs;
  state.playing = true;
  els.play.disabled = true;
  els.pause.disabled = false;
  els.stop.disabled = false;

  let cursor = 0;
  state.sequence.notes.forEach((note) => {
    const durationMs = noteDuration(note, state.sequence.mapping);
    const noteStart = cursor;
    cursor += durationMs;
    if (noteStart + durationMs < startOffsetMs || note.pitch == null) return;

    const delay = Math.max(0, noteStart - startOffsetMs);
    const playDuration = Math.max(80, durationMs - Math.max(0, startOffsetMs - noteStart));
    const timer = window.setTimeout(() => playTone(note, playDuration), delay);
    state.timers.push(timer);
  });

  const endTimer = window.setTimeout(stopPlayback, Math.max(0, state.sequence.durationMs - startOffsetMs));
  state.timers.push(endTimer);
  animate();
}

function playTone(note, durationMs) {
  const context = ensureAudio();
  const oscillator = context.createOscillator();
  const envelope = context.createGain();
  const now = context.currentTime;
  const duration = durationMs / 1000;

  oscillator.type = state.sequence.mapping.synth;
  oscillator.frequency.value = 440 * 2 ** ((note.pitch - 69) / 12);
  envelope.gain.setValueAtTime(0.0001, now);
  envelope.gain.exponentialRampToValueAtTime(Math.max(0.02, note.velocity / 127), now + 0.018);
  envelope.gain.exponentialRampToValueAtTime(0.0001, now + duration);
  oscillator.connect(envelope);
  envelope.connect(state.gain);
  oscillator.start(now);
  oscillator.stop(now + duration + 0.02);
}

function pausePlayback() {
  if (!state.playing) return;
  state.pausedAtMs = Math.min(performance.now() - state.startedAt, state.sequence.durationMs);
  state.playing = false;
  stopTimers();
  window.cancelAnimationFrame(state.animationFrame);
  els.play.disabled = false;
  els.pause.disabled = true;
}

function stopPlayback() {
  state.playing = false;
  state.pausedAtMs = 0;
  stopTimers();
  window.cancelAnimationFrame(state.animationFrame);
  if (state.sequence) {
    drawVisualizer(0);
    updateTimeline(0, state.sequence.durationMs);
    els.play.disabled = false;
    els.pause.disabled = true;
    els.stop.disabled = false;
  }
}

function stopTimers() {
  state.timers.forEach((timer) => window.clearTimeout(timer));
  state.timers = [];
}

function animate() {
  if (!state.playing || !state.sequence) return;
  const elapsed = Math.min(performance.now() - state.startedAt, state.sequence.durationMs);
  state.pausedAtMs = elapsed;
  state.lastFrameMs = elapsed;
  drawVisualizer(elapsed);
  updateTimeline(elapsed, state.sequence.durationMs);
  state.animationFrame = window.requestAnimationFrame(animate);
}

function drawEmptyVisualizer() {
  const ctx = els.canvas.getContext("2d");
  const { width, height } = els.canvas;
  drawCyberpunkStage(ctx, width, height, 0);
  ctx.fillStyle = "#c7fff8";
  ctx.shadowColor = "#2cf5ff";
  ctx.shadowBlur = 24;
  ctx.font = "28px system-ui";
  ctx.textAlign = "center";
  ctx.fillText("Awaiting generated sequence", width / 2, height / 2);
  ctx.shadowBlur = 0;
}

function drawVisualizer(elapsedMs) {
  if (!state.sequence) return drawEmptyVisualizer();
  const ctx = els.canvas.getContext("2d");
  const { width, height } = els.canvas;
  drawCyberpunkStage(ctx, width, height, elapsedMs);

  let cursor = 0;
  state.sequence.notes.forEach((note) => {
    const durationMs = noteDuration(note, state.sequence.mapping);
    const x = (cursor / state.sequence.durationMs) * width;
    const w = Math.max(5, (durationMs / state.sequence.durationMs) * width - 3);
    const active = elapsedMs >= cursor && elapsedMs <= cursor + durationMs;
    const y = note.pitch == null ? height - 42 : height - mapRange(note.pitch, 42, 88, 58, height - 58);
    const h = note.pitch == null ? 12 : mapRange(note.velocity, 0, 127, 18, 86);
    const hue = note.pitch == null ? 210 : mapRange(note.pitch, 42, 88, 178, 318);

    ctx.save();
    ctx.globalAlpha = note.pitch == null ? 0.42 : active ? 1 : 0.72;
    ctx.shadowColor = note.pitch == null ? "#35515c" : `hsl(${hue} 100% 62%)`;
    ctx.shadowBlur = active ? 28 : 13;
    ctx.fillStyle = note.pitch == null ? "#34424d" : `hsl(${hue} 100% ${active ? 65 : 52}%)`;
    ctx.fillRect(x, y - h / 2, w, h);
    ctx.fillStyle = active ? "#f6ff8f" : "rgb(255 255 255 / 0.34)";
    ctx.fillRect(x, y - h / 2, w, 2);
    ctx.restore();
    cursor += durationMs;
  });

  ctx.globalAlpha = 1;
  const playhead = state.sequence.durationMs ? (elapsedMs / state.sequence.durationMs) * width : 0;
  ctx.shadowColor = "#ff2bd6";
  ctx.shadowBlur = 24;
  ctx.strokeStyle = "#ff2bd6";
  ctx.lineWidth = 5;
  ctx.beginPath();
  ctx.moveTo(playhead, 0);
  ctx.lineTo(playhead, height);
  ctx.stroke();
  ctx.shadowBlur = 0;
  ctx.fillStyle = "#f6ff8f";
  ctx.fillRect(Math.max(0, playhead - 11), 0, 22, 4);
  drawScanlines(ctx, width, height);
}

function drawCyberpunkStage(ctx, width, height, elapsedMs) {
  const gradient = ctx.createLinearGradient(0, 0, width, height);
  gradient.addColorStop(0, "#070a18");
  gradient.addColorStop(0.52, "#101026");
  gradient.addColorStop(1, "#061f24");
  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);

  ctx.save();
  ctx.globalAlpha = 0.52;
  ctx.strokeStyle = "#1fe7ff";
  ctx.lineWidth = 1;
  const offset = (elapsedMs / 28) % 42;
  for (let x = -42 + offset; x < width + 42; x += 42) {
    ctx.beginPath();
    ctx.moveTo(x, height);
    ctx.lineTo(width / 2 + (x - width / 2) * 0.22, height * 0.34);
    ctx.stroke();
  }
  for (let y = height * 0.34; y < height; y += 24) {
    const depth = (y - height * 0.34) / (height * 0.66);
    ctx.globalAlpha = 0.18 + depth * 0.46;
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(width, y);
    ctx.stroke();
  }
  ctx.restore();

  ctx.save();
  ctx.globalAlpha = 0.22;
  ctx.fillStyle = "#ff2bd6";
  ctx.beginPath();
  ctx.ellipse(width * 0.82, height * 0.2, width * 0.18, height * 0.1, -0.25, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function drawScanlines(ctx, width, height) {
  ctx.save();
  ctx.globalAlpha = 0.12;
  ctx.fillStyle = "#ffffff";
  for (let y = 0; y < height; y += 8) {
    ctx.fillRect(0, y, width, 1);
  }
  ctx.restore();
}

function updateTimeline(elapsedMs, durationMs) {
  els.progress.value = durationMs ? (elapsedMs / durationMs) * 100 : 0;
  els.timeReadout.textContent = `${formatTime(elapsedMs)} / ${formatTime(durationMs)}`;
}

function saveSequence() {
  if (!state.sequence) return;
  const saved = getSaved();
  saved.unshift(state.sequence);
  localStorage.setItem("data-symphony-sequences", JSON.stringify(saved.slice(0, 12)));
  renderSaved();
}

function getSaved() {
  try {
    return JSON.parse(localStorage.getItem("data-symphony-sequences") || "[]");
  } catch {
    return [];
  }
}

function renderSaved() {
  const saved = getSaved();
  if (saved.length === 0) {
    els.savedList.className = "saved-list empty-state";
    els.savedList.textContent = "No saved sequences yet.";
    return;
  }

  els.savedList.className = "saved-list";
  els.savedList.innerHTML = saved
    .map(
      (sequence) => `
        <button class="saved-item" type="button" data-id="${sequence.id}">
          <strong>${escapeHtml(sequence.datasetName)}</strong>
          <span>${sequence.notes.length} notes · ${formatTime(sequence.durationMs)} · ${new Date(sequence.createdAt).toLocaleString()}</span>
        </button>`
    )
    .join("");
}

function loadSaved(id) {
  const sequence = getSaved().find((item) => item.id === id);
  if (!sequence) return;
  state.sequence = sequence;
  state.sequence.mapping.noteDivision = state.sequence.mapping.noteDivision ?? state.sequence.mapping.quantize ?? "1/4";
  state.sequence.durationMs = sequenceDuration(state.sequence.notes, state.sequence.mapping);
  els.tempo.value = state.sequence.mapping.tempoBpm;
  els.tempoOutput.textContent = `${state.sequence.mapping.tempoBpm} BPM`;
  els.noteDivision.value = state.sequence.mapping.noteDivision;
  state.pausedAtMs = 0;
  renderSequence();
}

function formatTime(ms) {
  const totalSeconds = Math.round(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = String(totalSeconds % 60).padStart(2, "0");
  return `${minutes}:${seconds}`;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => {
    return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" }[char];
  });
}

function escapeAttr(value) {
  return escapeHtml(value).replace(/`/g, "&#096;");
}

els.loadSample.addEventListener("click", () => loadDataset(sampleCsv, "sample-sales.csv"));
els.file.addEventListener("change", async (event) => {
  const file = event.target.files[0];
  if (!file) return;
  loadDataset(await file.text(), file.name);
});
els.tempo.addEventListener("input", () => {
  const tempoBpm = Number(els.tempo.value);
  els.tempoOutput.textContent = `${tempoBpm} BPM`;
  refreshSequenceTiming({ tempoBpm });
});
els.noteDivision.addEventListener("change", () => {
  refreshSequenceTiming({ noteDivision: els.noteDivision.value });
});
els.generate.addEventListener("click", generateSequence);
els.play.addEventListener("click", playSequence);
els.pause.addEventListener("click", pausePlayback);
els.stop.addEventListener("click", stopPlayback);
els.save.addEventListener("click", saveSequence);
els.savedList.addEventListener("click", (event) => {
  const button = event.target.closest("[data-id]");
  if (button) loadSaved(button.dataset.id);
});
els.clearLibrary.addEventListener("click", () => {
  localStorage.removeItem("data-symphony-sequences");
  renderSaved();
});

drawEmptyVisualizer();
renderSaved();
