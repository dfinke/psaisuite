#requires -Version 7.0
#requires -Module PSAI

param(
    [string]$Prompt = "Date: $(Get-Date) - latest AI Lab news",
    [string[]]$Models,
    [object[]]$Tools
)

if (!$models) {
    $models = @(
        'openai:gpt-4.1'
        'xAI:grok-4-1-fast-non-reasoning'
        'anthropic:claude-sonnet-4-5-20250929'
        'google:gemini-flash-latest'
    )
}

. $PSScriptRoot\Invoke-AICompare.ps1 -Prompt $Prompt -Models $models -Tools $Tools