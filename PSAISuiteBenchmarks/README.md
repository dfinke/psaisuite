<table>
  <tr>
    <td width="86">
      <img src="./Assets/model-comparison-icon.svg" alt="PSAISuite model comparison icon" width="72" height="72">
    </td>
    <td>
      <h1>PSAISuite Benchmarks</h1>
      <p>Benchmark harness and model comparison dashboard for comparing provider behavior, latency, and response quality.</p>
    </td>
  </tr>
</table>

## What This Is

A benchmark suite for evaluating AI models across categories: `InstructionFollowing`, `Reasoning`, `CodeGen`, and `Latency`.
It is built on top of `psaisuite`, which supports 15 providers and their models, making side-by-side evaluation straightforward across a broad model landscape.

## Key Finding: InstructionFollowing Results

Both `anthropic:claude-sonnet-4-6` and `xAI:grok-4-1-fast-non-reasoning` scored **3/4** on instruction following. Both models are strong at structured output tasks (raw JSON, numbered lists, integer-only responses). The key differentiator is latency: xAI averages ~0.41s versus Claude at ~0.89s, roughly **2x faster** at equivalent accuracy, giving xAI a measurable advantage for latency-sensitive agent pipelines.

## Reasoning Results (8 prompts, 4 models)

Claude and GPT each scored **7/8**, xAI scored **5/8**, and Gemini scored **6/8**; xAI specifically missed `reasoning-006` (coin order) and `reasoning-008` (last place). Gemini failed `reasoning-008` with “Impossible,” which is technically defensible in natural language but treated as incorrect for benchmark consistency. Gemini also showed severe latency (about **15s average**, with some prompts in the **28–35s** range), which points more to a provider/endpoint issue than model capability. Claude violated strict output format on `reasoning-006` but still passed due to substring matching (known scoring gap requiring manual format review), while xAI remained fastest at ~0.45s average and GPT was slowest at ~1.7s.

## CodeGen Results (5 prompts, 3 models — Gemini excluded due to free tier quota)

Claude, GPT, and xAI each scored **5/5** on automatic scoring, but that headline is misleading without manual validation. Current CodeGen auto-scoring only checks whether the expected function name appears, so manual review and execution are still required to verify correctness. In manual review, Claude’s `Test-PalindromeString` uses `Select-Object -Last`, which does not reverse input and would fail on non-palindromes, while GPT’s `Test-PalindromeString` includes a pipeline bug around `[Array]::Reverse`. xAI returned every response wrapped in markdown code fences despite explicit instructions not to; those runs still passed because the contains check found function names inside fenced blocks, even though fenced output can break agent pipelines. Latency favored xAI at **1.1s** average, followed by Claude at **2.4s**, with GPT at **3.1s**, and the combined outcome exposes a scorer gap that should add a markdown-fence not-contains check for CodeGen instruction-following failures.

## Latency Results (5 prompts, 3 models — xAI and Gemini excluded this run)

All three models scored **4/5** on `latency-005`, with **1 manual review** each. Claude was fastest at **0.67s** average, followed by GPT-5.3-codex at **1.08s** and GPT-4.1 at **1.24s**. `latency-005` asked for the current day of the week, and today is Thursday: GPT-4.1 and GPT-5.3-codex answered Thursday correctly, while Claude answered Monday with no hedging or uncertainty—a confident hallucination. That is a meaningful signal for time-sensitive agent workflows where stale or fabricated temporal facts can quietly break automation decisions. Claude also added bold markdown formatting on `latency-004` (returned `**32**` instead of `32`) despite the "one word only" instruction, which is consistent with the markdown-fence/output-format drift pattern already seen in CodeGen.

## Full Suite Summary

| Model | InstructionFollowing | Reasoning | CodeGen | Latency | AvgLatency |
| --- | --- | --- | --- | --- | --- |
| anthropic:claude-sonnet-4-6 | 3/4 | 7/8 | 5/5* | 4/5 | 0.67s |
| openai:gpt-5.3-codex | — | 7/8 | 5/5* | 4/5 | 1.08s |
| xAI:grok-4-1-fast-non-reasoning | 3/4 | 5/8 | 5/5* | — | 0.45s |
| google:gemini-3-flash-preview | — | 6/8 | 3/5† | — | ~15s⚠️ |
| openai:gpt-4.1 | — | — | — | 4/5 | 1.24s |

