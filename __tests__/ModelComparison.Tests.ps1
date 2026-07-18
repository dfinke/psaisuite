BeforeAll {
    Import-Module "$PSScriptRoot\..\PSAISuiteBenchmarks\PSAISuiteBenchmarks.psd1" -Force
}

Describe "Model comparison JSON store" {
    BeforeEach {
        $script:storePath = Join-Path -Path $TestDrive -ChildPath 'model-comparisons.json'
        $store = [PSCustomObject]@{
            schemaVersion    = 1
            createdAt        = '2026-05-19T12:00:00.0000000Z'
            updatedAt        = '2026-05-19T12:00:00.0000000Z'
            ratingCategories = @(
                [PSCustomObject]@{ key = 'accuracy'; label = 'Accuracy'; description = 'Were there any factual errors?' }
                [PSCustomObject]@{ key = 'relevance'; label = 'Relevance'; description = 'Did it answer the prompt?' }
                [PSCustomObject]@{ key = 'completeness'; label = 'Completeness'; description = 'Was anything important missing?' }
                [PSCustomObject]@{ key = 'concise'; label = 'Concise'; description = 'Was the answer appropriately direct?' }
                [PSCustomObject]@{ key = 'unbiased'; label = 'Unbiased'; description = 'Did the answer avoid unwanted bias?' }
            )
            runs             = @(
                [PSCustomObject]@{
                    id             = 'run-001'
                    kind           = 'comparison'
                    title          = 'Capital check'
                    prompt         = 'What is the capital of France?'
                    createdAt      = '2026-05-19T12:00:00.0000000Z'
                    models         = @('openai:gpt-4o-mini')
                    tags           = @('geo')
                    category       = $null
                    benchmarkId    = $null
                    expectedAnswer = $null
                    scoringType    = $null
                    notes          = $null
                    responses      = @(
                        [PSCustomObject]@{
                            id                  = 'response-001'
                            model               = 'openai:gpt-4o-mini'
                            provider            = 'openai'
                            modelName           = 'gpt-4o-mini'
                            response            = 'Paris'
                            error               = $null
                            status              = 'Succeeded'
                            elapsedMilliseconds = 123.45
                            elapsedTime         = '00:00:00.1234500'
                            rawScore            = $null
                            passed              = $null
                            needsReview         = $false
                            scoringType         = $null
                            notes               = $null
                            userNotes           = $null
                            ratings             = [PSCustomObject]@{
                                accuracy     = $null
                                relevance    = $null
                                completeness = $null
                                concise      = $null
                                unbiased     = $null
                            }
                        }
                    )
                }
            )
        }

        $store | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $script:storePath -Encoding UTF8
    }

    It "searches prompts and responses" {
        $result = Search-ModelComparison -Query 'Paris' -StorePath $script:storePath
        @($result).Count | Should -Be 1
        $result.Id | Should -Be 'run-001'
    }

    It "updates response ratings and notes" {
        $updated = Set-ModelComparisonRating -RunId 'run-001' -Model 'openai:gpt-4o-mini' -Accuracy Up -Relevance Down -Notes 'Needs a source.' -StorePath $script:storePath

        $updated.ratings.accuracy | Should -BeTrue
        $updated.ratings.relevance | Should -BeFalse
        $updated.userNotes | Should -Be 'Needs a source.'

        $store = Get-ModelComparison -StorePath $script:storePath -Raw
        $store.runs[0].responses[0].ratings.accuracy | Should -BeTrue
    }

    It "renders a dashboard HTML file" {
        $outputPath = Join-Path -Path $TestDrive -ChildPath 'model-comparisons.html'
        $file = Show-ModelComparison -StorePath $script:storePath -OutputPath $outputPath

        $file.FullName | Should -Be $outputPath
        Test-Path -LiteralPath $outputPath | Should -BeTrue
        $html = Get-Content -LiteralPath $outputPath -Raw
        $html | Should -Match 'Run Comparison'
        $html | Should -Not -Match 'Auto-evaluate'
        $html | Should -Match 'deepseek:deepseek-v4-flash'
        $html | Should -Match 'google:gemini-3.1-flash-lite'
        $html | Should -Match 'textarea.models'
        $html | Should -Match 'min-height: 104px'
        $html | Should -Match 'function scrollResultsTo'
        $html | Should -Match 'page-mark'
        $html | Should -Match '<svg viewBox="0 0 64 64"'
        $html | Should -Match 'rating-button'
        $html | Should -Match ([regex]::Escape('👍🏼'))
        $html | Should -Match ([regex]::Escape('👎🏼'))
    }

    It "creates a missing store when launching the dashboard" {
        $missingStorePath = Join-Path -Path $TestDrive -ChildPath 'new-model-comparisons.json'
        $outputPath = Join-Path -Path $TestDrive -ChildPath 'new-model-comparisons.html'

        $null = Show-ModelComparison -StorePath $missingStorePath -OutputPath $outputPath

        Test-Path -LiteralPath $missingStorePath | Should -BeTrue
        $store = Get-Content -LiteralPath $missingStorePath -Raw | ConvertFrom-Json
        $store.schemaVersion | Should -Be 1
    }

    It "serves the interactive dashboard API" {
        $serverStorePath = Join-Path -Path $TestDrive -ChildPath 'server-model-comparisons.json'
        $server = Show-ModelComparison -StorePath $serverStorePath -Open -NoBrowser

        try {
            $store = Invoke-RestMethod -Uri "$($server.Url)api/store" -Method Get
            $store.schemaVersion | Should -Be 1

            $body = @{
                prompt     = 'hello'
                modelsText = 'missing-provider:model'
            } | ConvertTo-Json
            $result = Invoke-WebRequest -Uri "$($server.Url)api/compare" -Method Post -ContentType 'application/json' -Body $body
            $content = if ($result.Content -is [byte[]]) {
                [System.Text.Encoding]::UTF8.GetString($result.Content)
            }
            else {
                [string]$result.Content
            }
            $events = @($content -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json })
            $complete = $events | Where-Object type -eq 'complete' | Select-Object -First 1

            ($events | Where-Object type -eq 'started').Count | Should -Be 1
            ($events | Where-Object type -eq 'response').Count | Should -Be 1
            ($events | Where-Object type -eq 'evaluation').Count | Should -Be 0
            $complete.run.kind | Should -Be 'comparison'
            $complete.run.responses[0].status | Should -Be 'Failed'

            $ratingBody = @{
                runId      = $complete.run.id
                responseId = $complete.run.responses[0].id
                category   = 'accuracy'
                value      = 'Up'
            } | ConvertTo-Json
            $rating = Invoke-RestMethod -Uri "$($server.Url)api/rating" -Method Post -ContentType 'application/json' -Body $ratingBody
            $rating.response.ratings.accuracy | Should -BeTrue
            $rating.store.runs[0].responses[0].ratings.accuracy | Should -BeTrue

            Test-Path -LiteralPath $serverStorePath | Should -BeTrue
        }
        finally {
            if ($server.JobId) {
                Invoke-RestMethod -Uri "$($server.Url)api/shutdown" -Method Post -ErrorAction SilentlyContinue | Out-Null
                Wait-Job -Id $server.JobId -Timeout 5 -ErrorAction SilentlyContinue | Out-Null
                Remove-Job -Id $server.JobId -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It "captures comparison errors as failed responses" {
        $run = Invoke-ModelComparison -Prompt 'hello' -Models 'missing-provider:model' -NoSave

        $run.kind | Should -Be 'comparison'
        @($run.responses).Count | Should -Be 1
        $run.responses[0].status | Should -Be 'Failed'
        $run.responses[0].needsReview | Should -BeTrue
    }
}
