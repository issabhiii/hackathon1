(function () {
  console.log("[boot] script.js loaded");

  const fileInput = document.getElementById("file");
  const output = document.getElementById("output");
  const submitBtn = document.getElementById("submitBtn");
  const extractBtn = document.getElementById("extractBtn");
  const langInput = document.getElementById("lang");
  const dropzone = document.getElementById("dropzone");
  const statusEl = document.getElementById("status");

  if (!submitBtn || !extractBtn) {
    console.error("[boot] buttons not found in DOM");
  } else {
    console.log("[boot] found buttons:", { submitBtn: !!submitBtn, extractBtn: !!extractBtn });
  }

  let currentFile = null;

  function setOutput(text) { output.textContent = text ?? ""; }
  function setBusy(b) {
    submitBtn.disabled = b;
    extractBtn.disabled = b;
    submitBtn.textContent = b ? "Running..." : "Run OCR";
    statusEl.textContent = b ? "status: working..." : "status: idle";
  }

  // --- File selection + drop ---
  dropzone.addEventListener("click", () => fileInput.click());
  ["dragenter", "dragover"].forEach(evt =>
    dropzone.addEventListener(evt, e => { e.preventDefault(); e.stopPropagation(); dropzone.classList.add("drag"); })
  );
  ["dragleave", "drop"].forEach(evt =>
    dropzone.addEventListener(evt, e => { e.preventDefault(); e.stopPropagation(); dropzone.classList.remove("drag"); })
  );
  dropzone.addEventListener("drop", e => {
    currentFile = e.dataTransfer.files?.[0] ?? null;
    console.log("[drop] file:", currentFile);
    setOutput(currentFile ? `Selected: ${currentFile.name}` : "No file");
  });
  fileInput.addEventListener("change", e => {
    currentFile = e.target.files?.[0] ?? null;
    console.log("[choose] file:", currentFile);
    setOutput(currentFile ? `Selected: ${currentFile.name}` : "No file");
  });

  // --- Run OCR (structured->fallback) ---
  submitBtn.addEventListener("click", async () => {
    console.log("[click] Run OCR");
    if (!currentFile) { alert("Pick an image first."); return; }
    try {
      setBusy(true);
      const form = new FormData();
      form.append("file", currentFile);

      console.log("[fetch] POST /api/parse-structured");
      let res = await fetch("/api/parse-structured", { method: "POST", body: form });
      console.log("[fetch] /api/parse-structured status:", res.status);
      if (res.ok) {
        const data = await res.json();
        const lines = [];
        if (data.columns && data.columns.length > 0) {
          data.columns.forEach((col, ci) => {
            lines.push(`--- Column ${ci+1} ---`);
            col.items.forEach(it => lines.push(it.text));
            lines.push("");
          });
        } else {
          lines.push("(no text found by structured OCR)");
        }
        setOutput(lines.join("\n"));
        statusEl.textContent = "status: structured OCR OK";
        return;
      }

      // fallback to Tesseract
      form.append("lang", langInput.value || "eng");
      console.log("[fetch] POST /api/parse");
      res = await fetch("/api/parse", { method: "POST", body: form });
      console.log("[fetch] /api/parse status:", res.status);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data2 = await res.json();
      setOutput(data2.text || "(no text found)");
      statusEl.textContent = "status: tesseract fallback OK";
    } catch (err) {
      console.error("[Run OCR] error:", err);
      setOutput(`Error: ${err.message}`);
      statusEl.textContent = "status: error";
    } finally {
      setBusy(false);
    }
  });

  // --- Extract (LLM) ---
  extractBtn.addEventListener("click", async () => {
    console.log("[click] Extract (LLM)");
    if (!currentFile) { alert("Pick an image first."); return; }
    try {
      setBusy(true);
      const form = new FormData();
      form.append("file", currentFile);
      console.log("[fetch] POST /api/extract");
      const res = await fetch("/api/extract", { method: "POST", body: form });
      console.log("[fetch] /api/extract status:", res.status);
      const text = await res.text();
      console.log("[fetch] /api/extract raw:", text);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = JSON.parse(text);
      statusEl.textContent = data.model_used === "ollama-llm" ? "LLM: ON ✅" : "LLM: fallback ❌";
      setOutput(JSON.stringify(data, null, 2));
    } catch (err) {
      console.error("[Extract] error:", err);
      setOutput(`Error: ${err.message}`);
      statusEl.textContent = "status: error";
    } finally {
      setBusy(false);
    }
  });
})();
