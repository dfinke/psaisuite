# Run explicitly: pwsh -NoProfile -File ./__tests__/Test-AnthropicAgentHarnessLive.ps1
# Uses real Anthropic requests and PowerShell file tools; no mocks.
[CmdletBinding()]
param(
    [string]$Model = 'anthropic:claude-sonnet-5-5'
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../PSAISuite.psd1" -Force
if ($env:PSAISUITE_DEFAULT_MODEL -and $env:PSAISUITE_DEFAULT_MODEL -ne $Model) {
    throw 'PSAISUITE_DEFAULT_MODEL overrides the selected test model. Clear it before running this test.'
}
if ($Model -notlike 'anthropic:*') {
    throw 'This live test requires an Anthropic model.'
}

$fixturePath = Join-Path ([System.IO.Path]::GetTempPath()) ('psaisuite-anthropic-' + [guid]::NewGuid())
$previousDebug = $env:PSAISUITE_DEBUG_ANTHROPIC
$winner = 'Customer-' + [guid]::NewGuid().ToString('N')
New-Item -ItemType Directory -Path $fixturePath | Out-Null
@"
CustomerId,Name
1,$winner
2,Other Customer
"@ | Set-Content -LiteralPath (Join-Path $fixturePath 'customers.csv')
@'
OrderId,CustomerId,Amount
1,1,120
2,2,500
3,1,450
'@ | Set-Content -LiteralPath (Join-Path $fixturePath 'orders.csv')

Push-Location -LiteralPath $fixturePath
try {
    $env:PSAISUITE_DEBUG_ANTHROPIC = '1'
    $prompt = 'Read the files. Need a ps1 to show which customer bought the most by total Amount. Return the complete runnable script in a powershell code block. Also report the winning customer name and total for the current files.'
    $records = @(New-AgentHarness -Model $Model -Tools Get-ChildItem, Get-Content, Get-Date -Prompt $prompt 6>&1)
    $answers = @()
    $stopReasons = @()
    $toolNames = @()
    foreach ($record in $records) {
        if ($record -is [System.Management.Automation.InformationRecord]) {
            $message = [string]$record.MessageData
            if ($message.StartsWith('Anthropic stop_reason: ')) {
                $stopReasons += $message.Substring('Anthropic stop_reason: '.Length)
            }
            elseif ($message.StartsWith('Anthropic response content: ')) {
                $blocks = $message.Substring('Anthropic response content: '.Length) | ConvertFrom-Json
                $toolNames += @($blocks | Where-Object type -eq 'tool_use' | ForEach-Object name)
            }
        }
        else {
            $answers += [string]$record
        }
    }

    $answer = $answers -join "`n"
    if ($stopReasons.Count -eq 0 -or $stopReasons[-1] -ne 'end_turn') {
        throw "Anthropic did not finish its answer. Stop reasons: $($stopReasons -join ', ')"
    }
    if ('Get-Content' -notin $toolNames) {
        throw 'The model did not call the real file-reading tool.'
    }
    if (-not $answer.Contains($winner) -or $answer -notmatch '570') {
        throw 'The answer did not identify the winning customer and total from the test files.'
    }
    $codeMatch = [regex]::Match($answer, '(?is)```(?:powershell|ps1)\s*\r?\n(.*?)```')
    if (-not $codeMatch.Success) {
        throw 'The answer did not contain a complete fenced PowerShell script.'
    }
    $parseTokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($codeMatch.Groups[1].Value, [ref]$parseTokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        throw 'The returned PowerShell script contained syntax errors.'
    }
    Write-Output "PASS: $Model read real CSV files, identified the winner, and returned a complete PowerShell script."
    Write-Output "Stop reasons: $($stopReasons -join ', ')"
}
finally {
    Pop-Location
    if ($null -eq $previousDebug) {
        Remove-Item Env:PSAISUITE_DEBUG_ANTHROPIC -ErrorAction SilentlyContinue
    }
    else {
        $env:PSAISUITE_DEBUG_ANTHROPIC = $previousDebug
    }
    Remove-Item -LiteralPath (Join-Path $fixturePath 'customers.csv'), (Join-Path $fixturePath 'orders.csv')
    Remove-Item -LiteralPath $fixturePath
}