* CodeGen scores require manual review — automatic scoring checks function name only
† Gemini hit free tier quota limit (429) on `codegen-004` and `codegen-005`

This suite is designed to give `psaisuite` users a reproducible, runnable baseline they can execute on their own setup to compare model behavior across quality and latency dimensions. As additional models are added over time, the value compounds by preserving consistent test prompts, scoring conventions, and operational context so trend comparisons stay meaningful.

## Known Scorer Gaps

1. CodeGen scoring uses contains on function name only, so correctness still requires manual execution and review.
2. Markdown fence detection is missing, so models that wrap output in code fences pass CodeGen scoring despite violating output constraints. Planned fix: add a not-contains `ScoringType` and a `CodeGenNoMarkdown` benchmark file.

## Benchmark Categories

- **InstructionFollowing**: Tests strict compliance with formatting and output constraints required for reliable automation.
- **Reasoning**: Tests multi-step logic, consistency, and ability to arrive at correct conclusions from provided context.
- **CodeGen**: Tests correctness, structure, and practical usability of generated code for implementation tasks.
- **Latency**: Tests response-time characteristics under benchmark workloads to assess runtime suitability.

## Benchmark Hashtable Layout (How to Author a Benchmark)

Each benchmark file in `benchmarks/*.ps1` returns an array of hashtables (`@(...)`).
Each hashtable is one test case.

Required shape:

```powershell
@(
		@{
				Id             = 'instruction-following-001'
				Category       = 'InstructionFollowing'
				Prompt         = 'Respond with exactly three words. Do not use punctuation.'
				ExpectedAnswer = '^(\S+)\s+(\S+)\s+(\S+)$'
				ScoringType    = 'regex'
				Notes          = 'What this test is checking and any review guidance.'
		}
)
```

Field reference:

- `Id`: Unique benchmark identifier (string).
- `Category`: Group name used for filtering and summary (for example: `InstructionFollowing`, `Reasoning`, `CodeGen`, `Latency`).
- `Prompt`: Prompt text sent to the model.
- `ExpectedAnswer`: Meaning depends on `ScoringType` (exact value, substring, regex pattern, JSON key list, etc.).
- `ScoringType`: One of the supported scoring modes (see below).
- `Notes`: Human-readable intent, caveats, and manual-review guidance.

### Scoring Types Explained

The scorer trims the model response (`.Trim()`) before evaluation.

- `exact`
	- Passes when response equals `ExpectedAnswer` (case-insensitive string comparison).
	- Best for strict single-value responses.

- `contains`
	- Passes when response contains `ExpectedAnswer` as a literal substring (case-insensitive regex match using escaped expected text).
	- Useful when the answer may include surrounding text.

- `not-contains`
	- Passes when response does **not** contain `ExpectedAnswer`.
	- Useful for guardrails, for example rejecting markdown code fences by checking for ```` ``` ````.

- `regex`
	- Passes when response matches regex in `ExpectedAnswer`.
	- Best for format constraints (like exact list numbering or integer-only output).

- `json-valid`
	- First checks the response parses as valid JSON.
	- If `ExpectedAnswer` is provided (comma-separated keys, e.g. `name,capital`), each key must exist.
	- Fails on parse errors or missing keys.

- `manual`
	- Always sets `RawScore = $null`, `Passed = $false`, `NeedsReview = $true`.
	- Use when correctness is contextual or requires human judgment.

### How Results Are Interpreted

- `RawScore`
	- `1` = automatic pass
	- `0` = automatic fail
	- `$null` = not auto-scorable (manual)

- `Passed`
	- `$true` only when auto-scored and pass condition met.

- `NeedsReview`
	- `$true` for `manual` scoring or if an exception occurred during scoring.

### Authoring Tips

- Keep `Id` unique across files to avoid analysis confusion.
- Keep `Category` names consistent; category filtering uses exact string matching.
- For regex, prefer anchors (`^...$`) for strict formatting tests.
- Use `CodeGen` in two passes when needed:
	1. functional presence check (for example `contains` with function name)
	2. formatting enforcement (for example `not-contains` with ```` ``` ````)
