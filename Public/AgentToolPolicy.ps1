# Provider-neutral execution policy. Models do not author or modify this policy.
function New-AgentToolPolicy {
    [OutputType([hashtable])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory execution policy only.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [hashtable]$Options = @{}
    )

    $policy = @{
        Root = Resolve-AgentToolRoot -Path $Root
        MaxReadBytes = 1MB
        MaxOutputCharacters = 20000
        MaxListedItems = 1000
        MaxScanEntries = 4096
        MaxFilePaths = 100
        BeforeInvoke = $null
    }
    foreach ($key in $Options.Keys) {
        if ($key -eq 'Root' -or -not $policy.ContainsKey($key)) { throw "Unknown ToolPolicy option '$key'. Set the root using ToolRoot." }
        $value = $Options[$key]
        if ($key -eq 'BeforeInvoke') {
            if ($null -ne $value -and $value -isnot [scriptblock]) { throw 'ToolPolicy.BeforeInvoke must be a scriptblock.' }
        }
        elseif (($value -isnot [int] -and $value -isnot [long]) -or $value -lt 0 -or
            ($key -ne 'MaxReadBytes' -and $value -gt ([int]::MaxValue - 1))) {
            throw "ToolPolicy.$key must be a non-negative integer; zero means unlimited."
        }
        $policy[$key] = $value
    }
    return $policy
}
