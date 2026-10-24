# File-tool boundaries, not an OS sandbox for arbitrary user-supplied functions.
function Resolve-AgentToolRoot {
    [OutputType([string])]
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $item = Microsoft.PowerShell.Management\Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.PSProvider.Name -ne 'FileSystem' -or -not $item.PSIsContainer) {
        throw 'ToolRoot must be an existing FileSystem directory.'
    }
    $root = [System.IO.Path]::GetFullPath($item.FullName)
    $volumeRoot = [System.IO.Path]::GetPathRoot($root)
    if ($root.Length -gt $volumeRoot.Length) { $root = $root.TrimEnd([char[]]@('/', '\')) }
    Assert-AgentFilePath -Path $root -Root $root
    return $root
}

function Assert-AgentFilePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root
    )

    $comparison = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else { [System.StringComparison]::Ordinal }
    $prefix = $Root.TrimEnd([char[]]@('/', '\')) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $Path.Equals($Root, $comparison) -and -not $Path.StartsWith($prefix, $comparison)) {
        throw 'Path is outside ToolRoot. Stay inside the allowed directory; ask the user to choose a different ToolRoot if necessary.'
    }
    # Inspect each existing ancestor without traversing a link's contents.
    $ancestor = $Path
    while ($ancestor) {
        $item = $null
        try { $item = Microsoft.PowerShell.Management\Get-Item -LiteralPath $ancestor -Force -ErrorAction Stop }
        catch [System.Management.Automation.ItemNotFoundException] { $item = $null }
        if ($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            throw 'Links and junctions are not permitted by the file-tool boundary.'
        }
        $parent = [System.IO.Directory]::GetParent($ancestor)
        if ($null -eq $parent -or $parent.FullName -eq $ancestor) { break }
        $ancestor = $parent.FullName
    }
}

function Assert-AgentFileTree {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [int]$MaxEntries)

    $pending = New-Object 'System.Collections.Generic.Queue[string]'
    $pending.Enqueue($Path)
    $count = 0
    while ($pending.Count -gt 0) {
        $directory = $pending.Dequeue()
        foreach ($entry in Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) {
            $count++
            if ($MaxEntries -gt 0 -and $count -gt $MaxEntries) { throw "Recursive listing exceeds the policy's $MaxEntries entries. Select a smaller directory or adjust ToolPolicy.MaxScanEntries." }
            if ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                throw 'Recursive listing would encounter a link or junction. Select an explicit directory without links.'
            }
            if ($entry.PSIsContainer) { $pending.Enqueue($entry.FullName) }
        }
    }
}

