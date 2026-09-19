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
            elseif ($tool.Contains('functionDeclarations')) {
                foreach ($declaration in @($tool['functionDeclarations'])) {
                    $declarationName = if ($declaration -is [System.Collections.IDictionary]) { $declaration['name'] } else { $declaration.name }
                    if (-not [string]::IsNullOrWhiteSpace([string]$declarationName) -and -not $names.Contains([string]$declarationName)) {
                        $names.Add([string]$declarationName)
                    }
                }
                continue
            }
            elseif ($tool.Contains('function_declarations')) {
                foreach ($declaration in @($tool['function_declarations'])) {
                    $declarationName = if ($declaration -is [System.Collections.IDictionary]) { $declaration['name'] } else { $declaration.name }
                    if (-not [string]::IsNullOrWhiteSpace([string]$declarationName) -and -not $names.Contains([string]$declarationName)) {
                        $names.Add([string]$declarationName)
                    }
                }
                continue
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
            elseif ($tool.PSObject.Properties['functionDeclarations']) {
                foreach ($declaration in @($tool.functionDeclarations)) {
                    $declarationName = $declaration.name
                    if (-not [string]::IsNullOrWhiteSpace([string]$declarationName) -and -not $names.Contains([string]$declarationName)) {
                        $names.Add([string]$declarationName)
                    }
                }
                continue
            }
            elseif ($tool.PSObject.Properties['function_declarations']) {
                foreach ($declaration in @($tool.function_declarations)) {
                    $declarationName = $declaration.name
                    if (-not [string]::IsNullOrWhiteSpace([string]$declarationName) -and -not $names.Contains([string]$declarationName)) {
                        $names.Add([string]$declarationName)
                    }
                }
                continue
            }
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$name) -and -not $names.Contains([string]$name)) {
            $names.Add([string]$name)
        }
    }

    return @($names)
}
