function Get-DefaultModelComparisonStorePath {
    [CmdletBinding()]
    param()

    $root = if ($env:LOCALAPPDATA) {
        Join-Path -Path $env:LOCALAPPDATA -ChildPath 'PSAISuite'
    }
    else {
        Join-Path -Path $HOME -ChildPath '.psaisuite'
    }

    return (Join-Path -Path $root -ChildPath 'model-comparisons.json')
}

function Resolve-ModelComparisonStorePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$StorePath
    )

    if ([string]::IsNullOrWhiteSpace($StorePath)) {
        $StorePath = Get-DefaultModelComparisonStorePath
    }

    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($StorePath)
}

function New-ModelComparisonRatings {
    [CmdletBinding()]
    param()

    return [PSCustomObject][ordered]@{
        accuracy     = $null
        relevance    = $null
        completeness = $null
        concise      = $null
        unbiased     = $null
    }
}

function New-ModelComparisonStore {
    [CmdletBinding()]
    param()

    return [PSCustomObject]@{
        schemaVersion    = 1
        createdAt        = (Get-Date).ToUniversalTime().ToString('o')
        updatedAt        = (Get-Date).ToUniversalTime().ToString('o')
        ratingCategories = @(
            [PSCustomObject]@{ key = 'accuracy'; label = 'Accuracy'; description = 'Were there any factual errors?' }
            [PSCustomObject]@{ key = 'relevance'; label = 'Relevance'; description = 'Did it answer the prompt?' }
            [PSCustomObject]@{ key = 'completeness'; label = 'Completeness'; description = 'Was anything important missing?' }
            [PSCustomObject]@{ key = 'concise'; label = 'Concise'; description = 'Was the answer appropriately direct?' }
            [PSCustomObject]@{ key = 'unbiased'; label = 'Unbiased'; description = 'Did the answer avoid unwanted bias?' }
        )
        runs             = @()
    }
}

function Read-ModelComparisonStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$StorePath
    )

    $resolvedPath = Resolve-ModelComparisonStorePath -StorePath $StorePath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return (New-ModelComparisonStore)
    }

    $raw = Get-Content -LiteralPath $resolvedPath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return (New-ModelComparisonStore)
    }

    $store = $raw | ConvertFrom-Json
    if (-not $store.PSObject.Properties['schemaVersion']) {
        $store | Add-Member -MemberType NoteProperty -Name 'schemaVersion' -Value 1
    }
    if (-not $store.PSObject.Properties['createdAt']) {
        $store | Add-Member -MemberType NoteProperty -Name 'createdAt' -Value (Get-Date).ToUniversalTime().ToString('o')
    }
    if (-not $store.PSObject.Properties['updatedAt']) {
        $store | Add-Member -MemberType NoteProperty -Name 'updatedAt' -Value (Get-Date).ToUniversalTime().ToString('o')
    }
    if (-not $store.PSObject.Properties['ratingCategories']) {
        $fresh = New-ModelComparisonStore
        $store | Add-Member -MemberType NoteProperty -Name 'ratingCategories' -Value $fresh.ratingCategories
    }
    if (-not $store.PSObject.Properties['runs']) {
        $store | Add-Member -MemberType NoteProperty -Name 'runs' -Value @()
    }

    $store.runs = @($store.runs)
    foreach ($run in $store.runs) {
        if (-not $run.PSObject.Properties['responses']) {
            $run | Add-Member -MemberType NoteProperty -Name 'responses' -Value @()
        }
        $run.responses = @($run.responses)

        foreach ($response in $run.responses) {
            if (-not $response.PSObject.Properties['ratings']) {
                $response | Add-Member -MemberType NoteProperty -Name 'ratings' -Value (New-ModelComparisonRatings)
            }
            foreach ($category in @('accuracy', 'relevance', 'completeness', 'concise', 'unbiased')) {
                if (-not $response.ratings.PSObject.Properties[$category]) {
                    $response.ratings | Add-Member -MemberType NoteProperty -Name $category -Value $null
                }
            }
        }
    }

    return $store
}

function Write-ModelComparisonStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Store,

        [Parameter(Mandatory = $false)]
        [string]$StorePath
    )

    $resolvedPath = Resolve-ModelComparisonStorePath -StorePath $StorePath
    $parent = Split-Path -Path $resolvedPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        $null = New-Item -ItemType Directory -Path $parent -Force
    }

    $Store.updatedAt = (Get-Date).ToUniversalTime().ToString('o')
    $Store | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $resolvedPath -Encoding UTF8
    return $resolvedPath
}

function Add-ModelComparisonRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Run,

        [Parameter(Mandatory = $false)]
        [string]$StorePath
    )

    $store = Read-ModelComparisonStore -StorePath $StorePath
    $runs = [System.Collections.Generic.List[object]]::new()
    foreach ($existingRun in @($store.runs)) {
        $runs.Add($existingRun)
    }
    for ($index = $Run.Count - 1; $index -ge 0; $index--) {
        $runs.Insert(0, $Run[$index])
    }

    $store.runs = @($runs)
    $null = Write-ModelComparisonStore -Store $store -StorePath $StorePath
    return $Run
}

