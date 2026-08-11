/// Static HTML page that renders the SimGate API docs.
///
/// A self-contained, Swagger-UI-style page (no external CDN assets, so it
/// works on LANs without internet). It fetches the OpenAPI document from
/// `/swagger.json`, renders every operation grouped by tag, and lets the user
/// authorize with the access token (prefilled from the live config) and send
/// real test requests with clean, syntax-highlighted responses.
class SwaggerUi {
  SwaggerUi._();

  static const String contentType = 'text/html; charset=utf-8';

  static const String html = r'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SimGate API Docs</title>
<style>
  :root {
    --bg: #14161a;
    --surface: #1d2026;
    --surface-2: #23272e;
    --border: #2e333b;
    --text: #e7e9ec;
    --text-2: #9aa4b2;
    --mono: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
    --get: #61affe;
    --post: #49cc90;
    --put: #fca130;
    --delete: #f93e3e;
    --err: #f06e6e;
    --ok: #7fd6a5;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: var(--bg);
    color: var(--text);
    font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  }
  ::-webkit-scrollbar { width: 10px; height: 10px; }
  ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 5px; }

  /* Header */
  header {
    position: sticky; top: 0; z-index: 20;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 12px 24px;
    display: flex; align-items: center; gap: 16px; flex-wrap: wrap;
  }
  .logo { font-size: 18px; font-weight: 800; letter-spacing: .5px; white-space: nowrap; }
  .logo .acc { color: var(--get); }
  .sub { color: var(--text-2); font-size: 12px; margin-top: 2px; }
  .spacer { flex: 1; }
  .pill {
    font-family: var(--mono); font-size: 12px;
    background: var(--surface-2); border: 1px solid var(--border);
    color: var(--text-2); padding: 6px 10px; border-radius: 6px;
  }
  select.pill { cursor: pointer; color: var(--text); }
  .btn {
    font: 600 13px/1 -apple-system, sans-serif;
    background: var(--surface-2); color: var(--text);
    border: 1px solid var(--border); border-radius: 6px;
    padding: 9px 14px; cursor: pointer; transition: filter .15s;
  }
  .btn:hover { filter: brightness(1.15); }
  .btn:disabled { opacity: .45; cursor: not-allowed; }
  .btn.auth { border-color: var(--post); color: var(--post); }
  .btn.primary { background: var(--get); border-color: var(--get); color: #0b1220; }
  .btn.danger { border-color: var(--delete); color: var(--delete); }

  /* Toolbar */
  .toolbar { display: flex; gap: 12px; padding: 16px 24px 0; align-items: center; flex-wrap: wrap; }
  .toolbar input[type=text] {
    flex: 1; min-width: 220px;
    background: var(--surface); color: var(--text);
    border: 1px solid var(--border); border-radius: 6px;
    padding: 9px 12px; font-size: 13px; outline: none;
  }
  .toolbar input[type=text]:focus { border-color: var(--get); }
  .info-line { padding: 6px 24px; color: var(--text-2); font-size: 12px; }

  /* Layout */
  .layout { display: flex; gap: 20px; padding: 16px 24px 60px; align-items: flex-start; }
  .nav {
    position: sticky; top: 64px; flex: 0 0 230px;
    max-height: calc(100vh - 90px); overflow: auto;
    background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
    padding: 10px;
  }
  .nav h4 { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: var(--text-2); margin: 10px 8px 6px; }
  .nav a {
    display: block; padding: 5px 8px; border-radius: 6px;
    color: var(--text-2); text-decoration: none; font-size: 12.5px; cursor: pointer;
  }
  .nav a:hover { background: var(--surface-2); color: var(--text); }
  .nav a .mini {
    display: inline-block; width: 44px; text-align: center;
    font-family: var(--mono); font-size: 10px; font-weight: 700;
    border-radius: 3px; padding: 1px 0; margin-right: 6px; color: #fff;
  }
  .main { flex: 1; min-width: 0; }

  /* Tags & operations */
  .tag { margin-bottom: 24px; }
  .tag-head {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 10px 10px 0 0; padding: 12px 16px;
    display: flex; align-items: center; gap: 10px; cursor: pointer;
  }
  .tag-head h3 { font-size: 16px; font-weight: 700; }
  .tag-head .count { color: var(--text-2); font-size: 12px; }
  .tag-body { display: block; }
  .op {
    background: var(--surface); border: 1px solid var(--border);
    border-top: none; padding: 0 16px;
  }
  .op:last-child { border-radius: 0 0 10px 10px; border-bottom: 1px solid var(--border); }
  .op-head {
    display: flex; align-items: center; gap: 12px; padding: 13px 0;
    cursor: pointer; user-select: none;
  }
  .op-head:hover .path { color: var(--text); }
  .method {
    font-family: var(--mono); font-weight: 700; font-size: 12px;
    color: #fff; border-radius: 4px; padding: 4px 8px; min-width: 52px;
    text-align: center; letter-spacing: .5px;
  }
  .m-get { background: var(--get); }
  .m-post { background: var(--post); }
  .m-put { background: var(--put); }
  .m-delete { background: var(--delete); }
  .path { font-family: var(--mono); font-size: 13.5px; color: var(--text-2); flex: 1; }
  .summary { color: var(--text); font-size: 13px; }
  .chev { color: var(--text-2); transition: transform .15s; }
  .op.open .chev { transform: rotate(90deg); }

  .op-body { display: none; padding: 0 0 18px; border-top: 1px dashed var(--border); padding-top: 14px; }
  .op.open .op-body { display: block; }
  .desc { color: var(--text-2); font-size: 13px; margin-bottom: 14px; }
  .op-body h5 {
    font-size: 11px; text-transform: uppercase; letter-spacing: 1px;
    color: var(--text-2); margin: 14px 0 8px;
  }
  .lock-note { font-size: 12px; color: var(--put); margin-left: 6px; }

  table.params { width: 100%; border-collapse: collapse; }
  table.params th, table.params td {
    text-align: left; padding: 7px 10px; font-size: 12.5px;
    border-bottom: 1px solid var(--border);
  }
  table.params th { color: var(--text-2); font-weight: 600; }
  table.params td input {
    width: 100%; background: var(--surface-2); color: var(--text);
    border: 1px solid var(--border); border-radius: 5px;
    padding: 6px 8px; font-family: var(--mono); font-size: 12px; outline: none;
  }
  table.params td input:focus { border-color: var(--get); }
  .req { color: var(--delete); font-weight: 700; }
  .param-desc { color: var(--text-2); font-size: 11.5px; }

  textarea.body {
    width: 100%; min-height: 110px;
    background: var(--surface-2); color: var(--text);
    border: 1px solid var(--border); border-radius: 6px;
    padding: 10px; font-family: var(--mono); font-size: 12.5px;
    resize: vertical; outline: none; white-space: pre;
  }
  textarea.body:focus { border-color: var(--get); }

  .op-actions { display: flex; gap: 10px; margin: 14px 0 4px; align-items: center; flex-wrap: wrap; }
  .spinner {
    width: 14px; height: 14px; border: 2px solid var(--border);
    border-top-color: var(--get); border-radius: 50%;
    animation: spin .8s linear infinite; display: none;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .response { display: none; margin-top: 12px; }
  .status-line {
    font-family: var(--mono); font-size: 13px; padding: 10px 12px;
    border-radius: 6px 6px 0 0; font-weight: 700;
  }
  .status-2xx { background: #173a2b; color: var(--ok); }
  .status-4xx { background: #3a2c17; color: var(--put); }
  .status-5xx, .status-net { background: #3a1717; color: var(--err); }
  .status-meta { display: flex; gap: 14px; color: var(--text-2); font-size: 11.5px; margin-left: auto; font-weight: 400; }
  .resp-body {
    background: #101216; border: 1px solid var(--border); border-top: none;
    border-radius: 0 0 6px 6px; padding: 12px; overflow: auto;
    font-family: var(--mono); font-size: 12.5px; max-height: 420px;
  }
  .resp-headers {
    background: #0d0f12; color: var(--text-2); font-family: var(--mono);
    font-size: 11.5px; padding: 8px 12px; border-left: 1px solid var(--border);
    border-right: 1px solid var(--border); white-space: pre-wrap; word-break: break-all;
  }
  .err-banner {
    background: #3a1717; color: var(--err); border: 1px solid var(--err);
    border-radius: 6px; padding: 10px 12px; margin-top: 12px;
    font-family: var(--mono); font-size: 12.5px; white-space: pre-wrap; word-break: break-word;
  }
  .curl {
    background: #0d0f12; border: 1px solid var(--border); border-radius: 6px;
    color: var(--text-2); font-family: var(--mono); font-size: 11.5px;
    padding: 8px 12px; margin-top: 10px; white-space: pre-wrap; word-break: break-all;
  }
  .k { color: #7dd3fc; } .s { color: #86efac; } .n { color: #fcd34d; }
  .b { color: #f9a8d4; } .p { color: #9aa4b2; }

  /* Modal */
  .modal-back {
    position: fixed; inset: 0; background: rgba(0,0,0,.6); z-index: 50;
    display: none; align-items: center; justify-content: center;
  }
  .modal-back.show { display: flex; }
  .modal {
    width: min(520px, 92vw); background: var(--surface);
    border: 1px solid var(--border); border-radius: 12px; padding: 20px;
  }
  .modal h3 { margin-bottom: 6px; }
  .modal p { color: var(--text-2); font-size: 12.5px; margin-bottom: 14px; }
  .modal input {
    width: 100%; background: var(--surface-2); color: var(--text);
    border: 1px solid var(--border); border-radius: 6px;
    padding: 10px 12px; font-family: var(--mono); font-size: 12.5px; outline: none;
  }
  .modal input:focus { border-color: var(--get); }
  .modal .row { display: flex; gap: 10px; margin-top: 16px; justify-content: flex-end; }
  .token-state { font-size: 12px; margin-top: 10px; color: var(--text-2); }
  .token-state.ok { color: var(--ok); }
  .token-state.bad { color: var(--err); }
  .empty {
    text-align: center; color: var(--text-2); padding: 60px 0;
    display: none;
  }
  .banner {
    background: var(--surface); border: 1px solid var(--border); border-radius: 8px;
    padding: 12px 16px; margin: 14px 24px 0; color: var(--text-2); font-size: 13px;
  }
  .banner code { font-family: var(--mono); color: var(--text); }
  a.plain { color: var(--get); text-decoration: none; }
  a.plain:hover { text-decoration: underline; }
</style>
</head>
<body>

<header>
  <div>
    <div class="logo">Sim<span class="acc">Gate</span> API Docs</div>
    <div class="sub" id="hdr-sub">Loading specification…</div>
  </div>
  <div class="spacer"></div>
  <select class="pill" id="server-select" title="API base URL"></select>
  <span class="pill" id="token-pill">Not authorized</span>
  <button class="btn auth" id="auth-btn">Authorize</button>
</header>

<div class="banner">
  Interactive documentation for the SimGate self-hosted SMS gateway.
  Every example is pre-filled from the live server config (SIM cards, port,
  retention policy, token). Responses use the
  <code>{ success, data, error, timestamp, requestId }</code> envelope.
</div>

<div class="toolbar">
  <input type="text" id="filter" placeholder="Filter operations by path or summary…">
  <button class="btn" id="expand-all">Expand all</button>
  <button class="btn" id="collapse-all">Collapse all</button>
</div>
<div class="info-line" id="op-count"></div>

<div class="layout">
  <nav class="nav" id="nav"></nav>
  <div class="main" id="main"></div>
</div>
<div class="empty" id="empty">No operations match the filter.</div>

<div class="modal-back" id="modal-back">
  <div class="modal">
    <h3>Authorize</h3>
    <p>Paste the access token from <b>SimGate → Settings → Access Token</b>.
       It is sent as <b>Authorization: Bearer &lt;token&gt;</b>.
       The current token from the server config is pre-filled below.</p>
    <input type="password" id="token-input" placeholder="Paste access token…" autocomplete="off">
    <div class="token-state" id="token-state"></div>
    <div class="row">
      <button class="btn" id="modal-close">Close</button>
      <button class="btn danger" id="token-clear" style="display:none">Clear</button>
      <button class="btn primary" id="token-save">Authorize</button>
    </div>
  </div>
</div>

<script>
"use strict";
const $ = (id) => document.getElementById(id);
const state = { spec: null, token: localStorage.getItem("simgate_token") || "", server: "/api" };

const METHOD_COLORS = { get: "#61affe", post: "#49cc90", put: "#fca130", delete: "#f93e3e", patch: "#50e3c2" };
const METHOD_ORDER = ["get", "post", "put", "delete", "patch"];
function escapeHtml(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
const JSON_TOKEN_RE =
  /("(?:[^"\\]|\\.)*")(\s*:)?|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|(true|false|null)|([{}[\],])/g;
function prettyJson(v) {
  const src = JSON.stringify(v, null, 2) || "null";
  let out = "", last = 0, m;
  JSON_TOKEN_RE.lastIndex = 0;
  while ((m = JSON_TOKEN_RE.exec(src)) !== null) {
    out += escapeHtml(src.slice(last, m.index));
    if (m[1] !== undefined) {
      out += m[2] !== undefined
        ? `<span class="k">${escapeHtml(m[1])}</span><span class="p">${escapeHtml(m[2])}</span>`
        : `<span class="s">${escapeHtml(m[1])}</span>`;
    } else if (m[3] !== undefined) {
      out += `<span class="n">${escapeHtml(m[3])}</span>`;
    } else if (m[4] !== undefined) {
      out += `<span class="b">${escapeHtml(m[4])}</span>`;
    } else {
      out += `<span class="p">${escapeHtml(m[5])}</span>`;
    }
    last = m.index + m[0].length;
  }
  return out + escapeHtml(src.slice(last));
}
function stripTrailingSlash(u) { return u.endsWith("/") ? u.slice(0, -1) : u; }

/* ------------------------------------------------------------------ */
/* Spec loading & rendering                                             */
/* ------------------------------------------------------------------ */
async function loadSpec() {
  try {
    const res = await fetch("swagger.json", { headers: { "Accept": "application/json" } });
    if (!res.ok) throw new Error(`Failed to load spec: HTTP ${res.status}`);
    state.spec = await res.json();
  } catch (e) {
    $("hdr-sub").textContent = "Failed to load spec — " + e.message;
    $("main").innerHTML = `<div class="err-banner" style="display:block;margin:24px">` +
      escapeHtml("Could not load swagger.json: " + e.message) + `</div>`;
    return;
  }
  const info = state.spec.info || {};
  const servers = (state.spec.servers || []).map(s => s.url);
  const select = $("server-select");
  select.innerHTML = "";
  for (const s of servers) {
    const opt = document.createElement("option");
    opt.value = s;
    opt.textContent = s;
    select.appendChild(opt);
  }
  if (servers.length) state.server = servers[0];
  select.onchange = () => { state.server = select.value; };
  if (state.spec["x-access-token"] && !state.token) {
    state.token = state.spec["x-access-token"];
    localStorage.setItem("simgate_token", state.token);
  }
  updateAuthUi();
  render();
  $("hdr-sub").textContent = `${info.title || "SimGate API"} · v${info.version || "?"} · ` +
    (info.description ? "" : "");
}

function updateAuthUi() {
  const pill = $("token-pill");
  if (state.token) {
    pill.textContent = "Authorized";
    pill.style.color = "var(--ok)";
    $("auth-btn").textContent = "Authorize (" + maskToken(state.token) + ")";
  } else {
    pill.textContent = "Not authorized";
    pill.style.color = "var(--text-2)";
    $("auth-btn").textContent = "Authorize";
  }
}
function maskToken(t) {
  if (!t) return "";
  if (t.length <= 10) return t.slice(0, 4) + "…";
  return t.slice(0, 6) + "…" + t.slice(-4);
}

function render() {
  const spec = state.spec;
  const tags = (spec.tags || []).map(t => t.name);
  const byTag = {};
  for (const [path, methods] of Object.entries(spec.paths || {})) {
    for (const [method, op] of Object.entries(methods)) {
      if (!METHOD_ORDER.includes(method)) continue;
      const tag = (op.tags && op.tags[0]) || "Default";
      (byTag[tag] = byTag[tag] || []).push({ path, method, op });
    }
  }
  let opTotal = 0;
  const nav = $("nav");
  const main = $("main");
  nav.innerHTML = ""; main.innerHTML = "";
  const ordered = [...tags, ...Object.keys(byTag).filter(t => !tags.includes(t))];
  for (const tag of ordered) {
    const ops = byTag[tag];
    if (!ops) continue;
    opTotal += ops.length;
    nav.insertAdjacentHTML("beforeend",
      `<h4>${escapeHtml(tag)}</h4>` +
      ops.map(o => `<a data-anchor="${escapeHtml(tag)}:${o.method}:${escapeHtml(o.path)}">` +
        `<span class="mini" style="background:${METHOD_COLORS[o.method]}">${o.method.toUpperCase()}</span>` +
        `<span>${escapeHtml(o.op.summary || o.path)}</span></a>`).join(""));

    const tagEl = document.createElement("div");
    tagEl.className = "tag";
    tagEl.id = "tag-" + escapeHtml(tag);
    tagEl.innerHTML = `<div class="tag-head"><h3>${escapeHtml(tag)}</h3>` +
      `<span class="count">${ops.length} operation${ops.length === 1 ? "" : "s"}</span>` +
      `<span style="margin-left:auto">▾</span></div>`;
    const body = document.createElement("div");
    body.className = "tag-body";
    for (const o of ops) body.appendChild(opCard(o));
    tagEl.appendChild(body);
    tagEl.querySelector(".tag-head").onclick = () => {
      const isOpen = body.style.display !== "none";
      body.style.display = isOpen ? "none" : "block";
      tagEl.querySelector(".tag-head span:last-child").textContent = isOpen ? "▸" : "▾";
    };
    main.appendChild(tagEl);
  }
  $("op-count").textContent = `${opTotal} operation${opTotal === 1 ? "" : "s"} in the API`;
  $("empty").style.display = opTotal ? "none" : "block";

  nav.querySelectorAll("a").forEach(a => {
    a.onclick = () => {
      const [tag, method, path] = a.dataset.anchor.split(":");
      const el = document.getElementById("op-" + tag + "-" + method + "-" + path);
      if (el) { el.classList.add("open"); el.scrollIntoView({ behavior: "smooth", block: "start" }); }
    };
  });
}

function opCard({ path, method, op }) {
  const requiresAuth = !(op.security && op.security.length === 0);
  const hasParams = op.parameters && op.parameters.length;
  const hasBody = op.requestBody;
  const card = document.createElement("div");
  card.className = "op";
  const opId = "op-" + (op.tags && op.tags[0] ? op.tags[0] : "Default") + "-" + method + "-" + path;
  card.id = opId;
  card.innerHTML = `
    <div class="op-head">
      <span class="method m-${method}">${method.toUpperCase()}</span>
      <span class="path">${escapeHtml(path)}</span>
      <span class="summary">${escapeHtml(op.summary || "")}</span>
      <span class="chev">▶</span>
    </div>
    <div class="op-body">
      <div class="desc">${escapeHtml(op.description || "")}${requiresAuth ? '<span class="lock-note">🔒 requires token</span>' : '<span class="lock-note">public</span>'}</div>
      ${hasParams ? `<h5>Parameters</h5><table class="params">` +
        `<tr><th>Name</th><th>In</th><th>Type</th><th>Value</th></tr>` +
        op.parameters.map(p => paramRow(p)).join("") + `</table>` : ""}
      ${hasBody ? `<h5>Request body · application/json</h5><textarea class="body" spellcheck="false"></textarea>` : ""}
      <div class="op-actions">
        <button class="btn try-btn">Try it out</button>
        <button class="btn primary execute-btn" style="display:none">Execute</button>
        <button class="btn cancel-btn" style="display:none">Cancel request</button>
        <span class="spinner"></span>
      </div>
      <div class="response">
        <div class="status-line"></div>
        <div class="resp-headers"></div>
        <div class="resp-body"></div>
      </div>
      <div class="err-banner" style="display:none"></div>
      <div class="curl"></div>
    </div>`;

  const head = card.querySelector(".op-head");
  head.onclick = () => {
    card.classList.toggle("open");
    card.querySelector(".chev").textContent = card.classList.contains("open") ? "▼" : "▶";
  };
  card.addEventListener("keydown", e => { if (e.key === "Enter") e.stopPropagation(); });

  if (hasBody) {
    const ex = op.requestBody.content && op.requestBody.content["application/json"];
    const example = ex && (ex.example !== undefined ? ex.example : ex.schema && ex.schema.example);
    card.querySelector(".body").value = example !== undefined
      ? JSON.stringify(example, null, 2) : "";
  }
  setupActions(card, { path, method, op, hasParams });
  return card;
}

function paramRow(p) {
  const schema = p.schema || {};
  const example = p.example !== undefined ? p.example
    : schema.example !== undefined ? schema.example
    : schema.default !== undefined ? schema.default
    : "";
  const type = schema.type || "string";
  const val = typeof example === "object" ? JSON.stringify(example) : example;
  const en = schema.enum ? ` <span class="param-desc">enum: ${escapeHtml(schema.enum.join(", "))}</span>` : "";
  return `<tr>
    <td><b>${escapeHtml(p.name)}</b>${p.required ? ' <span class="req">*</span>' : ""}</td>
    <td class="param-desc">query</td>
    <td class="param-desc">${type}${en}</td>
    <td><input data-param="${escapeHtml(p.name)}" value="${escapeHtml(String(val))}" disabled></td>
  </tr>`;
}

/* ------------------------------------------------------------------ */
/* Try-it-out logic                                                    */
/* ------------------------------------------------------------------ */
function setupActions(card, ctx) {
  const tryBtn = card.querySelector(".try-btn");
  const execBtn = card.querySelector(".execute-btn");
  const cancelBtn = card.querySelector(".cancel-btn");
  const spinner = card.querySelector(".spinner");
  const inputs = card.querySelectorAll("input[data-param]");
  const bodyEl = card.querySelector(".body");
  const response = card.querySelector(".response");
  const errBanner = card.querySelector(".err-banner");
  const curlEl = card.querySelector(".curl");
  const statusLine = card.querySelector(".status-line");
  const headersEl = card.querySelector(".resp-headers");
  const bodyOut = card.querySelector(".resp-body");
  let controller = null;

  const reset = () => {
    if (controller) { controller.abort(); controller = null; }
    spinner.style.display = "none";
    execBtn.style.display = "none";
    cancelBtn.style.display = "none";
    tryBtn.style.display = "inline-block";
    tryBtn.textContent = "Try it out";
    tryBtn.disabled = false;
    inputs.forEach(i => i.disabled = true);
    if (bodyEl) bodyEl.disabled = true;
    response.style.display = "none";
    errBanner.style.display = "none";
  };

  tryBtn.onclick = () => {
    tryBtn.style.display = "none";
    execBtn.style.display = "inline-block";
    cancelBtn.style.display = "inline-block";
    inputs.forEach(i => i.disabled = false);
    if (bodyEl) bodyEl.disabled = false;
    tryBtn.textContent = "Reset";
  };

  cancelBtn.onclick = () => {
    if (controller) controller.abort();
    execBtn.disabled = false;
    cancelBtn.disabled = true;
    spinner.style.display = "none";
  };

  execBtn.onclick = async () => {
    execBtn.disabled = true;
    cancelBtn.disabled = false;
    spinner.style.display = "inline-block";
    errBanner.style.display = "none";
    curlEl.textContent = "";
    response.style.display = "none";

    const base = stripTrailingSlash(state.server) || "";
    const query = inputs.length
      ? "?" + [...inputs].map(i => encodeURIComponent(i.dataset.param) + "=" +
          encodeURIComponent(i.value)).filter(q => !q.endsWith("=")).join("&")
      : "";
    const url = base + ctx.path + query;

    let bodyRaw = null;
    if (bodyEl) {
      const val = bodyEl.value.trim();
      if (val) bodyRaw = val;
    }
    const headers = { "Accept": "application/json" };
    if (bodyRaw) headers["Content-Type"] = "application/json";
    if (state.token) headers["Authorization"] = "Bearer " + state.token;
    const needsAuth = !(ctx.op.security && ctx.op.security.length === 0);

    const sw = performance.now();
    controller = new AbortController();
    let res;
    try {
      res = await fetch(url, {
        method: ctx.method.toUpperCase(),
        headers,
        body: bodyRaw || undefined,
        signal: controller.signal,
      });
    } catch (e) {
      spinner.style.display = "none";
      execBtn.disabled = false;
      cancelBtn.disabled = true;
      const isAbort = e.name === "AbortError";
      const msg = isAbort ? "Request cancelled by the user."
        : (needsAuth && !state.token)
          ? "Network error. Note: this endpoint requires a token — click Authorize first."
          : "Network error: " + e.message;
      statusLine.className = "status-line status-net";
      statusLine.innerHTML = `<span>${isAbort ? "REQUEST CANCELLED" : "NETWORK ERROR"}</span>` +
        `<span class="status-meta"><span>${Math.round(performance.now() - sw)} ms</span></span>`;
      response.style.display = "block";
      errBanner.style.display = "block";
      errBanner.textContent = msg;
      showCurl(curlEl, url, headers, bodyRaw, ctx.method.toUpperCase());
      return;
    }

    const raw = await res.text();
    let parsed = null;
    try { parsed = JSON.parse(raw); } catch (_) { parsed = null; }
    const ms = Math.round(performance.now() - sw);

    spinner.style.display = "none";
    execBtn.disabled = false;
    cancelBtn.disabled = true;
    response.style.display = "block";

    const cls = res.status >= 500 ? "status-5xx" : res.status >= 400 ? "status-4xx" : "status-2xx";
    statusLine.className = "status-line " + cls;
    const flag = parsed && parsed.success === false ? "⚠ API error" : "";
    statusLine.innerHTML =
      `<span>${escapeHtml("HTTP/1.1 " + res.status + " " + res.statusText)} ${flag}</span>` +
      `<span class="status-meta"><span>${ms} ms</span><span>${prettyBytes(raw.length)}</span></span>`;

    const hdrs = [...res.headers.entries()]
      .filter(([k]) => k.toLowerCase() !== "content-length")
      .map(([k, v]) => escapeHtml(k + ": " + v)).join("\n");
    headersEl.textContent = hdrs || "(no headers)";

    if (parsed !== null) {
      bodyOut.innerHTML = prettyJson(parsed);
      const data = parsed.success === true && parsed.data ? parsed.data : null;
      if (parsed.success === false) {
        errBanner.style.display = "block";
        errBanner.textContent = "API error: " + (parsed.error || "unknown error") +
          "\nrequestId: " + (parsed.requestId || "—");
      } else if (data && typeof data === "object" && Object.keys(data).length === 0) {
        errBanner.style.display = "block";
        errBanner.textContent = "Empty data object returned.";
      }
    } else if (res.status >= 400) {
      bodyOut.textContent = raw || "(empty body)";
      errBanner.style.display = "block";
      errBanner.textContent = "HTTP " + res.status + " " + res.statusText;
    } else {
      bodyOut.textContent = raw || "(empty body)";
    }
    showCurl(curlEl, url, headers, bodyRaw, ctx.method.toUpperCase());
    setTimeout(reset, 1);
    execBtn.style.display = "none";
    tryBtn.style.display = "inline-block";
    tryBtn.textContent = "Reset";
  };
}

function prettyBytes(n) {
  if (n < 1024) return n + " B";
  return (n / 1024).toFixed(1) + " KB";
}
function showCurl(curlEl, url, headers, bodyRaw, method) {
  if (curlEl) {
    const args = [`curl -X ${method}`, `"${url}"`];
    for (const [k, v] of Object.entries(headers)) args.push(`-H "${escapeHtml(k)}: ${escapeHtml(v)}"`);
    if (bodyRaw) args.push(`-d '${escapeHtml(bodyRaw)}'`);
    curlEl.textContent = args.join(" \\\n  ");
  }
}

/* ------------------------------------------------------------------ */
/* Authorization modal                                                 */
/* ------------------------------------------------------------------ */
function setupAuthModal() {
  const back = $("modal-back");
  const input = $("token-input");
  const st = $("token-state");
  $("auth-btn").onclick = () => {
    input.value = state.token || "";
    st.textContent = state.token ? "Token loaded from server config / browser storage." : "";
    st.className = "token-state ok";
    back.classList.add("show");
    input.focus();
  };
  $("modal-close").onclick = () => back.classList.remove("show");
  $("token-save").onclick = () => {
    state.token = input.value.trim();
    if (state.token) localStorage.setItem("simgate_token", state.token);
    else localStorage.removeItem("simgate_token");
    st.textContent = state.token ? "Token saved. Requests will use it." : "Token cleared.";
    st.className = "token-state " + (state.token ? "ok" : "bad");
    updateAuthUi();
    setTimeout(() => back.classList.remove("show"), 500);
  };
  $("token-clear").onclick = () => {
    input.value = "";
    st.textContent = "Token cleared.";
    st.className = "token-state bad";
  };
  back.onclick = (e) => { if (e.target === back) back.classList.remove("show"); };
  input.addEventListener("keydown", e => { if (e.key === "Enter") $("token-save").click(); });
}

/* ------------------------------------------------------------------ */
/* Filter & expand                                                     */
/* ------------------------------------------------------------------ */
function setupToolbar() {
  const input = $("filter");
  input.addEventListener("input", () => {
    const q = input.value.trim().toLowerCase();
    document.querySelectorAll(".op").forEach(op => {
      const hay = (op.querySelector(".path").textContent + " " +
        op.querySelector(".summary").textContent).toLowerCase();
      op.style.display = hay.includes(q) ? "" : "none";
    });
    document.querySelectorAll(".tag").forEach(tag => {
      const visible = [...tag.querySelectorAll(".op")].some(op => op.style.display !== "none");
      tag.style.display = visible ? "" : "none";
      if (tag.querySelectorAll(".op").length && !visible) tag.style.display = "none";
    });
    $("empty").style.display = q && !document.querySelectorAll(".op:not([style*='none'])").length
      ? "block" : "none";
  });
  const setAll = (open) => {
    document.querySelectorAll(".op").forEach(op => {
      op.classList.toggle("open", open);
      op.querySelector(".chev").textContent = open ? "▼" : "▶";
    });
  };
  $("expand-all").onclick = () => setAll(true);
  $("collapse-all").onclick = () => setAll(false);
}

setupAuthModal();
setupToolbar();
loadSpec();
</script>
</body>
</html>''';
}
