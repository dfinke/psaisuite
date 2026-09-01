<#
.SYNOPSIS
    Invokes the Anthropic API to generate responses using Claude models.

.DESCRIPTION
    The Invoke-AnthropicProvider function sends requests to the Anthropic API and returns the generated content.
    It requires an API key to be set in the environment variable 'AnthropicKey'.

.PARAMETER ModelName
    The name of the Anthropic model to use (e.g., 'claude-3-opus', 'claude-3-sonnet', 'claude-3-haiku').

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.PARAMETER EffortLevel
    The Anthropic adaptive thinking effort level. Supported values are model-dependent.

.PARAMETER SpeedLevel
    The requested processing speed level. Anthropic maps fast and priority requests to
    its priority-capable service tier and flex requests to standard-only capacity.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Summarize the key events of World War II'
    $response = Invoke-AnthropicProvider -ModelName 'claude-3-opus' -Messages $Message
    
.NOTES
    Requires the AnthropicKey environment variable to be set with a valid API key.
    Uses a fixed max_tokens value of 1024.
    Returns content from the 'text' field in the response.
    API Reference: https://docs.anthropic.com/claude/reference/getting-started-with-the-api
#>
function Write-AnthropicActivity {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [int]$Iteration,
        [int]$MaxIterations
    )

    $timestampedMessage = "[$((Get-Date).ToString('o'))] $Message"
    Write-Verbose $timestampedMessage

    $percentComplete = 0
    if ($MaxIterations -gt 0) {
        $percentComplete = [Math]::Min(99, [Math]::Max(0, [int](($Iteration / $MaxIterations) * 100)))
    }

    Write-Progress `
        -Id 9174 `
        -Activity 'Anthropic tool workflow' `
        -Status $timestampedMessage `
        -PercentComplete $percentComplete
}

function Complete-AnthropicActivity {
    Write-Progress -Id 9174 -Activity 'Anthropic tool workflow' -Completed
}

