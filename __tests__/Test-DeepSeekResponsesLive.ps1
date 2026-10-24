# Explicit real API and tool checks; no mocks. Uses the configured DeepSeekKey.
# Run: pwsh -NoProfile -File ./__tests__/Test-DeepSeekResponsesLive.ps1
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'Test tools invoked from provider scope share temporary state; finally removes the state and commands.')]
[CmdletBinding()]
param([string]$Model = 'deepseek:deepseek-flash')

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../PSAISuite.psd1" -Force
if ($Model -notlike 'deepseek:*' -or ($env:PSAISUITE_DEFAULT_MODEL -and $env:PSAISUITE_DEFAULT_MODEL -ne $Model)) {
    throw 'Select a DeepSeek model and clear a conflicting PSAISUITE_DEFAULT_MODEL override.'
}
$global:deepSeekProbeValue = [guid]::NewGuid().ToString()
$global:deepSeekProbeCalls = 0
function global:Get-DeepSeekProbe {
    <# .SYNOPSIS
    Returns the private test value. Call the tool to discover it.
    #>
    [CmdletBinding()]
    param()
    $global:deepSeekProbeCalls++
    $global:deepSeekProbeValue
}
function global:Get-DeepSeekRequiredProbe {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Value)
    $global:deepSeekProbeCalls++
    $Value
}

try {
    # Exercise the real execution guard with invalid inputs. No API is needed
    # to verify that rejected calls cannot run a command or prompt for input.
    $guardResults = & (Get-Module PSAISuite) {
        $tools = @{'Get-DeepSeekProbe' = @{type='object';properties=@{}}}
        Invoke-RegisteredAgentTool -Name Get-DeepSeekRequiredProbe -Arguments '{"Value":"bad"}' -RegisteredTools $tools
        Invoke-RegisteredAgentTool -Name Get-DeepSeekProbe -Arguments '{broken}' -RegisteredTools $tools
        Invoke-RegisteredAgentTool -Name Get-DeepSeekProbe -Arguments '[]' -RegisteredTools $tools
        Invoke-RegisteredAgentTool -Name Get-DeepSeekProbe -Arguments '{"Unknown":true}' -RegisteredTools $tools
        $tools['Get-DeepSeekRequiredProbe'] = @{type='object';properties=@{Value=@{type='string'}};required=@('Value')}
        Invoke-RegisteredAgentTool -Name Get-DeepSeekRequiredProbe -Arguments '{}' -RegisteredTools $tools
        $tools['Get-DeepSeekRequiredProbe'].required = @()
        Invoke-RegisteredAgentTool -Name Get-DeepSeekRequiredProbe -Arguments '{}' -RegisteredTools $tools
    }
    if (@($guardResults).Count -ne 6 -or @($guardResults | Where-Object { -not $_.Failed }).Count -gt 0 -or $global:deepSeekProbeCalls -ne 0) {
        throw 'Tool guards failed to reject unknown names, invalid JSON, unknown arguments, or missing mandatory parameters.'
    }
    Write-Output 'PASS: six real tool guard checks; no rejected command executed.'

    $first = Invoke-ChatCompletion -Model $Model -Messages @(
        @{role='system';content='Call Get-DeepSeekProbe exactly once and return only its exact value.'}
        @{role='user';content='Use the tool to discover the private value.'}
    ) -Tools Get-DeepSeekProbe -EffortLevel low -Raw
    if ($first.Response.Trim() -ne $global:deepSeekProbeValue -or $global:deepSeekProbeCalls -ne 1) { throw 'Real function calling failed.' }
    $calls = @($first.Conversation | Where-Object type -eq 'function_call')
    $outputs = @($first.Conversation | Where-Object type -eq 'function_call_output')
    $reasoning = @($first.Conversation | Where-Object type -eq 'reasoning')
    if ($calls.Count -ne 1 -or $outputs.Count -ne 1 -or $calls[0].call_id -ne $outputs[0].call_id -or $reasoning.Count -eq 0) {
        throw 'Conversation metadata lost tool pairing or thinking history.'
    }
    Write-Output 'PASS: real Responses function call, tool output pairing, and reasoning history.'

    $second = Invoke-ChatCompletion -Model $Model -Messages (@($first.Conversation) + @(
        @{role='user';content='Repeat the value you already discovered, without calling any tool.'}
    )) -Tools Get-DeepSeekProbe -EffortLevel low -Raw
    if ($second.Response.Trim() -ne $global:deepSeekProbeValue -or $global:deepSeekProbeCalls -ne 1) { throw 'Stateless follow-up replay failed.' }
    Write-Output 'PASS: follow-up retained reasoning, tool results, and the final answer without re-executing the tool.'

    $schema = @{Name='Get-DeepSeekProbe';Description='Return the private test value.';Parameters=@{type='object';properties=@{}}}
    $schemaResult = New-AgentHarness -Model $Model -Prompt 'Call the tool and return only its exact private value.' -Tools $schema
    if ($schemaResult.Trim() -ne $global:deepSeekProbeValue -or $global:deepSeekProbeCalls -ne 2) { throw 'Provider-neutral schema execution failed.' }
    Write-Output 'PASS: New-AgentHarness accepts a provider-neutral function schema.'

    $plain = 'Sample context' | Invoke-ChatCompletion -Model $Model -Messages 'Reply with exactly READY.' -EffortLevel none
    if ($plain.Trim() -ne 'READY') { throw 'Plain text or pipeline context compatibility failed.' }
    Write-Output 'PASS: text-only requests and pipeline context with thinking disabled.'

    $dateResult = Invoke-ChatCompletion -Model $Model -Messages 'Call Get-Date with Format yyyy and return only its result.' -Tools Get-Date -EffortLevel none -Raw
    if ($dateResult.Response.Trim() -ne (Get-Date -Format yyyy) -or
        @($dateResult.Conversation | Where-Object { $_.type -eq 'function_call' -and $_.name -eq 'Get-Date' }).Count -eq 0) {
        throw 'The built-in Get-Date tool failed.'
    }
    Write-Output 'PASS: built-in Get-Date and PowerShell argument binding.'

    $fixturePath = Join-Path ([System.IO.Path]::GetTempPath()) ('deepseek-tools-' + [guid]::NewGuid())
    $fixtureFile = Join-Path $fixturePath 'value.txt'
    New-Item -ItemType Directory -Path $fixturePath | Out-Null
    Set-Content -LiteralPath $fixtureFile -Value $global:deepSeekProbeValue
    try {
        $fileResult = Invoke-ChatCompletion -Model $Model -Messages "List files in '$fixturePath' using Get-ChildItem, then read value.txt with Get-Content. Return only the contents." -Tools Get-ChildItem, Get-Content -EffortLevel none -Raw
        $calledNames = @($fileResult.Conversation | Where-Object type -eq 'function_call' | ForEach-Object name)
        if ($fileResult.Response.Trim() -ne $global:deepSeekProbeValue -or 'Get-ChildItem' -notin $calledNames -or 'Get-Content' -notin $calledNames) {
            throw 'Built-in file listing and reading failed.'
        }
        Write-Output 'PASS: real Get-ChildItem and Get-Content calls read the generated file.'
    }
    finally {
        Remove-Item -LiteralPath $fixtureFile
        Remove-Item -LiteralPath $fixturePath
    }
}
finally {
    Remove-Item Function:\Get-DeepSeekProbe, Function:\Get-DeepSeekRequiredProbe -ErrorAction SilentlyContinue
    Remove-Variable deepSeekProbeValue, deepSeekProbeCalls -Scope Global -ErrorAction SilentlyContinue
}
