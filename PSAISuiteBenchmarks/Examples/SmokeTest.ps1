Import-Module $PSScriptRoot\..\PSAISuiteBenchmarks.psd1 -Force

Invoke-Benchmark -Models 'anthropic:claude-sonnet-4-6', 'xAI:grok-4-1-fast-non-reasoning' -Category 'InstructionFollowing'