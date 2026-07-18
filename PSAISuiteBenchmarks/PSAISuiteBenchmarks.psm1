$publicFiles = Get-ChildItem -Path "$PSScriptRoot\Public" -Filter "*.ps1" -File
foreach ($file in $publicFiles) {
    . $file.FullName
}

Export-ModuleMember -Function 'Invoke-Benchmark', 'Invoke-BenchmarkScore', 'Invoke-ModelComparison', 'Get-ModelComparison', 'Search-ModelComparison', 'Set-ModelComparisonRating', 'Show-ModelComparison'