- Put manual-review instructions in `Notes` so reviewers know exactly what to validate.

## How to Run

Import the module, then run all benchmarks or scoped runs by category, optionally exporting to CSV.

```powershell
Import-Module .\PSAISuiteBenchmarks.psm1 -Force

# Run one category
Invoke-Benchmark -Models 'anthropic:claude-sonnet-4-6','xAI:grok-4-1-fast-non-reasoning' -Category 'InstructionFollowing'

# Run one category and export results
Invoke-Benchmark -Models 'anthropic:claude-sonnet-4-6','xAI:grok-4-1-fast-non-reasoning' -Category 'InstructionFollowing' -OutputPath .\results-instructionfollowing.csv

# Run all categories and export results
Invoke-Benchmark -Models 'anthropic:claude-sonnet-4-6','xAI:grok-4-1-fast-non-reasoning' -OutputPath .\results-all.csv

# Run one category and also persist it to the JSON comparison store
Invoke-Benchmark -Models 'anthropic:claude-sonnet-4-6','xAI:grok-4-1-fast-non-reasoning' -Category 'InstructionFollowing' -SaveJson -Tags 'agent-pipeline'
```

## Model Comparison History

`Invoke-ModelComparison` runs one ad hoc prompt across multiple PSAISuite models, captures response text, latency, errors, and review fields, then saves the run to a JSON store. By default the store is written to:

```powershell
$env:LOCALAPPDATA\PSAISuite\model-comparisons.json
```

Run a comparison:

```powershell
$models = @(
    'openai:gpt-4o-mini'
    'anthropic:claude-sonnet-4-6'
    'deepseek:deepseek-v4-flash'
    'google:gemini-3.1-flash-lite'
    'xAI:grok-4-1-fast-non-reasoning'
)

Invoke-ModelComparison -Prompt 'Explain PowerShell splatting with one small example.' -Models $models -Title 'Splatting explanation' -Tags 'docs','powershell'
```

Use a repo-local JSON file:

```powershell
Invoke-ModelComparison -Prompt 'Return valid JSON with name and capital for France.' -Models $models -StorePath .\model-comparisons.json
```

Search saved prompts and responses:

```powershell
Search-ModelComparison -Query 'valid JSON'
Search-ModelComparison -Model 'openai:gpt-4o-mini' -Tag 'powershell'
Get-ModelComparison -Last 5
```

Rate a response:

```powershell
$run = Get-ModelComparison -Last 1 -IncludeResponses
Set-ModelComparisonRating -RunId $run.Id -Model 'openai:gpt-4o-mini' -Accuracy Up -Relevance Up -Completeness Down -Notes 'Missed one edge case.'
```

Open the interactive local dashboard:

```powershell
Show-ModelComparison -Open
Show-ModelComparison -StorePath .\model-comparisons.json -Open
```

`Show-ModelComparison -Open` creates the JSON store if it does not exist, starts a small localhost dashboard server, and opens the browser. The primary screen has a prompt box, a whitespace-separated model list, and a `Run Comparison` button. `Ctrl+Enter` runs the comparison from either text box. While a run is active, the dashboard switches to a wait cursor, disables the run button, shows one pending card per model, and updates each card as that model finishes.

Example model list:

```text
openai:gpt-4o-mini
anthropic:claude-sonnet-4-6
deepseek:deepseek-v4-flash
google:gemini-3.1-flash-lite
```

The dashboard saves each run back to the JSON store, then displays the responses side by side with latency, errors, benchmark scores, human ratings, history, and search.

Export a read-only static HTML snapshot:

```powershell
Show-ModelComparison -StorePath .\model-comparisons.json -OutputPath .\model-comparisons.html
```

## Interpreting Results

- **RawScore**: Numeric score from automatic evaluation (`1` pass, `0` fail, or `$null` when not auto-scorable).
- **Passed**: Boolean pass/fail summary (`$true` only when `RawScore` is non-null and non-zero).
- **NeedsReview**: Boolean indicating manual verification is required (manual scoring type or scoring exception path).

If a model scores **0 across all `InstructionFollowing` tests**, treat it as **unsafe for agent pipeline use**: it is likely to violate strict output contracts that automation depends on (JSON shape, exact formatting, token constraints, etc.).
