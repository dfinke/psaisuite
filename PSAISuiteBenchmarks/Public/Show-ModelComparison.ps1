function ConvertTo-ModelComparisonDashboardHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Store,

        [Parameter(Mandatory = $false)]
        [switch]$CanRun
    )

    $storeJson = ($Store | ConvertTo-Json -Depth 64) -replace '</script', '<\/script'
    $canRunValue = if ($CanRun) { 'true' } else { 'false' }

    $template = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>PSAISuite Model Comparison</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f7f8fb;
      --ink: #151b28;
      --muted: #667085;
      --line: #dfe5ee;
      --panel: #ffffff;
      --panel-soft: #f3f8ff;
      --sidebar: #ffffff;
      --nav-active: #edf4ff;
      --accent: #2563eb;
      --accent-dark: #1d4ed8;
      --good: #047857;
      --bad: #b91c1c;
      --warn: #a16207;
      --shadow: 0 6px 24px rgba(24, 32, 47, .08);
    }
    * { box-sizing: border-box; }
    html {
      height: 100%;
      overflow: hidden;
    }
    body {
      margin: 0;
      font-family: Segoe UI, Roboto, Arial, sans-serif;
      background: var(--bg);
      color: var(--ink);
      letter-spacing: 0;
      height: 100%;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }
    body.busy, body.busy * {
      cursor: wait !important;
    }
    header {
      padding: 22px 34px 20px;
      border-bottom: 1px solid var(--line);
      background: var(--panel);
      flex: 0 0 auto;
      z-index: 5;
      display: flex;
      align-items: center;
      gap: 18px;
    }
    h1, h2, h3, p { margin: 0; }
    h1 { font-size: 30px; line-height: 1.1; font-weight: 750; }
    h2 { font-size: 18px; margin-bottom: 12px; font-weight: 650; }
    h3 { font-size: 15px; line-height: 1.25; }
    .page-mark {
      width: 58px;
      height: 58px;
      flex: 0 0 58px;
      display: grid;
      place-items: center;
      border-radius: 15px;
      background:
        radial-gradient(circle at 76% 24%, rgba(255, 255, 255, 0.38), transparent 22px),
        linear-gradient(135deg, #2563eb 0%, #0f766e 100%);
      box-shadow: 0 12px 28px rgba(37, 99, 235, 0.22), inset 0 1px 0 rgba(255, 255, 255, 0.32);
      overflow: hidden;
    }
    .page-mark svg {
      width: 42px;
      height: 42px;
      display: block;
      filter: drop-shadow(0 2px 4px rgba(15, 23, 42, 0.18));
    }
    .header-copy {
      min-width: 0;
    }
    .subtitle {
      color: #5f6b7d;
      font-size: 17px;
      margin-top: 8px;
    }
    label {
      display: block;
      font-size: 12px;
      font-weight: 650;
      color: #39475c;
      margin-bottom: 6px;
    }
    button, input, select, textarea {
      font: inherit;
      letter-spacing: 0;
    }
    textarea, input, select {
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 9px 10px;
      background: #fff;
      color: var(--ink);
    }
    textarea {
      resize: vertical;
      min-height: 82px;
      line-height: 1.4;
    }
    textarea.models {
      min-height: 104px;
      font-family: Consolas, Cascadia Mono, monospace;
      font-size: 13px;
    }
    button {
      border: 0;
      border-radius: 6px;
      min-height: 38px;
      padding: 9px 13px;
      cursor: pointer;
      background: var(--accent);
      color: #fff;
      font-weight: 650;
    }
    button:hover:not(:disabled) { background: var(--accent-dark); }
    button:disabled {
      cursor: not-allowed;
      background: #9aa8bb;
    }
    main {
      display: grid;
      grid-template-columns: 315px minmax(0, 1fr);
      flex: 1 1 auto;
      min-height: 0;
      overflow: hidden;
    }
    aside {
      border-right: 1px solid var(--line);
      background: var(--sidebar);
      padding: 24px 20px;
      overflow: auto;
      min-height: 0;
    }
    .content {
      padding: 28px 34px;
      overflow: hidden;
      min-width: 0;
      width: 100%;
      min-height: 0;
      display: flex;
      flex-direction: column;
    }
    #details {
      width: 100%;
      max-width: 1420px;
      margin: 0 auto;
      min-height: 0;
      flex: 1 1 auto;
      overflow: auto;
      padding-right: 4px;
    }
    .side-nav {
      display: grid;
      gap: 10px;
      margin-bottom: 22px;
    }
    .nav-item {
      width: 100%;
      min-height: 50px;
      border: 0;
      border-radius: 5px;
      padding: 12px 10px;
      background: transparent;
      color: #292f3a;
      text-align: left;
      font-size: 20px;
      font-weight: 500;
    }
    .nav-item.active {
      background: var(--nav-active);
      color: var(--accent);
    }
    .filters {
      display: grid;
      gap: 9px;
      margin: 16px 0 24px;
    }
    .recent-head {
      display: flex;
      justify-content: space-between;
      align-items: center;
      color: #667085;
      font-size: 18px;
      font-weight: 700;
      margin: 12px 0 18px;
    }
    .composer {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      box-shadow: var(--shadow);
      padding: 16px 18px;
      margin: 0 auto 28px;
      max-width: 1420px;
      width: 100%;
      flex: 0 0 auto;
    }
    .composer-grid {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(260px, 360px);
      gap: 12px;
      align-items: end;
    }
    .composer-actions {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      margin-top: 12px;
    }
    .status {
      min-height: 20px;
      font-size: 13px;
      color: var(--muted);
    }
    .status.error { color: var(--bad); }
    .run-list {
      display: grid;
      gap: 4px;
    }
    .run-button {
      width: 100%;
      border: 0;
      background: transparent;
      color: var(--ink);
      border-radius: 5px;
      padding: 10px;
      text-align: left;
      cursor: pointer;
      min-height: auto;
      font-weight: 400;
    }
    .run-button:hover { background: #f6f8fb; }
    .run-button.active {
      background: var(--nav-active);
      box-shadow: none;
    }
    .recent-title {
      display: block;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      font-size: 16px;
      color: #2b3038;
    }
    .recent-date {
      display: block;
      margin-top: 2px;
      color: #667085;
      font-size: 14px;
    }
    .run-meta {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      color: var(--muted);
      font-size: 12px;
      margin-top: 6px;
    }
    .pill {
      display: inline-flex;
      align-items: center;
      min-height: 22px;
      padding: 2px 7px;
      border-radius: 999px;
      background: #e4edf8;
      color: #344256;
      font-size: 12px;
      white-space: nowrap;
    }
    .query-group {
      background: rgba(255, 255, 255, .72);
      border: 1px solid #e6ebf2;
      border-radius: 8px;
      box-shadow: 0 3px 14px rgba(24, 32, 47, .05);
      padding: 20px;
      margin: 0 0 34px;
      width: 100%;
    }
    .query-group.selected {
      border-color: #ccd8ea;
      box-shadow: 0 5px 20px rgba(24, 32, 47, .08);
    }
    .query-head {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 16px;
      margin-bottom: 20px;
    }
    .query-title {
      display: inline-block;
      max-width: min(760px, 100%);
      background: #f2f4f7;
      border-radius: 5px;
      padding: 10px 12px;
      color: #202631;
      font-size: 20px;
      line-height: 1.25;
      white-space: pre-wrap;
    }
    .query-date {
      color: #667085;
      font-size: 16px;
      margin-top: 8px;
    }
    .trash {
      color: #667085;
      font-size: 22px;
      line-height: 1;
      padding: 4px;
      user-select: none;
    }
    .history-list {
      display: grid;
      gap: 28px;
      width: 100%;
    }
    .responses {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(min(280px, 100%), 1fr));
      gap: 22px;
      align-items: stretch;
      width: 100%;
    }
    .card {
      background: var(--panel);
      border: 1px solid #cfd9e8;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 7px 22px rgba(24, 32, 47, .09);
      display: flex;
      flex-direction: column;
      min-height: 390px;
      min-width: 0;
    }
    .card.pending {
      border-color: #b8c7db;
    }
    .card-head {
      padding: 12px;
      border-bottom: 1px solid var(--line);
      display: grid;
      gap: 5px;
      background: #fbfcfe;
      min-height: 135px;
    }
    .model-title {
      font-size: 20px;
      font-weight: 750;
      color: #1e2430;
    }
    .provider {
      color: #667085;
      font-size: 16px;
    }
    .latency {
      color: #667085;
      font-size: 16px;
      margin-top: 8px;
    }
    .card-body {
      padding: 12px;
      white-space: pre-wrap;
      line-height: 1.45;
      font-family: Segoe UI, Roboto, Arial, sans-serif;
      font-size: 16px;
      max-height: 520px;
      overflow: auto;
      background: var(--panel-soft);
      border-bottom: 1px solid var(--line);
      flex: 1 1 auto;
    }
    .error-text {
      color: var(--bad);
      font-family: Segoe UI, Roboto, Arial, sans-serif;
    }
    .pending-body {
      display: flex;
      align-items: center;
      gap: 10px;
      min-height: 84px;
      color: var(--muted);
      font-family: Segoe UI, Roboto, Arial, sans-serif;
    }
    .spinner {
      width: 18px;
      height: 18px;
      border: 3px solid #d6dfeb;
      border-top-color: var(--accent);
      border-radius: 50%;
      animation: spin .8s linear infinite;
      flex: 0 0 auto;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    .ratings {
      display: grid;
      gap: 9px;
      padding: 16px 14px 18px;
      background: #fbfcfe;
    }
    .rating-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      color: #4b5565;
      font-weight: 700;
      margin-bottom: 4px;
    }
    .score-badge {
      border-radius: 999px;
      padding: 8px 14px;
      background: #eef2f6;
      color: #667085;
      font-weight: 750;
      white-space: nowrap;
    }
    .score-badge.good { background: #e7f7ef; color: var(--good); }
    .score-badge.warn { background: #fff8d9; color: #a46b00; }
    .score-badge.bad { background: #fdeceb; color: var(--bad); }
    .rating-row {
      display: grid;
      grid-template-columns: minmax(95px, 1fr) 82px;
      align-items: center;
      gap: 10px;
      color: #5f6b7d;
      font-size: 16px;
    }
    .rating-icons {
      display: flex;
      justify-content: flex-end;
      gap: 8px;
      font-weight: 750;
    }
    .rating-button {
      display: inline-grid;
      place-items: center;
      min-width: 36px;
      min-height: 28px;
      padding: 0 7px;
      border: 1px solid #cbd5e1;
      border-radius: 5px;
      background: #f8fafc;
      color: #475569;
      font-size: 16px;
      font-weight: 750;
      line-height: 1;
    }
    .rating-button:hover:not(:disabled) {
      background: #e8eef7;
      border-color: #94a3b8;
      color: #1f2937;
    }
    .rating-button:disabled {
      background: #f8fafc;
      border-color: #e2e8f0;
      color: #94a3b8;
      cursor: default;
      opacity: .75;
    }
    .rating-button.up.selected { color: #047857; background: #e8f7ef; border-color: #86efac; }
    .rating-button.down.selected { color: #b91c1c; background: #fdecec; border-color: #fca5a5; }
    .summary {
      margin-top: 16px;
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      overflow: auto;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      min-width: 720px;
    }
    th, td {
      padding: 9px 10px;
      border-bottom: 1px solid var(--line);
      text-align: left;
      font-size: 13px;
      vertical-align: top;
    }
    th {
      background: #f8fafc;
      color: #344256;
      font-weight: 600;
    }
    tr:last-child td { border-bottom: 0; }
    .empty {
      padding: 28px;
      color: var(--muted);
      background: var(--panel);
      border: 1px dashed var(--line);
      border-radius: 8px;
    }
    @media (max-width: 980px) {
      .composer-grid { grid-template-columns: 1fr; }
    }
    @media (max-width: 860px) {
      header { padding: 20px; }
      main {
        grid-template-columns: 1fr;
        grid-template-rows: auto minmax(0, 1fr);
      }
      aside { border-right: 0; border-bottom: 1px solid var(--line); max-height: 30vh; }
      .nav-item { font-size: 17px; min-height: 42px; }
      .content { padding: 18px; }
    }
  </style>
</head>
<body>
  <header>
    <span class="page-mark" aria-hidden="true">
      <svg viewBox="0 0 64 64" focusable="false">
        <path d="M20 25C26 17 38 17 44 25M20 39C26 47 38 47 44 39" fill="none" stroke="rgba(255,255,255,0.58)" stroke-width="4" stroke-linecap="round" />
        <rect x="12" y="18" width="14" height="28" rx="5" fill="rgba(255,255,255,0.88)" />
        <rect x="25" y="11" width="14" height="42" rx="5" fill="#ffffff" />
        <rect x="38" y="21" width="14" height="22" rx="5" fill="rgba(255,255,255,0.82)" />
        <circle cx="32" cy="32" r="4" fill="#fbbf24" />
      </svg>
    </span>
    <div class="header-copy">
      <h1>AI Model Comparison</h1>
      <p class="subtitle">Compare responses from different LLM models side by side. Rate responses across different categories and track model performance.</p>
    </div>
  </header>
  <main>
    <aside>
      <nav class="side-nav" aria-label="Dashboard sections">
        <button class="nav-item" type="button" data-view="compare">Compare Models</button>
        <button class="nav-item active" type="button" data-view="history">Full History</button>
        <button class="nav-item" type="button" data-view="ratings">Ratings Summary</button>
      </nav>
      <div class="filters">
      <input id="search" type="search" placeholder="Search prompts, models, responses">
      <select id="kind">
        <option value="">All runs</option>
        <option value="comparison">Comparisons</option>
        <option value="benchmark">Benchmarks</option>
      </select>
      </div>
      <div class="recent-head">
        <span>Recent Queries</span>
        <span aria-hidden="true">⌃</span>
      </div>
      <div id="runList" class="run-list"></div>
    </aside>
    <section class="content">
      <section id="composer" class="composer">
        <div class="composer-grid">
          <div>
            <label for="prompt">Prompt</label>
            <textarea id="prompt" placeholder="Ask the models something..."></textarea>
          </div>
          <div>
            <label for="models">Models</label>
            <textarea id="models" class="models" spellcheck="false">openai:gpt-4o-mini
anthropic:claude-sonnet-4-6
deepseek:deepseek-v4-flash
google:gemini-3.1-flash-lite</textarea>
          </div>
        </div>
        <div class="composer-actions">
          <div id="status" class="status"></div>
          <button id="run" type="button">Run Comparison</button>
        </div>
      </section>
      <div id="details"></div>
    </section>
  </main>
  <script id="store-data" type="application/json">__MODEL_COMPARISON_DATA__</script>
  <script>
    let store = JSON.parse(document.getElementById('store-data').textContent || '{}');
    const canRun = __CAN_RUN__;
    let categories = store.ratingCategories || [];
    let activeRunId = (store.runs && store.runs[0] && store.runs[0].id) || '';

    const state = {
      search: '',
      kind: '',
      busy: false,
      ratingBusy: false
    };

    const els = {
      search: document.getElementById('search'),
      kind: document.getElementById('kind'),
      runList: document.getElementById('runList'),
      details: document.getElementById('details'),
      composer: document.getElementById('composer'),
      prompt: document.getElementById('prompt'),
      models: document.getElementById('models'),
      run: document.getElementById('run'),
      status: document.getElementById('status'),
      navItems: document.querySelectorAll('.nav-item')
    };

    function esc(value) {
      return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
    }

    function setStatus(text, isError = false) {
      els.status.textContent = text || '';
      els.status.classList.toggle('error', Boolean(isError));
    }

    function dateText(value) {
      if (!value) return '';
      const date = new Date(value);
      if (Number.isNaN(date.getTime())) return value;
      return date.toLocaleString();
    }

    function shortText(value, maxLength = 28) {
      const text = String(value || '').replace(/\s+/g, ' ').trim();
      if (text.length <= maxLength) return text;
      return `${text.slice(0, Math.max(0, maxLength - 3))}...`;
    }

    function runElementId(runId) {
      return `run-${String(runId || '').replace(/[^a-zA-Z0-9_-]/g, '-')}`;
    }

    function scrollResultsTo(element, block = 'start') {
      if (!element) return;
      const detailsRect = els.details.getBoundingClientRect();
      const elementRect = element.getBoundingClientRect();
      let top = els.details.scrollTop + elementRect.top - detailsRect.top;
      if (block === 'center') {
        top -= Math.max(0, (els.details.clientHeight - elementRect.height) / 2);
      }
      els.details.scrollTo({ top: Math.max(0, top - 8), behavior: 'smooth' });
    }

    function parseModels() {
      return els.models.value.split(/\s+/).map(model => model.trim()).filter(Boolean);
    }

    function ratingClass(value) {
      if (value === true) return 'good';
      if (value === false) return 'bad';
      return '';
    }

    function ratingText(value) {
      if (value === true) return '+';
      if (value === false) return '-';
      return ' ';
    }

    function updateRunButton() {
      const isBusy = state.busy || state.ratingBusy;
      els.run.disabled = isBusy || !canRun;
      document.body.classList.toggle('busy', isBusy);
    }

    function makePendingRun(prompt, models) {
      const now = new Date().toISOString();
      return {
        id: `pending-${Date.now()}`,
        kind: 'comparison',
        title: null,
        prompt,
        createdAt: now,
        models,
        tags: [],
        category: null,
        benchmarkId: null,
        expectedAnswer: null,
        scoringType: null,
        notes: null,
        responses: models.map(model => {
          const parts = model.match(/^([^:]+):(.+)$/);
          return {
            id: `pending-${model}-${Math.random().toString(16).slice(2)}`,
            model,
            provider: parts ? parts[1] : '',
            modelName: parts ? parts[2] : model,
            response: 'Queued',
            error: null,
            status: 'Pending',
            elapsedMilliseconds: null,
            elapsedTime: null,
            rawScore: null,
            passed: null,
            needsReview: false,
            scoringType: null,
            notes: null,
            userNotes: null,
            ratings: {}
          };
        })
      };
    }

    function findRun(runId) {
      return (store.runs || []).find(run => run.id === runId);
    }

    function findResponse(runId, responseId) {
      const run = findRun(runId);
      if (!run) return null;
      return (run.responses || []).find(response => response.id === responseId) || null;
    }

    function replaceRun(run) {
      store.runs = store.runs || [];
      const index = store.runs.findIndex(item => item.id === run.id);
      if (index >= 0) {
        store.runs[index] = run;
      } else {
        store.runs.unshift(run);
      }
    }

    function replaceResponse(runId, response, index) {
      const run = findRun(runId);
      if (!run) return;
      run.responses = run.responses || [];
      const responseIndex = run.responses.findIndex(item => item.id === response.id);
      if (responseIndex >= 0) {
        run.responses[responseIndex] = response;
      } else if (Number.isInteger(index) && index >= 0 && index < run.responses.length) {
        run.responses[index] = response;
      } else {
        run.responses.push(response);
      }
    }

    function handleProgressEvent(event) {
      if (event.type === 'started') {
        const pendingIndex = store.runs.findIndex(run => String(run.id).startsWith('pending-'));
        if (pendingIndex >= 0) {
          store.runs[pendingIndex] = event.run;
        } else {
          replaceRun(event.run);
        }
        activeRunId = event.run.id;
        setStatus(`Running ${event.total} model${event.total === 1 ? '' : 's'}...`);
        render();
      } else if (event.type === 'response') {
        replaceResponse(event.runId, event.response, event.index);
        setStatus(`Completed ${event.completed}/${event.total}: ${event.response.model}`);
        render();
      } else if (event.type === 'complete') {
        store = event.store;
        activeRunId = event.run.id;
        setStatus(`Comparison complete. ${event.completed}/${event.total} finished.`);
        render();
      } else if (event.type === 'error') {
        setStatus(event.error || 'Comparison failed.', true);
      }
    }

    function runMatches(run) {
      if (state.kind && run.kind !== state.kind) return false;
      if (!state.search) return true;
      const text = [
        run.id,
        run.kind,
        run.title,
        run.prompt,
        run.category,
        run.benchmarkId,
        run.expectedAnswer,
        run.notes,
        ...(run.tags || []),
        ...(run.models || []),
        ...((run.responses || []).flatMap(response => [
          response.id,
          response.model,
          response.provider,
          response.modelName,
          response.response,
          response.error,
          response.notes,
          response.userNotes
        ]))
      ].filter(Boolean).join('\n').toLowerCase();
      return text.includes(state.search.toLowerCase());
    }

    function filteredRuns() {
      return (store.runs || [])
        .filter(runMatches)
        .sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
    }

    function responseStatus(response) {
      const status = response.status || (response.error ? 'Failed' : 'Succeeded');
      const latency = response.elapsedMilliseconds == null ? '' : `${response.elapsedMilliseconds} ms`;
      return [status, latency].filter(Boolean).join(' / ');
    }

    function responseDisplayStatus(response) {
      const status = response.status || (response.error ? 'Failed' : 'Succeeded');
      if (response.elapsedMilliseconds != null) {
        const latency = `${response.elapsedMilliseconds}ms`;
        return status === 'Succeeded' ? `Latency: ${latency}` : `${status} / ${latency}`;
      }
      return status;
    }

    function isPendingResponse(response) {
      return response.status === 'Pending' || response.status === 'Running';
    }

    function renderRunList(runs) {
      if (!runs.length) {
        els.runList.innerHTML = '<div class="empty">No runs yet.</div>';
        return;
      }

      if (!runs.some(run => run.id === activeRunId)) {
        activeRunId = runs[0].id;
      }

      els.runList.innerHTML = runs.map(run => {
        const label = run.title || run.benchmarkId || run.prompt || run.id;
        return `
          <button type="button" class="run-button ${run.id === activeRunId ? 'active' : ''}" data-run-id="${esc(run.id)}">
            <span class="recent-title">${esc(shortText(label, 29))}</span>
            <span class="recent-date">${esc(dateText(run.createdAt))}</span>
          </button>
        `;
      }).join('');

      els.runList.querySelectorAll('.run-button').forEach(button => {
        button.addEventListener('click', () => {
          activeRunId = button.getAttribute('data-run-id');
          render();
          scrollResultsTo(document.getElementById(runElementId(activeRunId)));
        });
      });
    }

    function ratingStats(response) {
      return ratingStatsForRatings(response.ratings || {});
    }

    function ratingStatsForRatings(ratings) {
      const values = categories.map(category => ratings[category.key]).filter(value => value === true || value === false);
      if (!values.length) {
        return { label: 'Unrated', className: '' };
      }
      const positive = values.filter(Boolean).length;
      const percent = Math.round((positive / values.length) * 100);
      return {
        label: `${percent}% positive`,
        className: percent >= 80 ? 'good' : percent >= 50 ? 'warn' : 'bad'
      };
    }

    function renderRatings(response, runId) {
      const ratings = response.ratings || {};
      const stats = ratingStats(response);
      const disabled = !canRun || state.busy || state.ratingBusy || isPendingResponse(response);
      return `
        <div class="ratings">
          <div class="rating-head">
            <span>Rate this response:</span>
            <span class="score-badge ${stats.className}">${esc(stats.label)}</span>
          </div>
          ${categories.map(category => {
            const value = ratings[category.key];
            return `
              <div class="rating-row" title="${esc(category.description)}">
                <span>${esc(category.label)}</span>
                <span class="rating-icons">
                  <button type="button" class="rating-button up ${value === true ? 'selected' : ''}" data-run-id="${esc(runId)}" data-response-id="${esc(response.id)}" data-category="${esc(category.key)}" data-value="Up" aria-label="Rate ${esc(category.label)} thumbs up" ${disabled ? 'disabled' : ''}>👍🏼</button>
                  <button type="button" class="rating-button down ${value === false ? 'selected' : ''}" data-run-id="${esc(runId)}" data-response-id="${esc(response.id)}" data-category="${esc(category.key)}" data-value="Down" aria-label="Rate ${esc(category.label)} thumbs down" ${disabled ? 'disabled' : ''}>👎🏼</button>
                </span>
              </div>
            `;
          }).join('')}
        </div>
      `;
    }

    function renderResponses(run) {
      return `
        <div class="responses">
          ${(run.responses || []).map(response => `
            <article class="card ${isPendingResponse(response) ? 'pending' : ''}">
              <div class="card-head">
                <h3 class="model-title">${esc(response.modelName || response.model)}</h3>
                <div class="provider">${esc(response.provider || '')}</div>
                <div class="latency">${esc(responseDisplayStatus(response))}</div>
                ${response.scoringType ? `<div class="run-meta"><span>${esc(response.scoringType)}</span><span>${response.passed ? 'passed' : 'not passed'}</span>${response.needsReview ? '<span>needs review</span>' : ''}</div>` : ''}
              </div>
              <div class="card-body ${response.error ? 'error-text' : ''}">${
                isPendingResponse(response)
                  ? `<div class="pending-body"><span class="spinner"></span><span>${esc(response.response || 'Waiting for response...')}</span></div>`
                  : esc(response.error || response.response || '')
              }</div>
              ${renderRatings(response, run.id)}
            </article>
          `).join('')}
        </div>
      `;
    }

    function renderSummary(runs) {
      const rows = [];
      for (const run of runs) {
        for (const response of (run.responses || [])) {
          rows.push({ run, response });
        }
      }

      if (!rows.length) return '';

      return `
        <section class="summary">
          <table>
            <thead>
              <tr>
                <th>Run</th>
                <th>Model</th>
                <th>Status</th>
                <th>Latency</th>
                <th>Score</th>
                <th>Review</th>
              </tr>
            </thead>
            <tbody>
              ${rows.map(({ run, response }) => `
                <tr>
                  <td>${esc(run.title || run.benchmarkId || (run.prompt || '').slice(0, 80))}</td>
                  <td>${esc(response.model || response.modelName)}</td>
                  <td>${esc(response.status || '')}</td>
                  <td>${response.elapsedMilliseconds == null ? '' : esc(response.elapsedMilliseconds + ' ms')}</td>
                  <td>${response.rawScore == null ? '' : esc(response.rawScore)}</td>
                  <td>${response.needsReview ? 'yes' : ''}</td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        </section>
      `;
    }

    function renderRunGroup(run) {
      const tags = (run.tags || []).map(tag => `<span class="pill">${esc(tag)}</span>`).join('');
      return `
        <section id="${esc(runElementId(run.id))}" class="query-group ${run.id === activeRunId ? 'selected' : ''}">
          <div class="query-head">
            <div>
              <div class="query-title">${esc(run.prompt || run.title || run.benchmarkId || '')}</div>
              <div class="query-date">${esc(dateText(run.createdAt))}</div>
              <div class="run-meta">
                <span>${esc(run.kind || 'comparison')}</span>
                ${run.category ? `<span>${esc(run.category)}</span>` : ''}
                ${run.benchmarkId ? `<span>${esc(run.benchmarkId)}</span>` : ''}
                ${tags}
              </div>
            </div>
            <span class="trash" title="Delete support coming soon" aria-hidden="true">⌫</span>
          </div>
          ${renderResponses(run)}
        </section>
      `;
    }

    function renderDetails(runs) {
      if (!runs.length) {
        els.details.innerHTML = '<div class="empty">No runs yet. Enter a prompt, list one or more models, and run a comparison.</div>';
        return;
      }

      els.details.innerHTML = `
        <div class="history-list">
          ${runs.map(renderRunGroup).join('')}
        </div>
      `;
    }

    function render() {
      categories = store.ratingCategories || [];
      const runs = filteredRuns();
      renderRunList(runs);
      renderDetails(runs);
      updateRunButton();
    }

    async function refreshStore() {
      if (!canRun) {
        render();
        return;
      }
      const response = await fetch('/api/store', { cache: 'no-store' });
      if (!response.ok) throw new Error('Unable to load comparison store.');
      store = await response.json();
      render();
    }

    async function rateResponse(runId, responseId, category, value) {
      if (!canRun || state.busy || state.ratingBusy) return;
      if (!categories.some(item => item.key === category)) return;

      const response = findResponse(runId, responseId);
      if (!response || isPendingResponse(response)) return;

      response.ratings = response.ratings || {};
      const previousRatings = { ...response.ratings };
      const requestedBoolean = value === 'Up';
      const requestValue = response.ratings[category] === requestedBoolean ? 'Clear' : value;
      response.ratings[category] = requestValue === 'Clear' ? null : requestedBoolean;

      state.ratingBusy = true;
      setStatus('Saving rating...');
      render();

      try {
        const result = await fetch('/api/rating', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ runId, responseId, category, value: requestValue })
        });
        if (!result.ok) {
          const text = await result.text();
          throw new Error(text || 'Unable to save rating.');
        }

        const payload = await result.json();
        if (payload.store) {
          store = payload.store;
        } else if (payload.response) {
          replaceResponse(runId, payload.response);
        }
        setStatus('Rating saved.');
      } catch (error) {
        const currentResponse = findResponse(runId, responseId);
        if (currentResponse) {
          currentResponse.ratings = previousRatings;
        }
        setStatus(error instanceof Error ? error.message : String(error), true);
      } finally {
        state.ratingBusy = false;
        render();
      }
    }

    async function runComparison() {
      if (!canRun || state.busy || state.ratingBusy) return;

      const prompt = els.prompt.value.trim();
      const models = parseModels();
      if (!prompt) {
        setStatus('Prompt is required.', true);
        els.prompt.focus();
        return;
      }
      if (!models.length) {
        setStatus('At least one model is required.', true);
        els.models.focus();
        return;
      }

      state.busy = true;
      updateRunButton();
      setStatus(`Starting ${models.length} model${models.length === 1 ? '' : 's'}...`);

      const pendingRun = makePendingRun(prompt, models);
      store.runs = store.runs || [];
      store.runs.unshift(pendingRun);
      activeRunId = pendingRun.id;
      render();

      try {
        const response = await fetch('/api/compare', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ prompt, models })
        });
        if (!response.ok) {
          const text = await response.text();
          throw new Error(text || 'Comparison failed.');
        }

        const reader = response.body?.getReader();
        if (!reader) {
          throw new Error('This browser cannot read streamed comparison progress.');
        }

        const decoder = new TextDecoder();
        let buffer = '';

        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split('\n');
          buffer = lines.pop() || '';
          for (const line of lines) {
            if (!line.trim()) continue;
            handleProgressEvent(JSON.parse(line));
          }
        }

        buffer += decoder.decode();
        if (buffer.trim()) {
          handleProgressEvent(JSON.parse(buffer));
        }
      } catch (error) {
        setStatus(error instanceof Error ? error.message : String(error), true);
      } finally {
        state.busy = false;
        updateRunButton();
        render();
      }
    }

    els.search.addEventListener('input', event => {
      state.search = event.target.value.trim();
      render();
    });
    els.kind.addEventListener('change', event => {
      state.kind = event.target.value;
      render();
    });
    els.run.addEventListener('click', runComparison);
    els.details.addEventListener('click', event => {
      const button = event.target.closest('.rating-button');
      if (!button || button.disabled) return;
      rateResponse(
        button.getAttribute('data-run-id'),
        button.getAttribute('data-response-id'),
        button.getAttribute('data-category'),
        button.getAttribute('data-value')
      );
    });
    els.navItems.forEach(button => {
      button.addEventListener('click', () => {
        els.navItems.forEach(item => item.classList.toggle('active', item === button));
        const view = button.getAttribute('data-view');
        if (view === 'compare') {
          els.prompt.focus();
        } else if (view === 'history') {
          scrollResultsTo(document.querySelector('.query-group'));
        } else if (view === 'ratings') {
          setStatus('Ratings are shown below each response card.');
          scrollResultsTo(document.querySelector('.ratings'), 'center');
        }
      });
    });
    for (const input of [els.prompt, els.models]) {
      input.addEventListener('keydown', event => {
        if (event.ctrlKey && event.key === 'Enter') {
          event.preventDefault();
          runComparison();
        }
      });
    }

    if (!canRun) {
      els.run.disabled = true;
      setStatus('Static dashboard.');
    }

    refreshStore().catch(error => {
      setStatus(error instanceof Error ? error.message : String(error), true);
      render();
    });
  </script>
</body>
</html>
'@

    return $template.Replace('__MODEL_COMPARISON_DATA__', $storeJson).Replace('__CAN_RUN__', $canRunValue)
}

function Get-ModelComparisonDashboardPort {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Port
    )

    $candidates = if ($Port -gt 0) {
        @($Port)
    }
    else {
        49321..49420
    }

    foreach ($candidate in $candidates) {
        $listener = $null
        try {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $candidate)
            $listener.Start()
            return $candidate
        }
        catch {
            if ($Port -gt 0) {
                throw "Port $Port is not available."
            }
        }
        finally {
            if ($listener) {
                $listener.Stop()
            }
        }
    }

    throw 'No available localhost port was found for the model comparison dashboard.'
}

function Start-ModelComparisonDashboardServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Html,

        [Parameter(Mandatory = $true)]
        [string]$StorePath,

        [Parameter(Mandatory = $true)]
        [int]$Port
    )

    $benchmarkRoot = Split-Path -Path $PSScriptRoot -Parent
    $repoRoot = Split-Path -Path $benchmarkRoot -Parent
    $benchmarkModulePath = Join-Path -Path $benchmarkRoot -ChildPath 'PSAISuiteBenchmarks.psd1'
    $suiteModulePath = Join-Path -Path $repoRoot -ChildPath 'PSAISuite.psd1'
    $prefix = "http://127.0.0.1:$Port/"

    $job = Start-Job -Name "PSAISuiteModelComparison-$Port" -ScriptBlock {
        param(
            [string]$Prefix,
            [string]$Html,
            [string]$StorePath,
            [string]$BenchmarkModulePath,
            [string]$SuiteModulePath
        )

        if (Test-Path -LiteralPath $SuiteModulePath) {
            Import-Module $SuiteModulePath -Force
        }
        else {
            Import-Module PSAISuite -Force -ErrorAction SilentlyContinue
        }
        Import-Module $BenchmarkModulePath -Force

        function Send-ModelComparisonResponse {
            param(
                [Parameter(Mandatory = $true)]
                [System.Net.HttpListenerContext]$Context,

                [Parameter(Mandatory = $true)]
                [string]$Body,

                [Parameter(Mandatory = $false)]
                [string]$ContentType = 'text/plain; charset=utf-8',

                [Parameter(Mandatory = $false)]
                [int]$StatusCode = 200
            )

            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
            $Context.Response.StatusCode = $StatusCode
            $Context.Response.ContentType = $ContentType
            $Context.Response.ContentLength64 = $bytes.Length
            $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        }

        function Send-ModelComparisonJson {
            param(
                [Parameter(Mandatory = $true)]
                [System.Net.HttpListenerContext]$Context,

                [Parameter(Mandatory = $true)]
                [object]$Value,

                [Parameter(Mandatory = $false)]
                [int]$StatusCode = 200
            )

            $json = $Value | ConvertTo-Json -Depth 64
            Send-ModelComparisonResponse -Context $Context -Body $json -ContentType 'application/json; charset=utf-8' -StatusCode $StatusCode
        }

        function New-DashboardModelComparisonRatings {
            [PSCustomObject][ordered]@{
                accuracy     = $null
                relevance    = $null
                completeness = $null
                concise      = $null
                unbiased     = $null
            }
        }

        function Split-DashboardModelComparisonModel {
            param([Parameter(Mandatory = $true)][string]$Model)

            if ($Model -match '^([^:]+):(.+)$') {
                [PSCustomObject]@{
                    Provider  = $Matches[1]
                    ModelName = $Matches[2]
                }
            }
            else {
                [PSCustomObject]@{
                    Provider  = ''
                    ModelName = $Model
                }
            }
        }

        function New-DashboardPendingComparisonResponse {
            param(
                [Parameter(Mandatory = $true)][string]$Model,
                [Parameter(Mandatory = $false)][string]$Status = 'Pending'
            )

            $modelParts = Split-DashboardModelComparisonModel -Model $Model
            [PSCustomObject]@{
                id                  = [guid]::NewGuid().ToString()
                model               = $Model
                provider            = $modelParts.Provider
                modelName           = $modelParts.ModelName
                response            = if ($Status -eq 'Running') { 'Running...' } else { 'Queued' }
                error               = $null
                status              = $Status
                elapsedMilliseconds = $null
                elapsedTime         = $null
                rawScore            = $null
                passed              = $null
                needsReview         = $false
                scoringType         = $null
                notes               = $null
                userNotes           = $null
                ratings             = New-DashboardModelComparisonRatings
            }
        }

        function Write-DashboardModelComparisonStore {
            param([Parameter(Mandatory = $true)][object]$Store)

            $Store.updatedAt = (Get-Date).ToUniversalTime().ToString('o')
            $Store | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $StorePath -Encoding UTF8
        }

        function Save-DashboardModelComparisonRun {
            param([Parameter(Mandatory = $true)][object]$Run)

            $store = Get-ModelComparison -StorePath $StorePath -Raw
            $runs = @($store.runs)
            $found = $false
            for ($index = 0; $index -lt $runs.Count; $index++) {
                if ($runs[$index].id -eq $Run.id) {
                    $runs[$index] = $Run
                    $found = $true
                    break
                }
            }

            if (-not $found) {
                $newRuns = [System.Collections.Generic.List[object]]::new()
                $newRuns.Add($Run)
                foreach ($existingRun in $runs) {
                    $newRuns.Add($existingRun)
                }
                $runs = @($newRuns)
            }

            $store.runs = @($runs)
            Write-DashboardModelComparisonStore -Store $store
            return $store
        }

        function Write-DashboardModelComparisonEvent {
            param(
                [Parameter(Mandatory = $true)]
                [System.IO.StreamWriter]$Writer,

                [Parameter(Mandatory = $true)]
                [object]$Value
            )

            $Writer.WriteLine(($Value | ConvertTo-Json -Depth 64 -Compress))
            $Writer.Flush()
        }

        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add($Prefix)
        $listener.Start()
        $shouldStop = $false

        try {
            while ($listener.IsListening -and -not $shouldStop) {
                $context = $listener.GetContext()
                try {
                    $request = $context.Request
                    $path = $request.Url.AbsolutePath.TrimEnd('/')
                    if ([string]::IsNullOrWhiteSpace($path)) {
                        $path = '/'
                    }

                    if ($request.HttpMethod -eq 'OPTIONS') {
                        Send-ModelComparisonResponse -Context $context -Body ''
                    }
                    elseif ($request.HttpMethod -eq 'GET' -and $path -eq '/') {
                        Send-ModelComparisonResponse -Context $context -Body $Html -ContentType 'text/html; charset=utf-8'
                    }
                    elseif ($request.HttpMethod -eq 'GET' -and $path -eq '/api/health') {
                        Send-ModelComparisonJson -Context $context -Value @{ status = 'ok' }
                    }
                    elseif ($request.HttpMethod -eq 'GET' -and $path -eq '/api/store') {
                        Send-ModelComparisonJson -Context $context -Value (Get-ModelComparison -StorePath $StorePath -Raw)
                    }
                    elseif ($request.HttpMethod -eq 'POST' -and $path -eq '/api/shutdown') {
                        Send-ModelComparisonJson -Context $context -Value @{ status = 'stopping' }
                        $shouldStop = $true
                    }
                    elseif ($request.HttpMethod -eq 'POST' -and $path -eq '/api/rating') {
                        $reader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
                        try {
                            $body = $reader.ReadToEnd()
                        }
                        finally {
                            $reader.Dispose()
                        }

                        $payload = if ([string]::IsNullOrWhiteSpace($body)) { @{} } else { $body | ConvertFrom-Json }
                        $runId = [string]$payload.runId
                        $responseId = [string]$payload.responseId
                        $category = ([string]$payload.category).ToLowerInvariant()
                        $valueText = ([string]$payload.value).ToLowerInvariant()
                        $ratingValue = switch ($valueText) {
                            'up' { 'Up' }
                            'down' { 'Down' }
                            'clear' { 'Clear' }
                            default { $null }
                        }
                        $ratingParameterByCategory = @{
                            accuracy     = 'Accuracy'
                            relevance    = 'Relevance'
                            completeness = 'Completeness'
                            concise      = 'Concise'
                            unbiased     = 'Unbiased'
                        }

                        if ([string]::IsNullOrWhiteSpace($runId) -or [string]::IsNullOrWhiteSpace($responseId)) {
                            Send-ModelComparisonJson -Context $context -Value @{ error = 'RunId and ResponseId are required.' } -StatusCode 400
                        }
                        elseif (-not $ratingParameterByCategory.ContainsKey($category)) {
                            Send-ModelComparisonJson -Context $context -Value @{ error = "Unknown rating category '$category'." } -StatusCode 400
                        }
                        elseif ([string]::IsNullOrWhiteSpace($ratingValue)) {
                            Send-ModelComparisonJson -Context $context -Value @{ error = 'Rating value must be Up, Down, or Clear.' } -StatusCode 400
                        }
                        else {
                            $ratingParameters = @{
                                RunId      = $runId
                                ResponseId = $responseId
                                StorePath  = $StorePath
                            }
                            $ratingParameters[$ratingParameterByCategory[$category]] = $ratingValue
                            try {
                                $updatedResponse = Set-ModelComparisonRating @ratingParameters
                                $updatedStore = Get-ModelComparison -StorePath $StorePath -Raw
                                Send-ModelComparisonJson -Context $context -Value @{
                                    response = $updatedResponse
                                    store    = $updatedStore
                                }
                            }
                            catch {
                                Send-ModelComparisonJson -Context $context -Value @{ error = $_.Exception.Message } -StatusCode 400
                            }
                        }
                    }
                    elseif ($request.HttpMethod -eq 'POST' -and $path -eq '/api/compare') {
                        $reader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
                        try {
                            $body = $reader.ReadToEnd()
                        }
                        finally {
                            $reader.Dispose()
                        }

                        $payload = if ([string]::IsNullOrWhiteSpace($body)) { @{} } else { $body | ConvertFrom-Json }
                        $prompt = [string]$payload.prompt
                        $models = @($payload.models | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                        if ($models.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$payload.modelsText)) {
                            $models = @(([string]$payload.modelsText) -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                        }

                        if ([string]::IsNullOrWhiteSpace($prompt)) {
                            Send-ModelComparisonJson -Context $context -Value @{ error = 'Prompt is required.' } -StatusCode 400
                        }
                        elseif ($models.Count -eq 0) {
                            Send-ModelComparisonJson -Context $context -Value @{ error = 'At least one model is required.' } -StatusCode 400
                        }
                        else {
                            $context.Response.StatusCode = 200
                            $context.Response.ContentType = 'application/x-ndjson; charset=utf-8'
                            $context.Response.SendChunked = $true
                            $writer = [System.IO.StreamWriter]::new($context.Response.OutputStream, [System.Text.UTF8Encoding]::new($false))
                            $writer.AutoFlush = $true
                            $modelJobs = @()

                            try {
                                $run = [PSCustomObject]@{
                                    id             = [guid]::NewGuid().ToString()
                                    kind           = 'comparison'
                                    title          = $null
                                    prompt         = $prompt
                                    createdAt      = (Get-Date).ToUniversalTime().ToString('o')
                                    models         = @($models)
                                    tags           = @()
                                    category       = $null
                                    benchmarkId    = $null
                                    expectedAnswer = $null
                                    scoringType    = $null
                                    notes          = $null
                                    responses      = @($models | ForEach-Object { New-DashboardPendingComparisonResponse -Model $_ -Status 'Running' })
                                }

                                $store = Save-DashboardModelComparisonRun -Run $run
                                Write-DashboardModelComparisonEvent -Writer $writer -Value @{
                                    type      = 'started'
                                    run       = $run
                                    store     = $store
                                    total     = $models.Count
                                    completed = 0
                                }

                                for ($modelIndex = 0; $modelIndex -lt $models.Count; $modelIndex++) {
                                    $model = $models[$modelIndex]
                                    $responseId = $run.responses[$modelIndex].id
                                    $modelJobs += Start-Job -ScriptBlock {
                                        param(
                                            [string]$Prompt,
                                            [string]$Model,
                                            [string]$ResponseId,
                                            [int]$Index,
                                            [string]$SuiteModulePath
                                        )

                                        if (Test-Path -LiteralPath $SuiteModulePath) {
                                            Import-Module $SuiteModulePath -Force
                                        }
                                        else {
                                            Import-Module PSAISuite -Force -ErrorAction SilentlyContinue
                                        }

                                        $modelParts = if ($Model -match '^([^:]+):(.+)$') {
                                            [PSCustomObject]@{ Provider = $Matches[1]; ModelName = $Matches[2] }
                                        }
                                        else {
                                            [PSCustomObject]@{ Provider = ''; ModelName = $Model }
                                        }

                                        $timer = [System.Diagnostics.Stopwatch]::StartNew()
                                        try {
                                            $chatResult = Invoke-ChatCompletion -Model $Model -Prompt $Prompt -Raw -IncludeElapsedTime
                                            $timer.Stop()

                                            $elapsed = if ($chatResult.ElapsedTime -is [TimeSpan]) {
                                                $chatResult.ElapsedTime
                                            }
                                            elseif ($chatResult.ElapsedTime) {
                                                [TimeSpan]::Parse($chatResult.ElapsedTime)
                                            }
                                            else {
                                                $timer.Elapsed
                                            }

                                            $response = [PSCustomObject]@{
                                                id                  = $ResponseId
                                                model               = $Model
                                                provider            = $modelParts.Provider
                                                modelName           = $modelParts.ModelName
                                                response            = $chatResult.Response
                                                error               = $null
                                                status              = 'Succeeded'
                                                elapsedMilliseconds = [math]::Round($elapsed.TotalMilliseconds, 2)
                                                elapsedTime         = $elapsed.ToString('c')
                                                rawScore            = $null
                                                passed              = $null
                                                needsReview         = $false
                                                scoringType         = $null
                                                notes               = $null
                                                userNotes           = $null
                                                ratings             = [PSCustomObject][ordered]@{
                                                    accuracy     = $null
                                                    relevance    = $null
                                                    completeness = $null
                                                    concise      = $null
                                                    unbiased     = $null
                                                }
                                            }
                                        }
                                        catch {
                                            $timer.Stop()
                                            $response = [PSCustomObject]@{
                                                id                  = $ResponseId
                                                model               = $Model
                                                provider            = $modelParts.Provider
                                                modelName           = $modelParts.ModelName
                                                response            = ''
                                                error               = $_.Exception.Message
                                                status              = 'Failed'
                                                elapsedMilliseconds = [math]::Round($timer.Elapsed.TotalMilliseconds, 2)
                                                elapsedTime         = $timer.Elapsed.ToString('c')
                                                rawScore            = $null
                                                passed              = $false
                                                needsReview         = $true
                                                scoringType         = $null
                                                notes               = $null
                                                userNotes           = $null
                                                ratings             = [PSCustomObject][ordered]@{
                                                    accuracy     = $null
                                                    relevance    = $null
                                                    completeness = $null
                                                    concise      = $null
                                                    unbiased     = $null
                                                }
                                            }
                                        }

                                        [PSCustomObject]@{
                                            Index    = $Index
                                            Response = $response
                                        }
                                    } -ArgumentList $prompt, $model, $responseId, $modelIndex, $SuiteModulePath
                                }

                                $completed = 0
                                $remainingJobs = @($modelJobs)
                                while ($remainingJobs.Count -gt 0) {
                                    $null = Wait-Job -Job $remainingJobs -Any -Timeout 1
                                    $finishedJobs = @($remainingJobs | Where-Object { $_.State -in @('Completed', 'Failed', 'Stopped') })

                                    foreach ($job in $finishedJobs) {
                                        $remainingJobs = @($remainingJobs | Where-Object { $_.Id -ne $job.Id })

                                        if ($job.State -eq 'Completed') {
                                            $jobResult = Receive-Job -Job $job | Select-Object -First 1
                                            $responseIndex = [int]$jobResult.Index
                                            $response = $jobResult.Response
                                        }
                                        else {
                                            $responseIndex = [array]::IndexOf($modelJobs.Id, $job.Id)
                                            if ($responseIndex -lt 0) {
                                                $responseIndex = 0
                                            }
                                            $response = New-DashboardPendingComparisonResponse -Model $models[$responseIndex] -Status 'Failed'
                                            $response.id = $run.responses[$responseIndex].id
                                            $response.error = "Model job ended with state $($job.State)."
                                            $response.response = ''
                                            $response.passed = $false
                                            $response.needsReview = $true
                                        }

                                        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                                        $run.responses[$responseIndex] = $response
                                        $completed++
                                        $store = Save-DashboardModelComparisonRun -Run $run
                                        Write-DashboardModelComparisonEvent -Writer $writer -Value @{
                                            type      = 'response'
                                            runId     = $run.id
                                            index     = $responseIndex
                                            response  = $response
                                            total     = $models.Count
                                            completed = $completed
                                        }
                                    }
                                }

                                $store = Save-DashboardModelComparisonRun -Run $run
                                Write-DashboardModelComparisonEvent -Writer $writer -Value @{
                                    type      = 'complete'
                                    run       = $run
                                    store     = $store
                                    total     = $models.Count
                                    completed = $completed
                                }
                            }
                            catch {
                                Write-DashboardModelComparisonEvent -Writer $writer -Value @{
                                    type  = 'error'
                                    error = $_.Exception.Message
                                }
                            }
                            finally {
                                foreach ($job in @($modelJobs | Where-Object { $_.State -notin @('Completed', 'Failed', 'Stopped') })) {
                                    Stop-Job -Job $job -ErrorAction SilentlyContinue
                                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                                }
                                $writer.Flush()
                            }
                        }
                    }
                    else {
                        Send-ModelComparisonJson -Context $context -Value @{ error = 'Not found.' } -StatusCode 404
                    }
                }
                catch {
                    Send-ModelComparisonJson -Context $context -Value @{ error = $_.Exception.Message } -StatusCode 500
                }
                finally {
                    $context.Response.OutputStream.Close()
                }

                if ($shouldStop) {
                    $listener.Stop()
                }
            }
        }
        finally {
            $listener.Stop()
            $listener.Close()
        }
    } -ArgumentList $prefix, $Html, $StorePath, $benchmarkModulePath, $suiteModulePath

    return [PSCustomObject]@{
        Url       = $prefix
        Port      = $Port
        StorePath = $StorePath
        JobId     = $job.Id
        JobName   = $job.Name
    }
}

function Show-ModelComparison {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$StorePath,

        [Parameter(Mandatory = $false)]
        [string]$RunId,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [switch]$Open,

        [Parameter(Mandatory = $false)]
        [int]$Port,

        [Parameter(Mandatory = $false)]
        [switch]$NoBrowser
    )

    $resolvedStorePath = Resolve-ModelComparisonStorePath -StorePath $StorePath
    $store = Read-ModelComparisonStore -StorePath $resolvedStorePath

    if (-not (Test-Path -LiteralPath $resolvedStorePath)) {
        $null = Write-ModelComparisonStore -Store $store -StorePath $resolvedStorePath
    }

    if (-not [string]::IsNullOrWhiteSpace($RunId)) {
        $store.runs = @($store.runs | Where-Object { $_.id -eq $RunId })
    }

    if ($Open) {
        $serverPort = Get-ModelComparisonDashboardPort -Port $Port
        $html = ConvertTo-ModelComparisonDashboardHtml -Store $store -CanRun
        $server = Start-ModelComparisonDashboardServer -Html $html -StorePath $resolvedStorePath -Port $serverPort

        $healthUri = "$($server.Url)api/health"
        $deadline = (Get-Date).AddSeconds(10)
        do {
            Start-Sleep -Milliseconds 100
            if ((Get-Job -Id $server.JobId).State -eq 'Failed') {
                Receive-Job -Id $server.JobId -Keep | Out-String | Write-Error
                throw 'Model comparison dashboard server failed to start.'
            }
            try {
                $null = Invoke-RestMethod -Uri $healthUri -Method Get -TimeoutSec 2
                $ready = $true
            }
            catch {
                $ready = $false
            }
        } until ($ready -or (Get-Date) -gt $deadline)

        if (-not $ready) {
            Remove-Job -Id $server.JobId -Force
            throw 'Timed out waiting for the model comparison dashboard server to start.'
        }

        if (-not $NoBrowser) {
            Start-Process $server.Url
        }

        return $server
    }

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'psaisuite-model-comparisons.html'
    }

    $resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    $parent = Split-Path -Path $resolvedOutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        $null = New-Item -ItemType Directory -Path $parent -Force
    }

    $html = ConvertTo-ModelComparisonDashboardHtml -Store $store
    $html | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

    return (Get-Item -LiteralPath $resolvedOutputPath)
}
