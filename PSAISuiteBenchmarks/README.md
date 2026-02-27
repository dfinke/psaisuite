## What This Is

A benchmark suite for evaluating AI models across categories: `InstructionFollowing`, `Reasoning`, `CodeGen`, and `Latency`.
It is built on top of `psaisuite`, which supports 15 providers and their models, making side-by-side evaluation straightforward across a broad model landscape.

## Key Finding: InstructionFollowing Results

Both `anthropic:claude-sonnet-4-6` and `xAI:grok-4-1-fast-non-reasoning` scored **3/4** on instruction following. Both models are strong at structured output tasks (raw JSON, numbered lists, integer-only responses). The key differentiator is latency: xAI averages ~0.41s versus Claude at ~0.89s, roughly **2x faster** at equivalent accuracy, giving xAI a measurable advantage for latency-sensitive agent pipelines.

## Reasoning Results (8 prompts, 4 models)

Claude and GPT each scored **7/8**, xAI scored **5/8**, and Gemini scored **6/8**; xAI specifically missed `reasoning-006` (coin order) and `reasoning-008` (last place). Gemini failed `reasoning-008` with “Impossible,” which is technically defensible in natural language but treated as incorrect for benchmark consistency. Gemini also showed severe latency (about **15s average**, with some prompts in the **28–35s** range), which points more to a provider/endpoint issue than model capability. Claude violated strict output format on `reasoning-006` but still passed due to substring matching (known scoring gap requiring manual format review), while xAI remained fastest at ~0.45s average and GPT was slowest at ~1.7s.

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