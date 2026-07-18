function Get-ModelComparison {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Id,

        [Parameter(Mandatory = $false)]
        [int]$Last,

        [Parameter(Mandatory = $false)]
        [string]$StorePath,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeResponses,

        [Parameter(Mandatory = $false)]
        [switch]$Raw
    )

    $store = Read-ModelComparisonStore -StorePath $StorePath
    if ($Raw) {
        return $store
    }

    $runs = @($store.runs)

    if (-not [string]::IsNullOrWhiteSpace($Id)) {
        $runs = @($runs | Where-Object { $_.id -eq $Id })
    }

    $runs = @($runs | Sort-Object -Property createdAt -Descending)

    if ($Last -gt 0) {
        $runs = @($runs | Select-Object -First $Last)
    }

    if ($IncludeResponses) {
        return $runs
    }

    return ($runs | ConvertTo-ModelComparisonSummary)
}
