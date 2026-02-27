Import-Module $PSScriptRoot\..\PSAISuiteBenchmarks.psd1 -Force

Invoke-Benchmark -Models 'openai:gpt-4.1', 'anthropic:claude-sonnet-4-6', 'openai:gpt-5.3-codex' -Category 'Latency'