function Invoke-AgentFileTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Management.Automation.CommandInfo]$Command,
        [Parameter(Mandatory)][hashtable]$Arguments,
        [Parameter(Mandatory)][hashtable]$Policy
    )

    $Root = $Policy.Root
    if ($Arguments.FollowSymlink) { throw 'Following links is not permitted by the file-tool boundary.' }
    if ($Arguments.Wait) { throw 'Get-Content -Wait is not permitted in an agent request.' }
    if ($Arguments.Stream) { throw 'Alternate data streams require a purpose-built tool.' }
    foreach ($key in @('Filter', 'Include', 'Exclude')) {
        foreach ($pattern in $Arguments[$key]) {
            if ([string]$pattern -match '[/\\:]') { throw 'File filters must contain filename patterns only, without directories or providers.' }
        }
    }
    $literal = $Arguments.ContainsKey('LiteralPath')
    $paths = if ($literal) { @($Arguments.LiteralPath) }
    elseif ($Arguments.ContainsKey('Path')) { @($Arguments.Path) }
    else { @($Root) }
    if ($paths.Count -eq 0) { throw 'Supply at least one file path.' }
    if ($Policy.MaxFilePaths -gt 0 -and $paths.Count -gt $Policy.MaxFilePaths) { throw 'Too many file paths for ToolPolicy.MaxFilePaths.' }
    $resolvedPaths = @()
    $readBytes = 0L
    foreach ($path in $paths) {
        if ([string]::IsNullOrWhiteSpace([string]$path)) { throw 'Empty file paths are not permitted.' }
        $candidate = [string]$path
        if (-not [System.IO.Path]::IsPathRooted($candidate) -and $candidate -notmatch '^([^:]+:|~)') {
            $candidate = Join-Path -Path $Root -ChildPath $candidate
        }
        $provider = $null
        $drive = $null
        $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($candidate, [ref]$provider, [ref]$drive)
        if ($provider.Name -ne 'FileSystem') { throw 'File tools may access only the FileSystem provider.' }
        $full = [System.IO.Path]::GetFullPath($full)
        if ([System.IO.Path]::DirectorySeparatorChar -eq '\' -and $full.Substring([System.IO.Path]::GetPathRoot($full).Length).Contains(':')) {
            throw 'Alternate data streams are not permitted in file paths.'
        }
        $hasWildcard = -not $literal -and [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($full)
        if ($hasWildcard) {
            $directory = [System.IO.Path]::GetDirectoryName($full)
            if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($directory)) {
                throw 'Wildcards are permitted only in the final filename. Select an explicit directory inside ToolRoot.'
            }
            Assert-AgentFilePath -Path $directory -Root $Root
            $resolvedMatches = @(Microsoft.PowerShell.Management\Resolve-Path -Path $full -ErrorAction Stop)
        }
        else {
            Assert-AgentFilePath -Path $full -Root $Root
            $resolvedMatches = @(Microsoft.PowerShell.Management\Resolve-Path -LiteralPath $full -ErrorAction Stop)
        }
        foreach ($match in $resolvedMatches) {
            $target = [System.IO.Path]::GetFullPath($match.ProviderPath)
            Assert-AgentFilePath -Path $target -Root $Root
            if ($Policy.MaxFilePaths -gt 0 -and $resolvedPaths.Count -ge $Policy.MaxFilePaths) { throw 'Too many matching paths for ToolPolicy.MaxFilePaths. Select fewer files or adjust the policy.' }
            $item = Microsoft.PowerShell.Management\Get-Item -LiteralPath $target -Force -ErrorAction Stop
            if ($Command.Name -eq 'Get-Content') {
                if ($item.PSIsContainer) { throw 'Get-Content requires a file.' }
                $readBytes += $item.Length
                if ($Policy.MaxReadBytes -gt 0 -and $readBytes -gt $Policy.MaxReadBytes) { throw "The selected files exceed ToolPolicy.MaxReadBytes ($($Policy.MaxReadBytes)). Select smaller files or adjust the policy." }
            }
            elseif (($Arguments.Recurse -or $Arguments.ContainsKey('Depth')) -and $item.PSIsContainer) {
                Assert-AgentFileTree -Path $target -MaxEntries $Policy.MaxScanEntries
            }
            $resolvedPaths += $target
        }
    }
    $bound = @{}
    foreach ($key in $Arguments.Keys) { $bound[$key] = $Arguments[$key] }
    $bound.Remove('Path')
    $bound.Remove('LiteralPath')
    $bound.LiteralPath = $resolvedPaths
    if ($Command.Name -eq 'Get-ChildItem') {
        $listing = { & $Command @bound 2>&1 | Where-Object {
            $_ -isnot [System.IO.FileSystemInfo] -or -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
        } }
        $values = if ($Policy.MaxListedItems -gt 0) { @(& $listing | Select-Object -First ($Policy.MaxListedItems + 1)) }
        else { @(& $listing) }
    }
    else { $values = @(& $Command @bound 2>&1) }
    $errors = @($values | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    if ($errors.Count -gt 0) {
        return [pscustomobject]@{ Output = 'Error: ' + (($errors | ForEach-Object { $_.Exception.Message }) -join '; '); Failed = $true }
    }
    if ($values.Count -eq 0) {
        $text = if ($Command.Name -eq 'Get-ChildItem') {
            'No matching items in the allowed directory. Do not search outside ToolRoot; if there are no relevant files, tell the user.'
        }
        else { '(no output)' }
    }
    else {
        $text = if ($Command.Name -eq 'Get-ChildItem' -and $Policy.MaxListedItems -gt 0) { ($values | Select-Object -First $Policy.MaxListedItems | Out-String -Width 4096).TrimEnd() }
        else { ($values | Out-String -Width 4096).TrimEnd() }
    }
    if ($Command.Name -eq 'Get-ChildItem' -and $Policy.MaxListedItems -gt 0 -and $values.Count -gt $Policy.MaxListedItems) { $text += "`n[Listing limited to $($Policy.MaxListedItems) items by ToolPolicy; select a smaller query or adjust the policy.]" }
    return [pscustomobject]@{ Output = $text; Failed = $false }
}
