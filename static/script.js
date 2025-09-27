console.log("[boot] script.js loaded");

const fileInput = document.getElementById('file');
const output = document.getElementById('output');
const result = document.getElementById('result');
const submitBtn = document.getElementById('submitBtn');
const extractBtn = document.getElementById('extractBtn');
const extractCloudBtn = document.getElementById('extractCloudBtn');
const buildSpecBtn = document.getElementById('buildSpecBtn');
const buildSpecVisionBtn = document.getElementById('buildSpecVisionBtn');
const langInput = document.getElementById('lang');

console.log("[boot] found buttons:", {
  submitBtn: !!submitBtn,
  extractBtn: !!extractBtn,
  extractCloudBtn: !!extractCloudBtn,
  buildSpecBtn: !!buildSpecBtn,
  buildSpecVisionBtn: !!buildSpecVisionBtn
});

let currentFile = null;
fileInput.addEventListener('change', (e) => {
  currentFile = e.target.files[0];
  console.log("[choose] file:", currentFile);
  output.textContent = "";
  result.textContent = "";
});

async function postForm(url, file, extraParams = {}) {
  const qs = new URLSearchParams(extraParams).toString();
  const full = qs ? `${url}?${qs}` : url;
  const fd = new FormData();
  fd.append('file', file);
  console.log("[fetch] POST", full);
  const res = await fetch(full, { method: 'POST', body: fd });
  console.log("[fetch]", url, "status:", res.status);
  const text = await res.text();
  console.log("[fetch]", url, "raw:", text);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return JSON.parse(text);
}

// Run OCR (structured)
submitBtn.addEventListener('click', async () => {
  try {
    if (!currentFile) return alert("Pick a file first.");
    console.log("[click] Run OCR");
    const data = await postForm('/api/parse-structured', currentFile, { lang: langInput.value || 'en' });
    const lines = [];
    (data.columns || []).forEach(col => {
      (col.items || []).forEach(it => { if (it.text) lines.push(it.text); });
    });
    output.textContent = (lines.join("\n") || "(no text found)");
  } catch (err) {
    console.error(err);
    alert("OCR error: " + err.message);
  }
});

// Extract (local/cloud legacy)
extractBtn.addEventListener('click', async () => {
  try {
    if (!currentFile) return alert("Pick a file first.");
    console.log("[click] Extract (LLM)");
    const data = await postForm('/api/extract', currentFile, { lang: langInput.value || 'en' });
    result.textContent = JSON.stringify(data, null, 2);
  } catch (err) {
    console.error("[Extract local] error:", err);
    alert("Extract (LLM) error: " + err.message);
  }
});

extractCloudBtn.addEventListener('click', async () => {
  try {
    if (!currentFile) return alert("Pick a file first.");
    console.log("[click] Extract (Cloud)");
    const data = await postForm('/api/extract', currentFile, { lang: langInput.value || 'en', cloud: 1 });
    result.textContent = JSON.stringify(data, null, 2);
  } catch (err) {
    console.error("[Extract cloud] error:", err);
    alert("Extract (Cloud) error: " + err.message);
  }
});

// Build Spec JSON (text-only cloud)
buildSpecBtn.addEventListener('click', async () => {
  try {
    if (!currentFile) return alert("Pick a file first.");
    console.log("[click] Build Spec JSON");
    const data = await postForm('/api/spec', currentFile, { lang: langInput.value || 'en' });
    result.textContent = JSON.stringify(data, null, 2);
  } catch (err) {
    console.error("[Build Spec] error:", err);
    alert("Build Spec error: " + err.message);
  }
});

// Build Spec (Vision)
buildSpecVisionBtn.addEventListener('click', async () => {
  try {
    if (!currentFile) return alert("Pick a file first.");
    console.log("[click] Build Spec (Vision)");
    const data = await postForm('/api/spec-vision', currentFile, {});
    result.textContent = JSON.stringify(data, null, 2);
  } catch (err) {
    console.error("[Build Spec Vision] error:", err);
    alert("Build Spec (Vision) error: " + err.message);
  }
});
