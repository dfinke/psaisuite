function Search-ModelComparison {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [string[]]$Model,

        [Parameter(Mandatory = $false)]
        [string[]]$Category,

        [Parameter(Mandatory = $false)]
        [string[]]$Tag,

        [Parameter(Mandatory = $false)]
        [string]$StorePath,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeResponses
    )

    $store = Read-ModelComparisonStore -StorePath $StorePath
    $runs = @($store.runs)

    if (-not [string]::IsNullOrWhiteSpace($Query)) {
        $runs = @($runs | Where-Object {
                $run = $_
                $haystack = @(
                    $run.id
                    $run.kind
                    $run.title
                    $run.prompt
                    $run.category
                    $run.benchmarkId
                    $run.expectedAnswer
                    $run.notes
                    @($run.tags)
                    @($run.models)
                    @($run.responses | ForEach-Object {
                            @(
                                $_.id
                                $_.model
                                $_.provider
                                $_.modelName
                                $_.response
                                $_.error
                                $_.notes
                                $_.userNotes
                            )
                        })
                ) | Where-Object { $null -ne $_ }

                (($haystack -join "`n") -match [regex]::Escape($Query))
            })
    }

    if ($Model -and $Model.Count -gt 0) {
        $runs = @($runs | Where-Object {
                $runModels = @($_.models) + @($_.responses | ForEach-Object { $_.model })
                foreach ($modelName in $Model) {
                    if ($runModels -contains $modelName) {
                        return $true
                    }
                }
                return $false
            })
    }

    if ($Category -and $Category.Count -gt 0) {
        $runs = @($runs | Where-Object { $_.category -in $Category })
    }

    if ($Tag -and $Tag.Count -gt 0) {
        $runs = @($runs | Where-Object {
                $runTags = @($_.tags)
                foreach ($tagName in $Tag) {
                    if ($runTags -contains $tagName) {
                        return $true
                    }
                }
                return $false
            })
    }

    $runs = @($runs | Sort-Object -Property createdAt -Descending)

    if ($IncludeResponses) {
        return $runs
    }

    return ($runs | ConvertTo-ModelComparisonSummary)
}
