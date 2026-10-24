# Real filesystem/tool integration checks. No API requests or mocked commands.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../PSAISuite.psd1" -Force
$module = Get-Module PSAISuite
$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$fixture = Join-Path $tempBase ('psaisuite-boundary-' + [guid]::NewGuid())
$root = Join-Path $fixture 'allowed'
$outside = Join-Path $fixture 'allowed-sibling'
$empty = Join-Path $fixture 'empty'
$junction = Join-Path $root 'escape-link'
$driveName = 'Boundary' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$sentinel = [guid]::NewGuid().ToString()
$schemas = @{}
foreach ($name in @('Get-ChildItem', 'Get-Content', 'Get-Date')) {
    $schemas[$name] = (Register-Tool $name).function.parameters
    $schemas[$name].required = @() # Let the real parameter-set guard select Path or LiteralPath.
}
# Register-Tool describes a command's default parameter set. Include the real
# alternate/dynamic parameters exercised by these explicit schema checks.
foreach ($name in @('Get-ChildItem', 'Get-Content')) {
    $schemas[$name].properties['LiteralPath'] = @{type='array';items=@{type='string'}}
}
$schemas['Get-ChildItem'].properties['FollowSymlink'] = @{type='boolean'}
$schemas['Get-Content'].properties['Raw'] = @{type='boolean'}
$schemas['Get-Content'].properties['Wait'] = @{type='boolean'}
$schemas['gci'] = $schemas['Get-ChildItem']
function Invoke-FileProbe {
    param([string]$Name, [hashtable]$Arguments, [string]$AllowedRoot = $root, [hashtable]$Options)
    & $module {
        param($Name, $Json, $Schemas, $Root, $Options)
        $policy = New-AgentToolPolicy -Root $Root -Options $Options
        Invoke-RegisteredAgentTool -Name $Name -Arguments $Json -RegisteredTools $Schemas -Policy $policy
    } $Name ($Arguments | ConvertTo-Json -Depth 10 -Compress) $schemas $AllowedRoot $Options
}
function Assert-Probe {
    param($Result, [bool]$Failed, [string]$Label)
    if ($Result.Failed -ne $Failed -or ($Failed -and $Result.Output.Contains($sentinel))) { throw "Boundary check failed: $Label ($($Result.Output))" }
    Write-Output "PASS: $Label"
}

