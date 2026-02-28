function Invoke-BenchmarkScore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Response,

        [Parameter(Mandatory = $false)]
        [string]$ExpectedAnswer,

        [Parameter(Mandatory = $true)]
        [ValidateSet('exact', 'contains', 'not-contains', 'manual', 'json-valid', 'regex')]
        [string]$ScoringType,

        [Parameter(Mandatory = $false)]
        [string]$Notes
    )

    $trimmedResponse = if ($null -ne $Response) { $Response.Trim() } else { '' }
    
    $rawScore = $null
    $passed = $false
    $needsReview = $false

    try {
        switch ($ScoringType) {
            'exact' {
                if ($trimmedResponse -ieq $ExpectedAnswer) {
                    $rawScore = 1
                    $passed = $true
                }
                else {
                    $rawScore = 0
                }
            }
            'contains' {
                if ($trimmedResponse -match [regex]::Escape($ExpectedAnswer)) {
                    $rawScore = 1
                    $passed = $true
                }
                else {
                    $rawScore = 0
                }
            }
            'not-contains' {
                if ($trimmedResponse -notmatch [regex]::Escape($ExpectedAnswer)) {
                    $rawScore = 1
                    $passed = $true
                }
                else {
                    $rawScore = 0
                }
            }
            'regex' {
                if ($trimmedResponse -match $ExpectedAnswer) {
                    $rawScore = 1
                    $passed = $true
                }
                else {
                    $rawScore = 0
                }
            }
            'json-valid' {
                try {
                    $jsonObject = ConvertFrom-Json -InputObject $trimmedResponse -ErrorAction Stop
                    $allKeysExist = $true
                    
                    if (-not [string]::IsNullOrWhiteSpace($ExpectedAnswer)) {
                        $keys = $ExpectedAnswer -split ',' | ForEach-Object Trim
                        foreach ($key in $keys) {
                            $hasKey = $false
                            if ($jsonObject -is [System.Collections.IDictionary]) {
                                $hasKey = $jsonObject.Contains($key)
                            }
                            elseif ($null -ne $jsonObject.psobject) {
                                $hasKey = $jsonObject.psobject.Properties.Name -contains $key
                            }
                            
                            if (-not $hasKey) {
                                $allKeysExist = $false
                                break
                            }
                        }
                    }
                    
                    if ($allKeysExist) {
                        $rawScore = 1
                        $passed = $true
                    }
                    else {
                        $rawScore = 0
                    }
                }
                catch {
                    $rawScore = 0
                    $passed = $false
                    $needsReview = $false
                    $Notes = if ($Notes) { "$Notes`nJSON parse error: $_" } else { "JSON parse error: $_" }
                }
            }
            'manual' {
                $rawScore = $null
                $passed = $false
                $needsReview = $true
            }
        }
    }
    catch {
        $rawScore = $null
        $passed = $false
        $needsReview = $true
        $Notes = if ($Notes) { "$Notes`nScoring exception: $_" } else { "Scoring exception: $_" }
    }

    return @{
        RawScore    = $rawScore
        Passed      = $passed
        NeedsReview = $needsReview
        ScoringType = $ScoringType
        Notes       = $Notes
    }
}
