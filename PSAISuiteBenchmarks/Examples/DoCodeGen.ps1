Import-Module $PSScriptRoot\..\PSAISuiteBenchmarks.psd1 -Force

Invoke-Benchmark -Models 'google:gemini-3-flash-preview', 'xAI:grok-4-1-fast-non-reasoning', 'anthropic:claude-sonnet-4-6', 'openai:gpt-5.3-codex' -Category 'CodeGen'