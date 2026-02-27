function Invoke-Benchmark {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Models,

        [Parameter(Mandatory = $false)]
        [string[]]$Category,

        [Parameter(Mandatory = $false)]
        [string]$BenchmarksPath = "$PSScriptRoot\..\benchmarks",

        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    # 1. Load all .ps1 files from BenchmarksPath
    $allBenchmarks = @()
    if (Test-Path $BenchmarksPath) {
        $benchmarkFiles = Get-ChildItem -Path $BenchmarksPath -Filter "*.ps1" -File
        foreach ($file in $benchmarkFiles) {
            $b = . $file.FullName
            if ($b) {
                $allBenchmarks += $b
            }
        }
    }
    else {
        Write-Warning "Benchmarks path not found: $BenchmarksPath"
        return
    }

    # 2. Filter by Category if provided
    if ($Category -and $Category.Count -gt 0) {
        $allBenchmarks = $allBenchmarks | Where-Object { $_.Category -in $Category }
    }

    if ($allBenchmarks.Count -eq 0) {
        Write-Warning "No benchmarks found to run."
        return
    }

    $scoreScriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'Invoke-BenchmarkScore.ps1'

    # 3 & 4. Run models in parallel and score
    $results = @()
    $totalBenchmarks = $allBenchmarks.Count
    $completedBenchmarks = 0

    foreach ($benchmark in $allBenchmarks) {
        $percentComplete = if ($totalBenchmarks -gt 0) {
            [int](($completedBenchmarks / $totalBenchmarks) * 100)
        }
        else {
            0
        }

        Write-Progress -Id 1 -Activity 'Running PSAISuiteBenchmarks' -Status "Benchmark [$($completedBenchmarks + 1)/$totalBenchmarks]: $($benchmark.Category)/$($benchmark.Id) across $($Models.Count) model(s)" -PercentComplete $percentComplete

        $benchmarkData = [PSCustomObject]@{
            Prompt         = $benchmark.Prompt
            ExpectedAnswer = $benchmark.ExpectedAnswer
            ScoringType    = $benchmark.ScoringType
            Notes          = $benchmark.Notes
            Category       = $benchmark.Category
            Id             = $benchmark.Id
        }

        $benchmarkResults = $Models | ForEach-Object -Parallel {
            $model = $_
            $b = $using:benchmarkData

            . $using:scoreScriptPath

            # Call Invoke-ChatCompletion
            $chatResult = Invoke-ChatCompletion -Model $model -Prompt $b.Prompt -Raw -IncludeElapsedTime

            # Call Invoke-BenchmarkScore
            $scoreResult = Invoke-BenchmarkScore -Response $chatResult.Response -ExpectedAnswer $b.ExpectedAnswer -ScoringType $b.ScoringType -Notes $b.Notes

            $elapsed = if ($chatResult.ElapsedTime -is [TimeSpan]) {
                $chatResult.ElapsedTime
            }
            else {
                [TimeSpan]::Parse($chatResult.ElapsedTime)
            }

            # 5. Output PSCustomObject
            [PSCustomObject]@{
                Model       = $model
                Category    = $b.Category
                BenchmarkId = $b.Id
                Prompt      = $b.Prompt
                Response    = $chatResult.Response
                RawScore    = $scoreResult.RawScore
                Passed      = $scoreResult.Passed
                NeedsReview = $scoreResult.NeedsReview
                ElapsedTime = $elapsed
                ScoringType = $scoreResult.ScoringType
                Notes       = $scoreResult.Notes
            }
        }

        $results += $benchmarkResults
        $completedBenchmarks++
    }

    Write-Progress -Id 1 -Activity 'Running PSAISuiteBenchmarks' -Completed

    # 6. Export to CSV if OutputPath provided
    if ($OutputPath) {
        $results | Export-Csv -Path $OutputPath -NoTypeInformation
    }

    # 7. Print summary table to console
    $summary = @()
    $groupedByCategory = $results | Group-Object Category
    foreach ($catGroup in $groupedByCategory) {
        $groupedByModel = $catGroup.Group | Group-Object Model
        foreach ($modelGroup in $groupedByModel) {
            $total = $modelGroup.Group.Count
            $passed = ($modelGroup.Group | Where-Object Passed -eq $true).Count
            $needsReview = ($modelGroup.Group | Where-Object NeedsReview -eq $true).Count
            $failed = ($modelGroup.Group | Where-Object { $_.Passed -eq $false -and $_.NeedsReview -eq $false }).Count

            $validTimes = $modelGroup.Group.ElapsedTime | Where-Object { $_ -is [TimeSpan] }
            if ($validTimes.Count -gt 0) {
                $avgTicks = ($validTimes | Measure-Object -Property Ticks -Average).Average
                $avgTime = [TimeSpan]::FromTicks([long]$avgTicks)
            }
            else {
                $avgTime = [TimeSpan]::Zero
            }

            $summary += [PSCustomObject]@{
                Category       = $catGroup.Name
                Model          = $modelGroup.Name
                TotalTests     = $total
                Passed         = $passed
                Failed         = $failed
                NeedsReview    = $needsReview
                AvgElapsedTime = $avgTime
            }
        }
    }

    $summary | Format-Table -AutoSize | Out-Host

    # Highlight models that failed all InstructionFollowing tests
    $ifGroups = $results | Where-Object Category -eq 'InstructionFollowing' | Group-Object Model
    foreach ($grp in $ifGroups) {
        $allZero = $true
        foreach ($r in $grp.Group) {
            if ($r.RawScore -ne 0) {
                $allZero = $false
                break
            }
        }
        if ($allZero) {
            Write-Warning "$($grp.Name) failed all instruction following tests - not safe for agent pipelines"
        }
    }

    # Return the results to the pipeline
    return $results
}