function Invoke-AnthropicProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages,
        [object[]]$Tools,
        [ValidateSet('low', 'medium', 'high', 'xhigh', 'max')]
        [string]$EffortLevel,
        [ValidateSet('auto', 'default', 'flex', 'fast', 'priority')]
        [string]$SpeedLevel
    )

    # Process tools: if strings, register them; then convert to Anthropic schema
    if ($Tools) {
        $toolDefinitions = New-Object System.Collections.Generic.List[object]
        foreach ($tool in $Tools) {
            if ($tool -is [string]) {
                $toolDefinitions.Add((Register-Tool $tool))
            }
            else {
                $toolDefinitions.Add($tool)
            }
        }
        $Tools = ConvertTo-ProviderToolSchema -Tools $toolDefinitions -Provider anthropic
    }
    
    $headers = @{
        'x-api-key'         = $env:AnthropicKey
        'anthropic-version' = '2023-06-01'
        'content-type'      = 'application/json'
    }
    
    $body = @{
        'model'      = $ModelName
        'max_tokens' = 1024  # Hard-coded for Anthropic
    }

    if ($EffortLevel) {
        $body['thinking'] = @{
            type = 'adaptive'
        }
        $body['output_config'] = @{
            effort = $EffortLevel
        }
    }

    if ($SpeedLevel) {
        $body['service_tier'] = switch ($SpeedLevel) {
            'flex' { 'standard_only' }
            default { 'auto' }
        }
    }

    $MessagesList = @()
    foreach ($Msg in $Messages) {
        if ($Msg.role -eq 'system') {
            $body['system'] = $Msg.content
        }
        else {
            $MessagesList += $Msg
        }
    }
    
    $body['messages'] = $MessagesList

    if ($Tools) {
        $body['tools'] = @($Tools)
        $body['tool_choice'] = @{ type = 'auto' }
    }

    if ($env:PSAISUITE_DEBUG_ANTHROPIC -eq '1') {
        $toolCount = if ($Tools) { @($Tools).Count } else { 0 }
        Write-Host "Anthropic tools count: $toolCount"
        Write-Host "Anthropic request body: $($body | ConvertTo-Json -Depth 10)"
    }
        
    $Uri = "https://api.anthropic.com/v1/messages"
    
    $maxIterations = 5
    $iteration = 0

    while ($iteration -lt $maxIterations) {
        $round = $iteration + 1
        Write-AnthropicActivity -Message "Request started (round $round/$maxIterations)" -Iteration $iteration -MaxIterations $maxIterations

        $params = @{
            Uri     = $Uri
            Method  = 'POST'
            Headers = $headers
            Body    = $body | ConvertTo-Json -Depth 10
        }
        
        try {
            $response = Invoke-RestMethod @params

            if ($response.error) {
                Complete-AnthropicActivity
                Write-Error $response.error.message
                return "Error: $($response.error.message)"
            }

            if ($env:PSAISUITE_DEBUG_ANTHROPIC -eq '1') {
                Write-Host "Anthropic stop_reason: $($response.stop_reason)"
                if ($response.content) {
                    Write-Host "Anthropic response content: $($response.content | ConvertTo-Json -Depth 10)"
                }
            }

            if (!$response.content) {
                Complete-AnthropicActivity
                return "No content in response from API."
            }

            $toolUses = @($response.content | Where-Object { $_.type -eq 'tool_use' })
            if ($toolUses.Count -gt 0) {
                Write-AnthropicActivity -Message "Model requested $($toolUses.Count) tool call(s)" -Iteration $iteration -MaxIterations $maxIterations

                $body.messages += @{
                    role    = 'assistant'
                    content = $response.content
                }

                foreach ($call in $toolUses) {
                    $functionName = $call.name
                    $toolStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    Write-AnthropicActivity -Message "Tool started: $functionName" -Iteration $iteration -MaxIterations $maxIterations
                    $functionArgs = @{}
                    if ($call.input) {
                        # Convert PSObject from JSON response to hashtable for splatting
                        foreach ($prop in $call.input.PSObject.Properties) {
                            $functionArgs[$prop.Name] = $prop.Value
                        }
                    }

                    try {
                        if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                            $result = & $functionName @functionArgs
                        }
                        else {
                            $result = "Error: Function $functionName not found"
                        }
                    }
                    catch {
                        $result = "Error: $($_.Exception.Message)"
                    }

                    $toolStopwatch.Stop()
                    Write-AnthropicActivity -Message "Tool completed: $functionName ($($toolStopwatch.ElapsedMilliseconds) ms)" -Iteration $iteration -MaxIterations $maxIterations

                    $body.messages += @{
                        role    = 'user'
                        content = @(
                            @{
                                type        = 'tool_result'
                                tool_use_id = $call.id
                                content     = $result | Out-String
                            }
                        )
                    }
                }
            }
            else {
                $textBlocks = $response.content | Where-Object { $_.type -eq 'text' }
                if ($textBlocks) {
                    $text = ($textBlocks | ForEach-Object { $_.text }) -join ''
                    Write-AnthropicActivity -Message "Response completed (round $round/$maxIterations)" -Iteration $maxIterations -MaxIterations $maxIterations
                    Complete-AnthropicActivity
                    if ($EffortLevel -or $SpeedLevel) {
                        return [PSCustomObject]@{
                            Text                 = $text
                            RequestedEffortLevel = $EffortLevel
                            RequestedSpeedLevel  = $SpeedLevel
                            ReasoningEffort      = if ($response.usage.output_tokens_details) { $EffortLevel } else { $null }
                            ServiceTier          = $response.usage.service_tier
                        }
                    }
                    return $text
                }
                Complete-AnthropicActivity
                return "No text content in response."
            }
        }
        catch {
            Complete-AnthropicActivity
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorMessage = $_.ErrorDetails.Message
            Write-Error "Anthropic API Error (HTTP $statusCode): $errorMessage"
            return "Error calling Anthropic API: $($_.Exception.Message)"
        }

        $iteration++
    }

    Complete-AnthropicActivity
    return "Maximum iterations reached without completing the response."
}
