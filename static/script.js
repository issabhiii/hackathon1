const fileInput = document.getElementById("file");
const output = document.getElementById("output");
const submitBtn = document.getElementById("submitBtn");
const langInput = document.getElementById("lang");
const dropzone = document.getElementById("dropzone");

let currentFile = null;

function setOutput(text) { output.textContent = text ?? ""; }
function setBusy(b) { submitBtn.disabled = b; submitBtn.textContent = b ? "Running..." : "Run OCR"; }

dropzone.addEventListener("click", () => fileInput.click());

["dragenter", "dragover"].forEach(evt =>
  dropzone.addEventListener(evt, e => { e.preventDefault(); e.stopPropagation(); dropzone.classList.add("drag"); })
);
["dragleave", "drop"].forEach(evt =>
  dropzone.addEventListener(evt, e => { e.preventDefault(); e.stopPropagation(); dropzone.classList.remove("drag"); })
);
dropzone.addEventListener("drop", e => {
  currentFile = e.dataTransfer.files?.[0] ?? null;
  setOutput(currentFile ? `Selected: ${currentFile.name}` : "No file");
});
fileInput.addEventListener("change", e => {
  currentFile = e.target.files?.[0] ?? null;
  setOutput(currentFile ? `Selected: ${currentFile.name}` : "No file");
});

submitBtn.addEventListener("click", async () => {
  if (!currentFile) { alert("Pick an image first."); return; }
  try {
    setBusy(true);
    const form = new FormData();
    form.append("file", currentFile);

    // 1) Try structured OCR (PaddleOCR)
    let res = await fetch("/api/parse-structured", { method: "POST", body: form });
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
      return;
    }

    // 2) Fallback to Tesseract (classic)
    form.append("lang", langInput.value || "eng");
    res = await fetch("/api/parse", { method: "POST", body: form });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data2 = await res.json();
    setOutput(data2.text || "(no text found)");
  } catch (err) {
    setOutput(`Error: ${err.message}`);
  } finally {
    setBusy(false);
  }
});
