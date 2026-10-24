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
        [hashtable]$RegisteredTools,
        [string]$ToolRoot,
        [hashtable]$Policy
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
        $resolvedCommand = $command
        while ($resolvedCommand -is [System.Management.Automation.AliasInfo]) { $resolvedCommand = $resolvedCommand.ResolvedCommand }
        # Reject incomplete parameter sets instead of prompting an unattended loop.
        $usableSet = @($command.ParameterSets | Where-Object {
            $parameterSet = $_
            $missing = @($parameterSet.Parameters | Where-Object { $_.IsMandatory -and -not $argumentsMap.ContainsKey($_.Name) })
            $unknown = @($argumentsMap.Keys | Where-Object { $_ -notin $parameterSet.Parameters.Name })
            $missing.Count -eq 0 -and $unknown.Count -eq 0
        })
        if ($command.ParameterSets.Count -gt 0 -and $usableSet.Count -eq 0) { throw "Arguments for '$Name' do not satisfy a PowerShell parameter set." }
        if (-not $Policy -and $ToolRoot) { $Policy = New-AgentToolPolicy -Root $ToolRoot }
        if ($Policy) {
            $ToolRoot = $Policy.Root
            if ($Policy.BeforeInvoke) {
                $decision = @(& $Policy.BeforeInvoke ([pscustomobject]@{ Name = $Name; Arguments = $argumentsMap; Command = $resolvedCommand; Root = $ToolRoot }))
                if ($decision.Count -ne 1 -or $decision[0] -isnot [bool] -or -not $decision[0]) {
                    throw 'Tool call denied by ToolPolicy.BeforeInvoke.'
                }
            }
        }
        if ($ToolRoot) {
            $isFileTool = $resolvedCommand.Name -in @('Get-ChildItem', 'Get-Content')
            if ($isFileTool -and $resolvedCommand.ModuleName -ne 'Microsoft.PowerShell.Management') {
                throw 'A file-tool name is shadowed by a custom command. Use the built-in cmdlet for directory-scoped access.'
            }
            Push-Location -LiteralPath $ToolRoot -ErrorAction Stop
            try {
                if ($isFileTool) { $execution = Invoke-AgentFileTool -Command $resolvedCommand -Arguments $argumentsMap -Policy $Policy }
                else {
                    $result = Invoke-OpenAITool -FunctionName $Name -FunctionArgs $argumentsMap
                    $execution = [pscustomobject]@{ Output = [string]$result; Failed = [bool]($result -match '^Error(?: executing|:)') }
                }
            }
            finally { Pop-Location }
        }
        else {
            $result = Invoke-OpenAITool -FunctionName $Name -FunctionArgs $argumentsMap
            $execution = [pscustomobject]@{ Output = [string]$result; Failed = [bool]($result -match '^Error(?: executing|:)') }
        }
        if ($Policy -and $Policy.MaxOutputCharacters -gt 0 -and $execution.Output.Length -gt $Policy.MaxOutputCharacters) {
            $execution.Output = $execution.Output.Substring(0, $Policy.MaxOutputCharacters) + "`n[Tool output truncated at $($Policy.MaxOutputCharacters) characters by ToolPolicy; select a smaller query or adjust the policy.]"
        }
        $execution
    }
    catch [System.Management.Automation.PipelineStoppedException] { throw }
    catch {
        $message = "Error executing $($Name): $($_.Exception.Message)"
        if ($Policy -and $Policy.MaxOutputCharacters -gt 0 -and $message.Length -gt $Policy.MaxOutputCharacters) {
            $message = $message.Substring(0, $Policy.MaxOutputCharacters) + "`n[Tool error truncated by ToolPolicy.]"
        }
        [pscustomobject]@{ Output = $message; Failed = $true }
    }
}
