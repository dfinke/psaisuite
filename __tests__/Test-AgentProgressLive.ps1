# Explicit live checks; invokes real providers and tools without mocks.
# Run: pwsh -NoProfile -File ./__tests__/Test-AgentProgressLive.ps1
[CmdletBinding()]
param(
    [string[]]$Models = @('openai:gpt-6-luna', 'anthropic:claude-sonnet-5-5'),
    [ValidateSet('Success', 'ToolFailure', 'Limit', 'ApiFailure')]
    [string[]]$Cases = @('Success', 'ToolFailure', 'Limit', 'ApiFailure')
)

$ErrorActionPreference = 'Stop'
if ($env:PSAISUITE_DEFAULT_MODEL) {
    throw 'Clear PSAISUITE_DEFAULT_MODEL before testing individual providers.'
}
$manifestPath = (Resolve-Path "$PSScriptRoot/../PSAISuite.psd1").Path
$runCase = {
    param($ManifestPath, $Model, $Mode, $Nonce)
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'Continue'
    Import-Module $ManifestPath -Force
    $script:probeValue = $Nonce
    $script:probeMode = $Mode
    $script:probeCalls = 0
    function Get-AgentProgressValue {
        <#
        .SYNOPSIS
        Returns the test value. Call this tool to discover the value.
        #>
        [CmdletBinding()]
        param()
        $script:probeCalls++
        if ($script:probeMode -eq 'ToolFailure') {
            Write-Error 'Intentional live tool failure' -ErrorAction Continue
            return
        }
        $script:probeValue
    }

    $options = @{
        Model = $Model
        Tools = @('Get-AgentProgressValue')
        SystemPrompt = 'Call Get-AgentProgressValue exactly once before answering. Return only its exact value. If it fails, say the tool failed and do not retry.'
        Prompt = 'Call the tool and return the test value.'
        MaxIterations = 3
        Verbose = $true
    }
    if ($Mode -eq 'Limit') { $options.MaxIterations = 1 }
    if ($Mode -eq 'ApiFailure') {
        $options.Model = ($Model -split ':', 2)[0] + ':psaisuite-missing-model-live-test'
    }
    $errorCaught = $false
    $response = @()
    try { $response = @(New-AgentHarness @options) }
    catch { $errorCaught = $true }
    [pscustomobject]@{ Response = $response; ToolCalls = $script:probeCalls; ErrorCaught = $errorCaught }
}

foreach ($model in $Models) {
    foreach ($case in $Cases) {
        $nonce = [guid]::NewGuid().ToString()
        $pipeline = [powershell]::Create()
        try {
            $null = $pipeline.AddScript($runCase.ToString()).AddArgument($manifestPath).AddArgument($model).AddArgument($case).AddArgument($nonce)
            $pending = $pipeline.BeginInvoke()
            $timer = [System.Diagnostics.Stopwatch]::StartNew()
            $sawLiveProgress = $false
            while (-not $pending.IsCompleted) {
                if ($pipeline.Streams.Progress.Count -gt 0) { $sawLiveProgress = $true }
                if ($timer.Elapsed.TotalSeconds -gt 180) {
                    $pipeline.Stop()
                    throw "$model $case timed out."
                }
                Start-Sleep -Milliseconds 100
            }
            $results = @($pipeline.EndInvoke($pending))
            if ($results.Count -ne 1) { throw "$model $case returned unexpected success-stream output." }
            $result = $results[0]
            $progress = @($pipeline.Streams.Progress)
            $logs = @($pipeline.Streams.Verbose | ForEach-Object Message)
            $statuses = @($progress | ForEach-Object StatusDescription)
            if ($progress.Count -eq 0 -or $progress[-1].RecordType -ne 'Completed') {
                throw "$model $case left progress unfinished."
            }
            if (@($progress | Where-Object PercentComplete -ne -1).Count) {
                throw "$model $case reported a misleading completion percentage."
            }
            if (-not ($statuses -match 'Round 1/\d+ \| Waiting for response \| [\d.]+s elapsed')) {
                throw "$model $case is missing the waiting status."
            }
            if (-not ($logs -match 'Waiting for response')) {
                throw "$model $case did not forward -Verbose through the harness."
            }
            switch ($case) {
                'Success' {
                    if (-not $sawLiveProgress) { throw "$model progress was not visible while the request ran." }
                    if ($result.Response.Count -ne 1 -or $result.Response[0].Trim() -ne $nonce -or $result.ToolCalls -ne 1) {
                        throw "$model failed real tool execution or polluted the response stream."
                    }
                    foreach ($expected in @('Tool started: Get-AgentProgressValue', 'Tool completed: Get-AgentProgressValue', 'Round 2/', 'Response completed')) {
                        if (-not ($statuses -match [regex]::Escape($expected))) { throw "$model missing activity: $expected" }
                    }
                }
                'ToolFailure' {
                    if ($result.ErrorCaught -or $result.ToolCalls -ne 1 -or -not ($statuses -match 'Tool failed: Get-AgentProgressValue')) {
                        throw "$model did not report a real tool failure and continue the conversation."
                    }
                }
                'Limit' {
                    if ($result.ToolCalls -ne 1 -or -not ($statuses[-1] -match 'Stopped: maximum iterations reached')) {
                        throw "$model did not report the iteration limit."
                    }
                }
                'ApiFailure' {
                    if (-not $result.ErrorCaught -or -not ($statuses[-1] -match 'Request failed')) {
                        throw "$model did not report the API failure."
                    }
                }
            }
            Write-Output "PASS: $model / $case ($($progress.Count) progress events; output kept separate)."
        }
        finally { $pipeline.Dispose() }
    }
}
