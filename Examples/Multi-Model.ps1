Clear-Host

Import-Module $PSScriptRoot\..\PSAISuite.psd1 -Force

$code = Get-Content $PSScriptRoot\..\Public\Invoke-LLM.ps1

$models = $(
    'openrouter:meta-llama/llama-4-maverick '
    'gemini:gemini-2.5-pro-exp-03-25'
)

$code | Invoke-LLM explain -Models $models | Select-Object timestamp, model, response 