function Split-ModelComparisonModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Model
    )

    if ($Model -match '^([^:]+):(.+)$') {
        return [PSCustomObject]@{
            Provider  = $Matches[1]
            ModelName = $Matches[2]
        }
    }

    return [PSCustomObject]@{
        Provider  = ''
        ModelName = $Model
    }
}

function ConvertTo-ModelComparisonSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$Run
    )

    process {
        $responses = @($Run.responses)
        $elapsed = @($responses | Where-Object { $null -ne $_.elapsedMilliseconds } | ForEach-Object { [double]$_.elapsedMilliseconds })
        $avgLatency = if ($elapsed.Count -gt 0) {
            [math]::Round(($elapsed | Measure-Object -Average).Average, 2)
        }
        else {
            $null
        }

        [PSCustomObject]@{
            Id             = $Run.id
            Kind           = $Run.kind
            CreatedAt      = $Run.createdAt
            Title          = $Run.title
            Category       = $Run.category
            BenchmarkId    = $Run.benchmarkId
            Prompt         = $Run.prompt
            Models         = (@($Run.models) -join ', ')
            ResponseCount  = $responses.Count
            Succeeded      = ($responses | Where-Object status -eq 'Succeeded').Count
            Failed         = ($responses | Where-Object status -eq 'Failed').Count
            NeedsReview    = ($responses | Where-Object needsReview -eq $true).Count
            AvgLatencyMs   = $avgLatency
            Tags           = (@($Run.tags) -join ', ')
        }
    }
}

function Invoke-ModelComparison {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Prompt,

        [Parameter(Mandatory = $true, Position = 1)]
        [string[]]$Models,

        [Parameter(Mandatory = $false)]
        [string]$Title,

        [Parameter(Mandatory = $false)]
        [string[]]$Tags,

        [Parameter(Mandatory = $false)]
        [object[]]$Tools,

        [Parameter(Mandatory = $false)]
        [string]$StorePath,

        [Parameter(Mandatory = $false)]
        [switch]$NoSave
    )

    $createdAt = (Get-Date).ToUniversalTime().ToString('o')
    Write-Progress -Activity 'Running model comparison' -Status "Prompt across $($Models.Count) model(s)" -PercentComplete 0

    $responses = $Models | ForEach-Object -Parallel {
        $model = $_
        $modelParts = if ($model -match '^([^:]+):(.+)$') {
            [PSCustomObject]@{ Provider = $Matches[1]; ModelName = $Matches[2] }
        }
        else {
            [PSCustomObject]@{ Provider = ''; ModelName = $model }
        }

        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $params = @{
                Model              = $model
                Prompt             = $using:Prompt
                Raw                = $true
                IncludeElapsedTime = $true
            }

            if ($using:Tools) {
                $params.Tools = $using:Tools
            }

            $chatResult = Invoke-ChatCompletion @params
            $timer.Stop()

            $elapsed = if ($chatResult.ElapsedTime -is [TimeSpan]) {
                $chatResult.ElapsedTime
            }
            elseif ($chatResult.ElapsedTime) {
                [TimeSpan]::Parse($chatResult.ElapsedTime)
            }
            else {
                $timer.Elapsed
            }

            [PSCustomObject]@{
                id                  = [guid]::NewGuid().ToString()
                model               = $model
                provider            = $modelParts.Provider
                modelName           = $modelParts.ModelName
                response            = $chatResult.Response
                error               = $null
                status              = 'Succeeded'
                elapsedMilliseconds = [math]::Round($elapsed.TotalMilliseconds, 2)
                elapsedTime         = $elapsed.ToString('c')
                rawScore            = $null
                passed              = $null
                needsReview         = $false
                scoringType         = $null
                notes               = $null
                userNotes           = $null
                ratings             = [PSCustomObject][ordered]@{
                    accuracy     = $null
                    relevance    = $null
                    completeness = $null
                    concise      = $null
                    unbiased     = $null
                }
            }
        }
        catch {
            $timer.Stop()
            [PSCustomObject]@{
                id                  = [guid]::NewGuid().ToString()
                model               = $model
                provider            = $modelParts.Provider
                modelName           = $modelParts.ModelName
                response            = ''
                error               = $_.Exception.Message
                status              = 'Failed'
                elapsedMilliseconds = [math]::Round($timer.Elapsed.TotalMilliseconds, 2)
                elapsedTime         = $timer.Elapsed.ToString('c')
                rawScore            = $null
                passed              = $false
                needsReview         = $true
                scoringType         = $null
                notes               = $null
                userNotes           = $null
                ratings             = [PSCustomObject][ordered]@{
                    accuracy     = $null
                    relevance    = $null
                    completeness = $null
                    concise      = $null
                    unbiased     = $null
                }
            }
        }
    }

    Write-Progress -Activity 'Running model comparison' -Completed

    $run = [PSCustomObject]@{
        id             = [guid]::NewGuid().ToString()
        kind           = 'comparison'
        title          = $Title
        prompt         = $Prompt
        createdAt      = $createdAt
        models         = @($Models)
        tags           = @($Tags)
        category       = $null
        benchmarkId    = $null
        expectedAnswer = $null
        scoringType    = $null
        notes          = $null
        responses      = @($responses)
    }

    if (-not $NoSave) {
        $null = Add-ModelComparisonRun -Run $run -StorePath $StorePath
    }

    return $run
}
