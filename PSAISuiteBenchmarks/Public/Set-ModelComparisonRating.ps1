function ConvertFrom-ModelComparisonRatingInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Up', 'Down', 'Clear')]
        [string]$Value
    )

    switch ($Value) {
        'Up' { return $true }
        'Down' { return $false }
        'Clear' { return $null }
    }
}

function Set-ModelComparisonRating {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunId,

        [Parameter(Mandatory = $false)]
        [string]$ResponseId,

        [Parameter(Mandatory = $false)]
        [string]$Model,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Up', 'Down', 'Clear')]
        [string]$Accuracy,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Up', 'Down', 'Clear')]
        [string]$Relevance,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Up', 'Down', 'Clear')]
        [string]$Completeness,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Up', 'Down', 'Clear')]
        [string]$Concise,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Up', 'Down', 'Clear')]
        [string]$Unbiased,

        [Parameter(Mandatory = $false)]
        [string]$Notes,

        [Parameter(Mandatory = $false)]
        [string]$StorePath
    )

    if ([string]::IsNullOrWhiteSpace($ResponseId) -and [string]::IsNullOrWhiteSpace($Model)) {
        throw 'Provide either -ResponseId or -Model to choose the response to rate.'
    }

    $store = Read-ModelComparisonStore -StorePath $StorePath
    $run = @($store.runs | Where-Object { $_.id -eq $RunId } | Select-Object -First 1)
    if (-not $run) {
        throw "No model comparison run found with id '$RunId'."
    }

    $matches = if (-not [string]::IsNullOrWhiteSpace($ResponseId)) {
        @($run.responses | Where-Object { $_.id -eq $ResponseId })
    }
    else {
        @($run.responses | Where-Object { $_.model -eq $Model -or $_.modelName -eq $Model })
    }

    if ($matches.Count -eq 0) {
        throw 'No matching response was found for the provided selector.'
    }
    if ($matches.Count -gt 1) {
        throw 'More than one response matched. Use -ResponseId to rate a specific response.'
    }

    $response = $matches[0]
    if (-not $response.PSObject.Properties['ratings']) {
        $response | Add-Member -MemberType NoteProperty -Name 'ratings' -Value (New-ModelComparisonRatings)
    }

    $ratingMap = @{
        Accuracy     = 'accuracy'
        Relevance    = 'relevance'
        Completeness = 'completeness'
        Concise      = 'concise'
        Unbiased     = 'unbiased'
    }

    foreach ($parameterName in $ratingMap.Keys) {
        if ($PSBoundParameters.ContainsKey($parameterName)) {
            $propertyName = $ratingMap[$parameterName]
            if (-not $response.ratings.PSObject.Properties[$propertyName]) {
                $response.ratings | Add-Member -MemberType NoteProperty -Name $propertyName -Value $null
            }
            $response.ratings.$propertyName = ConvertFrom-ModelComparisonRatingInput -Value $PSBoundParameters[$parameterName]
        }
    }

    if ($PSBoundParameters.ContainsKey('Notes')) {
        if (-not $response.PSObject.Properties['userNotes']) {
            $response | Add-Member -MemberType NoteProperty -Name 'userNotes' -Value $null
        }
        $response.userNotes = $Notes
    }

    $null = Write-ModelComparisonStore -Store $store -StorePath $StorePath
    return $response
}
