#Requires -Version 5.1

# Get public and private function definition files
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue | Sort-Object -Property Name)
$Providers = @(Get-ChildItem -Path $PSScriptRoot\Providers\*.ps1 -ErrorAction SilentlyContinue | Sort-Object -Property Name)

# Dot source the files
foreach ($import in @($Public + $Providers)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}

Set-Alias -Name icc -Value Invoke-ChatCompletion 
Set-Alias -Name generateText -Value Invoke-ChatCompletion 