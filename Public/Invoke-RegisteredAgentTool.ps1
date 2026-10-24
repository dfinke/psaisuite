# Internal guard around the existing normalized PowerShell tool executor.
function Invoke-RegisteredAgentTool {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Name,
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Arguments,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable]$RegisteredTools
    )

    try {
        if (-not $RegisteredTools.ContainsKey($Name)) { throw "Tool '$Name' was not registered for this request." }
        $json = if ([string]::IsNullOrWhiteSpace($Arguments)) { '{}' } else { $Arguments.Trim() }
        if (-not $json.StartsWith('{') -or -not $json.EndsWith('}')) { throw 'Tool arguments must be a JSON object.' }
        $parsed = ConvertFrom-Json -InputObject $json -ErrorAction Stop
        $argumentsMap = @{}
        $schema = $RegisteredTools[$Name]
        $propertyNames = if ($schema.properties -is [System.Collections.IDictionary]) {
            @($schema.properties.Keys)
        }
        else { @($schema.properties.PSObject.Properties.Name) }
        foreach ($property in $parsed.PSObject.Properties) {
            if ($property.Name -notin $propertyNames) { throw "Unknown argument '$($property.Name)' for tool '$Name'." }
            $argumentsMap[$property.Name] = $property.Value
        }
        foreach ($required in $schema.required) {
            if (-not $argumentsMap.ContainsKey($required)) { throw "Missing required argument '$required' for tool '$Name'." }
        }
        $command = Get-Command -Name $Name -ErrorAction Stop
        # Reject incomplete parameter sets instead of prompting an unattended loop.
        $usableSet = @($command.ParameterSets | Where-Object {
            $parameterSet = $_
            $missing = @($parameterSet.Parameters | Where-Object { $_.IsMandatory -and -not $argumentsMap.ContainsKey($_.Name) })
            $unknown = @($argumentsMap.Keys | Where-Object { $_ -notin $parameterSet.Parameters.Name })
            $missing.Count -eq 0 -and $unknown.Count -eq 0
        })
        if ($command.ParameterSets.Count -gt 0 -and $usableSet.Count -eq 0) { throw "Arguments for '$Name' do not satisfy a PowerShell parameter set." }
        $result = Invoke-OpenAITool -FunctionName $Name -FunctionArgs $argumentsMap
        [pscustomobject]@{ Output = [string]$result; Failed = [bool]($result -match '^Error(?: executing|:)') }
    }
    catch [System.Management.Automation.PipelineStoppedException] { throw }
    catch { [pscustomobject]@{ Output = "Error executing $($Name): $($_.Exception.Message)"; Failed = $true } }
}
