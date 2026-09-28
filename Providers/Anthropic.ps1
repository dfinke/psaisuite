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

.PARAMETER MaxIterations
    The maximum number of tool-calling rounds allowed before the request stops.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Summarize the key events of World War II'
    $response = Invoke-AnthropicProvider -ModelName 'claude-3-opus' -Messages $Message

.NOTES
    Requires the AnthropicKey environment variable to be set with a valid API key.
    Uses a max_tokens value of 4096, shared by thinking and response text.
    Reports truncated responses before executing any incomplete tool calls.
    Returns content from the 'text' field in the response.
    API Reference: https://docs.anthropic.com/claude/reference/getting-started-with-the-api
#>
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
        [string]$SpeedLevel,
        [ValidateRange(1, 100)]
        [int]$MaxIterations = 5
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
        'max_tokens' = 4096  # Includes thinking as well as response text
    }

    if ($EffortLevel) {
        $body['thinking'] = @{ type = 'adaptive' }
        $body['output_config'] = @{ effort = $EffortLevel }
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

    $iteration = 0
    $activity = New-AgentActivity -Provider 'Anthropic' -Model $ModelName -MaxIterations $MaxIterations

    try {
        while ($iteration -lt $MaxIterations) {
            Write-AgentActivity -Activity $activity -Message 'Waiting for response' -Round ($iteration + 1)
            $params = @{
                Uri     = $Uri
                Method  = 'POST'
                Headers = $headers
                Body    = $body | ConvertTo-Json -Depth 10
            }

            try {
                $response = Invoke-RestMethod @params

                if ($response.error) {
                    Write-AgentActivity -Activity $activity -Message 'Request failed: provider returned an error' -Completed
                    Write-Error $response.error.message
                    return "Error: $($response.error.message)"
                }

                if ($env:PSAISUITE_DEBUG_ANTHROPIC -eq '1') {
                    Write-Host "Anthropic stop_reason: $($response.stop_reason)"
                    if ($response.content) {
                        Write-Host "Anthropic response content: $($response.content | ConvertTo-Json -Depth 10)"
                    }
                }

                # Thinking counts against max_tokens, even when its text is hidden.
                # A truncated response can also contain incomplete tool arguments;
                # do not execute tools or return partial code as a finished answer.
                if ($response.stop_reason -eq 'max_tokens') {
                    Write-AgentActivity -Activity $activity -Message "Stopped: output token limit reached (max_tokens=$($body.max_tokens), including thinking)" -Completed
                    return "Anthropic response exceeded the output token limit (max_tokens=$($body.max_tokens), including thinking). The response is incomplete; no tool calls from this response were executed."
                }

                if (!$response.content) {
                    Write-AgentActivity -Activity $activity -Message 'Request failed: no content in response' -Completed
                    return "No content in response from API."
                }

                $toolUses = @($response.content | Where-Object { $_.type -eq 'tool_use' })
                if ($toolUses.Count -gt 0) {
                    Write-AgentActivity -Activity $activity -Message "Model requested $($toolUses.Count) tool call(s)"
                    $body.messages += @{
                        role    = 'assistant'
                        content = $response.content
                    }

                    foreach ($call in $toolUses) {
                        $functionName = $call.name
                        $toolStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                        Write-AgentActivity -Activity $activity -Message "Tool started: $functionName"
                        $functionArgs = @{}
                        if ($call.input) {
                            # Convert PSObject from JSON response to hashtable for splatting
                            foreach ($prop in $call.input.PSObject.Properties) {
                                $functionArgs[$prop.Name] = $prop.Value
                            }
                        }

                        $toolFailed = $false
                        try {
                            if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                                $result = @(& $functionName @functionArgs 2>&1)
                                $toolFailed = @($result | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count -gt 0
                            }
                            else {
                                $toolFailed = $true
                                $result = "Error: Function $functionName not found"
                            }
                        }
                        catch {
                            $toolFailed = $true
                            $result = "Error: $($_.Exception.Message)"
                        }

                        $toolStopwatch.Stop()
                        $toolStatus = if ($toolFailed) { 'Tool failed' } else { 'Tool completed' }
                        Write-AgentActivity -Activity $activity -Message "$toolStatus`: $functionName ($($toolStopwatch.ElapsedMilliseconds) ms)"

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
                        Write-AgentActivity -Activity $activity -Message 'Response completed' -Completed
                        if ($EffortLevel -or $SpeedLevel) {
                            return [PSCustomObject]@{
                                Text                 = $text
                                MaxIterations        = $MaxIterations
                                RequestedEffortLevel = $EffortLevel
                                RequestedSpeedLevel  = $SpeedLevel
                                ReasoningEffort      = if ($response.usage.output_tokens_details) { $EffortLevel } else { $null }
                                ServiceTier          = $response.usage.service_tier
                            }
                        }
                        return $text
                    }
                    Write-AgentActivity -Activity $activity -Message 'Request failed: no text in response' -Completed
                    return "No text content in response."
                }
            }
            catch {
                Write-AgentActivity -Activity $activity -Message 'Request failed' -Completed
                $statusCode = $_.Exception.Response.StatusCode.value__
                $errorMessage = $_.ErrorDetails.Message
                Write-Error "Anthropic API Error (HTTP $statusCode): $errorMessage"
                return "Error calling Anthropic API: $($_.Exception.Message)"
            }

            $iteration++
        }

        Write-AgentActivity -Activity $activity -Message 'Stopped: maximum iterations reached' -Completed
        return "Maximum iterations reached without completing the response after $MaxIterations iterations."
    }
    finally {
        Write-AgentActivity -Activity $activity -Message 'Request stopped' -Completed
    }
}
