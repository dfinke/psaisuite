# PSAISuite Project Conventions

## Build & Test Commands
- **Load Module:** `Import-Module ./PSAISuite.psd1 -Force`
- **Run Benchmarks:** `Import-Module ./PSAISuiteBenchmarks/PSAISuiteBenchmarks.psm1; Invoke-Benchmark -Models 'openai:gpt-4o','anthropic:claude-3-5-sonnet'`
- **Validation:** `Invoke-ScriptAnalyzer -Path ./`

## Architectural Principles
- **Unified Interface:** All new provider integrations MUST adhere to the standardized `-Messages` and `-Model` parameter set.
- **Abstraction over Specificity:** Avoid adding provider-specific parameters to `Invoke-ChatCompletion`. Use the internal mapping logic to handle provider quirks.
- **Pipe-First Design:** Ensure `Invoke-ChatCompletion` consistently accepts pipeline input for context.
- **Error Handling:** Standardize error responses across providers so the calling agent/user receives consistent failure objects.

## Coding Style
- Follow Verb-Noun naming conventions.
- Maintain the "Thin Wrapper" philosophy: minimize overhead between the user and the LLM endpoint.
- Ensure tab-completion for `-Model` is updated when new models are added to `Get-ChatProviders`.