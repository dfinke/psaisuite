function Get-ToolInvocationNames {
    [CmdletBinding()]
    param(
        [object[]]$Tools
    )

    $names = New-Object 'System.Collections.Generic.List[string]'

    foreach ($tool in @($Tools)) {
        $name = $null

        if ($tool -is [System.Collections.IDictionary]) {
            if ($tool.Contains('function')) {
                $functionBlock = $tool['function']
                if ($functionBlock -is [System.Collections.IDictionary]) {
                    $name = $functionBlock['name']
                }
                elseif ($functionBlock.PSObject.Properties['name']) {
                    $name = $functionBlock.name
                }
            }
            elseif ($tool.Contains('name')) {
                $name = $tool['name']
            }
            elseif ($tool.Contains('Name')) {
                $name = $tool['Name']
            }
        }
        else {
            if ($tool.PSObject.Properties['function']) {
                $name = $tool.function.name
            }
            elseif ($tool.PSObject.Properties['name']) {
                $name = $tool.name
            }
            elseif ($tool.PSObject.Properties['Name']) {
                $name = $tool.Name
            }
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$name) -and -not $names.Contains([string]$name)) {
            $names.Add([string]$name)
        }
    }

    return @($names)
}
