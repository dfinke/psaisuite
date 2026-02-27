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

## How to Run

Import the module, then run all benchmarks or scoped runs by category, optionally exporting to CSV.

```powershell
Import-Module .\PSAISuiteBenchmarks.psd1 -Force

# Run one category
Invoke-Benchmark -Models 'anthropic:claude-sonnet-4-6','xAI:grok-4-1-fast-non-reasoning' -Category 'InstructionFollowing'

# Run one category and export results
Invoke-Benchmark -Models 'anthropic:claude-sonnet-4-6','xAI:grok-4-1-fast-non-reasoning' -Category 'InstructionFollowing' -OutputPath .\results-instructionfollowing.csv

# Run all categories and export results
Invoke-Benchmark -Models 'anthropic:claude-sonnet-4-6','xAI:grok-4-1-fast-non-reasoning' -OutputPath .\results-all.csv
```

## Interpreting Results

- **RawScore**: Numeric score from automatic evaluation (`1` pass, `0` fail, or `$null` when not auto-scorable).
- **Passed**: Boolean pass/fail summary (`$true` only when `RawScore` is non-null and non-zero).
- **NeedsReview**: Boolean indicating manual verification is required (manual scoring type or scoring exception path).

If a model scores **0 across all `InstructionFollowing` tests**, treat it as **unsafe for agent pipeline use**: it is likely to violate strict output contracts that automation depends on (JSON shape, exact formatting, token constraints, etc.).