try {
    New-Item -ItemType Directory -Path $root, $outside, $empty, (Join-Path $root 'sub') | Out-Null
    Set-Content -LiteralPath (Join-Path $outside 'secret.txt') -Value $sentinel
    Set-Content -LiteralPath (Join-Path $root 'data.csv') -Value 'inside'
    Set-Content -LiteralPath (Join-Path $root 'literal[1].txt') -Value 'literal'
    Set-Content -LiteralPath (Join-Path $root 'sub/nested.txt') -Value 'nested'
    Set-Content -LiteralPath (Join-Path $root 'long.txt') -Value ('x' * 30000)
    [System.IO.File]::WriteAllText((Join-Path $root 'big.bin'), ('x' * (1MB + 1)))
    $root = & $module { param($Path) Resolve-AgentToolRoot -Path $Path } $root

    Assert-Probe (Invoke-FileProbe Get-ChildItem @{}) $false 'omitted path stays inside root'
    $inside = Invoke-FileProbe Get-Content @{Path='./data.csv'}
    Assert-Probe $inside $false 'relative file path'
    if ($inside.Output.Trim() -ne 'inside') { throw 'Unexpected file output.' }
    Assert-Probe (Invoke-FileProbe Get-Content @{Path='./*.csv'}) $false 'leaf wildcard inside root'
    Assert-Probe (Invoke-FileProbe Get-Content @{LiteralPath='./literal[1].txt'}) $false 'literal wildcard characters'
    Assert-Probe (Invoke-FileProbe Get-Content @{Path='./sub/nested.txt'}) $false 'nested file inside root'
    Assert-Probe (Invoke-FileProbe Get-ChildItem @{Recurse=$true}) $false 'ordinary recursion inside root'
    Assert-Probe (Invoke-FileProbe Get-ChildItem @{Path='..'}) $true 'parent traversal denied'
    Assert-Probe (Invoke-FileProbe Get-Content @{Path=('../allowed-sibling/secret.txt')}) $true 'relative sibling read denied'
    Assert-Probe (Invoke-FileProbe Get-Content @{LiteralPath=(Join-Path $outside 'secret.txt')}) $true 'absolute sibling and prefix collision denied'
    Assert-Probe (Invoke-FileProbe gci @{Path=$outside}) $true 'alias cannot bypass boundary'
    Assert-Probe (Invoke-FileProbe Get-Content @{Path='Env:PATH'}) $true 'other PowerShell provider denied'
    Assert-Probe (Invoke-FileProbe Get-Content @{Path='../allowed-*/secret.txt'}) $true 'wildcard directory escape denied'
    Assert-Probe (Invoke-FileProbe Get-ChildItem @{Filter='../allowed-sibling/*'}) $true 'filter traversal denied'
    Assert-Probe (Invoke-FileProbe Get-ChildItem @{FollowSymlink=$true}) $true 'following links denied'
    Assert-Probe (Invoke-FileProbe Get-Content @{Path='./data.csv';Wait=$true}) $true 'unbounded waiting denied'
    Assert-Probe (Invoke-FileProbe Get-Content @{Path='./big.bin'}) $true 'oversized read denied'
    $bounded = Invoke-FileProbe Get-Content @{Path='./long.txt';Raw=$true}
    Assert-Probe $bounded $false 'large output safely bounded'
    if ($bounded.Output.Length -gt 20200 -or $bounded.Output -notmatch 'truncated') { throw 'Output limit was not applied.' }
    $unlimited = Invoke-FileProbe Get-Content @{Path='./long.txt';Raw=$true} -Options @{MaxOutputCharacters=0}
    Assert-Probe $unlimited $false 'output limit can be disabled by the caller'
    if ($unlimited.Output.Length -le 20000 -or $unlimited.Output -match 'truncated') { throw 'Unlimited output option was ignored.' }
    Assert-Probe (Invoke-FileProbe Get-Content @{Path='./big.bin';Raw=$true} -Options @{MaxReadBytes=2MB;MaxOutputCharacters=100}) $false 'read budget can be increased'
    $limitedListing = Invoke-FileProbe Get-ChildItem @{} -Options @{MaxListedItems=1}
    Assert-Probe $limitedListing $false 'listing budget is configurable'
    if ($limitedListing.Output -notmatch 'limited to 1 items') { throw 'Listing policy was ignored.' }
    Assert-Probe (Invoke-FileProbe Get-ChildItem @{Recurse=$true} -Options @{MaxScanEntries=1}) $true 'scan budget is configurable'
    Assert-Probe (Invoke-FileProbe Get-Content @{Path=@('./data.csv','./sub/nested.txt')} -Options @{MaxFilePaths=1}) $true 'file count budget is configurable'
    Assert-Probe (Invoke-FileProbe Get-Content @{Path=@('./data.csv') * 101} -Options @{MaxFilePaths=0}) $false 'file count budget can be disabled'
    Assert-Probe (Invoke-FileProbe Get-Date @{} -Options @{BeforeInvoke={ param($call) $call.Name -ne 'Get-Date' }}) $true 'generic callback can deny a non-file tool'
    Assert-Probe (Invoke-FileProbe Get-Date @{} -Options @{BeforeInvoke={ param($call) $call.Name -eq 'Get-Date' }}) $false 'generic callback can allow a non-file tool'
    Assert-Probe (Invoke-FileProbe Get-Date @{} -Options @{BeforeInvoke={ 'allow' }}) $true 'non-Boolean policy decisions fail closed'
    Assert-Probe (Invoke-FileProbe gci @{} -Options @{BeforeInvoke={ param($call) $call.Command.Name -ne 'Get-ChildItem' }}) $true 'policy callback sees the resolved command behind an alias'
    $emptyResult = Invoke-FileProbe Get-ChildItem @{} $empty
    Assert-Probe $emptyResult $false 'empty directory reported without searching elsewhere'
    if ($emptyResult.Output -notmatch 'No matching items') { throw 'Empty directory result is unclear.' }

    New-PSDrive -Name $driveName -PSProvider FileSystem -Root $outside -Scope Global | Out-Null
    Assert-Probe (Invoke-FileProbe Get-Content @{Path=($driveName + ':\secret.txt')}) $true 'PSDrive mapping cannot bypass boundary'
    $linkType = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $junction -Target $outside | Out-Null
    Assert-Probe (Invoke-FileProbe Get-Content @{Path='./escape-link/secret.txt'}) $true 'junction or symlink traversal denied'
    Assert-Probe (Invoke-FileProbe Get-ChildItem @{Recurse=$true}) $true 'recursive link escape denied'
    $listing = Invoke-FileProbe Get-ChildItem @{}
    Assert-Probe $listing $false 'nonrecursive listing omits links'
    if ($listing.Output -match 'escape-link') { throw 'Directory listing exposed link metadata.' }
    $rejectedRoot = $false
    try { & $module { param($Path) Resolve-AgentToolRoot -Path $Path } $junction | Out-Null }
    catch { $rejectedRoot = $true }
    if (-not $rejectedRoot) { throw 'Link-based root was accepted.' }
    Write-Output 'PASS: link-based root denied'
}
finally {
    Remove-PSDrive -Name $driveName -Scope Global -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $junction) { Remove-Item -LiteralPath $junction -Force }
    $resolved = [System.IO.Path]::GetFullPath($fixture)
    if ($resolved -eq $fixture -and (Split-Path -Path $resolved -Parent) -eq $tempBase.TrimEnd([char[]]@('/', '\')) -and
        (Split-Path -Path $resolved -Leaf) -like 'psaisuite-boundary-*') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
