# Run explicitly with pwsh -File ./__tests__/Test-AgentHarnessLive.ps1.
# Uses the configured provider credentials and makes real model requests.
# Requires PowerShell 7 for the redirected interactive child process.
# No provider, tool, or Read-Host mocks are used.
#Requires -Version 7.0
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'The real tool invoked from provider scope shares test state with this script; all test state is removed in finally.')]
[CmdletBinding()]
param(
    [string]$Model = 'openai:gpt-5.6-luna',
    [switch]$InteractiveChild
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../PSAISuite.psd1" -Force

$global:agentHarnessLiveValue = [guid]::NewGuid().ToString()
$global:agentHarnessLiveCalls = 0
function global:Get-AgentHarnessLiveValue {
    <#
    .SYNOPSIS
    Returns the current test value. Call this tool to discover the value.
    #>
    [CmdletBinding()]
    param()
    $global:agentHarnessLiveCalls++
    $global:agentHarnessLiveValue
}

try {
    $settings = @{
        Model = $Model
        Tools = @('Get-AgentHarnessLiveValue')
        SystemPrompt = 'When asked for the test value, call Get-AgentHarnessLiveValue. Reply with only the exact value, without formatting. For follow-up questions, use the conversation history.'
        MaxIterations = 3
    }

    if ($InteractiveChild) {
        $responses = @(New-AgentHarness @settings)
        if ($responses.Count -ne 2 -or
            $responses[0].Trim() -ne $global:agentHarnessLiveValue -or
            $responses[1].Trim() -ne $global:agentHarnessLiveValue -or
            $global:agentHarnessLiveCalls -ne 1) {
            throw 'Interactive mode did not execute one tool call and retain its answer for the follow-up.'
        }
        Write-Output 'PASS: interactive Read-Host, real tool execution, conversation history, and exit.'
        return
    }

    $harness = New-AgentHarness @settings -PassThru
    if (-not $harness.PSObject.Methods['GetResponse'] -or $global:agentHarnessLiveCalls -ne 0) {
        throw 'PassThru did not return a configuration object without executing tools.'
    }
    Write-Output 'PASS: PassThru returns the editable harness.'

    $response = New-AgentHarness @settings -Prompt 'Call the tool and return the test value.'
    if ($response.Trim() -ne $global:agentHarnessLiveValue -or $global:agentHarnessLiveCalls -ne 1) {
        throw 'Prompt mode did not execute the real tool and return its value.'
    }
    Write-Output 'PASS: Prompt runs the real model/tool loop and returns its answer.'

    $prefix = 'New-AgentHarness -Model '
    $providers = [System.Management.Automation.CommandCompletion]::CompleteInput($prefix, $prefix.Length, $null)
    if ('openai:' -notin $providers.CompletionMatches.CompletionText) {
        throw 'Provider tab completion is missing.'
    }
    $modelInput = $prefix + $Model
    $models = [System.Management.Automation.CommandCompletion]::CompleteInput($modelInput, $modelInput.Length, $null)
    if ($Model -notin $models.CompletionMatches.CompletionText) {
        throw 'Model tab completion did not return the selected model from the live catalog.'
    }
    Write-Output 'PASS: provider and live model catalog tab completion.'

    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = (Get-Command pwsh).Source
    foreach ($argument in @('-NoLogo', '-NoProfile', '-File', $PSCommandPath, '-Model', $Model, '-InteractiveChild')) {
        $start.ArgumentList.Add($argument)
    }
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $child = [System.Diagnostics.Process]::Start($start)
    try {
        $stdout = $child.StandardOutput.ReadToEndAsync()
        $stderr = $child.StandardError.ReadToEndAsync()
        $child.StandardInput.WriteLine('Call the tool and return the test value.')
        $child.StandardInput.WriteLine('Repeat the value from your previous answer without calling any tool.')
        $child.StandardInput.WriteLine('exit')
        $child.StandardInput.Close()
        if (-not $child.WaitForExit(180000)) {
            $child.Kill($true)
            throw 'Interactive live test timed out.'
        }
        $output = $stdout.GetAwaiter().GetResult()
        $errors = $stderr.GetAwaiter().GetResult()
        if ($child.ExitCode -ne 0) {
            throw "Interactive live test failed: $errors`n$output"
        }
        Write-Output $output.TrimEnd()
    }
    finally {
        $child.Dispose()
    }
}
finally {
    Remove-Item Function:\Get-AgentHarnessLiveValue -ErrorAction SilentlyContinue
    Remove-Variable agentHarnessLiveValue, agentHarnessLiveCalls -Scope Global -ErrorAction SilentlyContinue
}
