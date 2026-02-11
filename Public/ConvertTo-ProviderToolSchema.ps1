<#
.SYNOPSIS
Converts agnostic tool definitions into provider-specific tool schemas.

.DESCRIPTION
ConvertTo-ProviderToolSchema accepts agnostic tool definitions (Name, Description, Parameters)
or raw provider tool objects. It converts agnostic tools into provider-specific schemas
based on -Provider and passes through already provider-formatted tools (type = 'function').
The function always returns an array of tools and uses ordered hashtables to preserve key order.

.PARAMETER Tools
One or more tool definitions to convert. Accepts pipeline input or an array. Tools can be:
- Agnostic tools: PSCustomObject or hashtable with keys Name, Description, Parameters
- Raw provider tools: objects that already have type = 'function'

.PARAMETER Provider
The target provider schema to generate. Currently supports only "openai".

.PARAMETER PassThru
Returns the input tools unchanged without conversion.

.EXAMPLE
$tool = @{
    Name = "Invoke-WebSearch"
    Description = "Search the web"
    Parameters = @{ type = "object"; properties = @{ query = @{ type = "string"; description = "Query" } }; required = @("query") }
}
ConvertTo-ProviderToolSchema -Tools $tool -Provider openai

Converts an agnostic tool definition into the OpenAI tool schema.
#>
function ConvertTo-ProviderToolSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [object[]]$Tools,

        [Parameter(Mandatory)]
        [ValidateSet('openai', 'anthropic')]
        [string]$Provider,

        [switch]$PassThru
    )

    Begin {
        $collectedTools = New-Object System.Collections.Generic.List[object]

        function Get-ToolValue {
            param(
                [Parameter(Mandatory)]
                [object]$Tool,

                [Parameter(Mandatory)]
                [string]$Key
            )

            if ($Tool -is [System.Collections.IDictionary]) {
                foreach ($toolKey in $Tool.Keys) {
                    if ($toolKey -ieq $Key) {
                        return $Tool[$toolKey]
                    }
                }
                return $null
            }

            $property = $Tool.PSObject.Properties | Where-Object { $_.Name -ieq $Key } | Select-Object -First 1
            if ($property) {
                return $property.Value
            }

            return $null
        }
    }

    Process {
        if ($null -ne $Tools) {
            foreach ($tool in $Tools) {
                $collectedTools.Add($tool)
            }
        }
    }

    End {
        $results = @()

        if ($PassThru) {
            return @($collectedTools.ToArray())
        }

        foreach ($tool in $collectedTools) {
            if ($null -eq $tool) {
                continue
            }

            $toolType = Get-ToolValue -Tool $tool -Key 'type'
            if ($toolType -eq 'function') {
                if ($Provider -eq 'openai') {
                    $results += $tool
                    continue
                }
                # For non-OpenAI providers, extract from the function block
                $functionDef = Get-ToolValue -Tool $tool -Key 'function'
                if ($functionDef) {
                    $name = Get-ToolValue -Tool $functionDef -Key 'name'
                    $description = Get-ToolValue -Tool $functionDef -Key 'description'
                    $parameters = Get-ToolValue -Tool $functionDef -Key 'parameters'
                }
                else {
                    Write-Warning "Skipping tool: type is 'function' but no function definition found."
                    continue
                }
            }
            else {
                $name = Get-ToolValue -Tool $tool -Key 'Name'
                $description = Get-ToolValue -Tool $tool -Key 'Description'
                $parameters = Get-ToolValue -Tool $tool -Key 'Parameters'
            }

            if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($description) -or $null -eq $parameters) {
                Write-Warning "Skipping tool because Name, Description, or Parameters is missing."
                continue
            }

            switch ($Provider.ToLower()) {
                'openai' {
                    $results += [ordered]@{
                        type     = 'function'
                        function = [ordered]@{
                            name        = $name
                            description = $description
                            parameters  = $parameters
                        }
                    }
                }
                'anthropic' {
                    $results += [ordered]@{
                        name         = $name
                        description  = $description
                        input_schema = $parameters
                    }
                }
                default {
                    throw "Unsupported provider: $Provider."
                }
            }
        }

        return $results
    }
}
