# Internal helpers shared by providers; these are not exported by the manifest.
function New-AgentActivity {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates only an in-memory progress context and stopwatch.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,
        [Parameter(Mandatory)]
        [string]$Model,
        [Parameter(Mandatory)]
        [int]$MaxIterations
    )

    [pscustomobject]@{
        Id            = Get-Random -Minimum 1 -Maximum ([int]::MaxValue)
        Provider      = $Provider
        Label         = "$Provider agent: $Model"
        MaxIterations = $MaxIterations
        Round         = 1
        Stopwatch     = [System.Diagnostics.Stopwatch]::StartNew()
        Completed     = $false
    }
}

function Write-AgentActivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Activity,
        [Parameter(Mandatory)]
        [string]$Message,
        [int]$Round,
        [switch]$Completed
    )

    if ($Activity.Completed) { return }
    if ($Round -gt 0) { $Activity.Round = $Round }
    if ($Completed) {
        $Activity.Stopwatch.Stop()
        $Activity.Completed = $true
    }

    $elapsed = $Activity.Stopwatch.Elapsed.TotalSeconds.ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
    $status = "Round $($Activity.Round)/$($Activity.MaxIterations) | $Message | ${elapsed}s elapsed"
    Write-Verbose "[$($Activity.Provider)] $status"

    # A round limit is not a measure of work remaining. Use indeterminate progress.
    Write-Progress -Id $Activity.Id -Activity $Activity.Label -Status $status -PercentComplete -1 -Completed:$Completed
}
