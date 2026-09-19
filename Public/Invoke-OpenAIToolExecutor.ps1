function Invoke-OpenAIToolExecutor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FunctionName,

        [hashtable]$FunctionArgs = @{},

        [string[]]$AllowedToolNames = @()
    )

    if ($AllowedToolNames -notcontains $FunctionName) {
        return "Error: Function $FunctionName is not allowed"
    }

    $resolvedCommand = Get-Command -Name $FunctionName -CommandType Cmdlet, Function, ExternalScript, Application -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $FunctionName } |
        Select-Object -First 1

    if (-not $resolvedCommand) {
        return "Error: Function $FunctionName not found"
    }

    $normalizedArgs = @{}
    foreach ($argumentName in @($FunctionArgs.Keys)) {
        $argumentValue = $FunctionArgs[$argumentName]
        $parameter = $resolvedCommand.Parameters[$argumentName]

        if (-not $parameter) {
            continue
        }

        $isMandatory = @($parameter.Attributes | Where-Object {
                $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory
            }).Count -gt 0

        if (-not $isMandatory -and $argumentValue -is [string] -and [string]::IsNullOrWhiteSpace($argumentValue)) {
            continue
        }

        if (-not $isMandatory -and
            $parameter.ParameterType -eq [System.Management.Automation.SwitchParameter] -and
            $argumentValue -eq $false) {
            continue
        }

        $invalidRange = $false
        if (-not $isMandatory) {
            foreach ($range in @($parameter.Attributes | Where-Object {
                        $_ -is [System.Management.Automation.ValidateRangeAttribute]
                    })) {
                try {
                    if ($argumentValue -lt $range.MinRange -or $argumentValue -gt $range.MaxRange) {
                        $invalidRange = $true
                        break
                    }
                }
                catch {
                    # Let PowerShell report non-numeric conversion errors normally.
                }
            }
        }

        if ($invalidRange) {
            continue
        }

        $normalizedArgs[$argumentName] = $argumentValue
    }

    $toolOutput = @(& $resolvedCommand @normalizedArgs 2>&1)
    $toolErrors = @($toolOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    $toolValues = @($toolOutput | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })

    if ($toolErrors.Count -gt 0) {
        $errorText = ($toolErrors | ForEach-Object {
                if ($_.Exception -and $_.Exception.Message) { $_.Exception.Message }
                else { $_ | Out-String }
            }) -join '; '
        $result = "Error executing $FunctionName`: $errorText"

        if ($toolValues.Count -gt 0) {
            $result += "`nPartial output:`n$($toolValues | Out-String)"
        }

        return $result.TrimEnd()
    }

    if ($toolOutput.Count -eq 0) {
        return '(no output)'
    }

    return ($toolOutput | Out-String).TrimEnd()
}
