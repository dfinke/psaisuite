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

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Summarize the key events of World War II'
    $response = Invoke-AnthropicProvider -ModelName 'claude-3-opus' -Message $Message
    
.NOTES
    Requires the AnthropicKey environment variable to be set with a valid API key.
    Uses a fixed max_tokens value of 1024.
    Returns content from the 'text' field in the response.
    API Reference: https://docs.anthropic.com/claude/reference/getting-started-with-the-api
#>
function Invoke-AnthropicProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages,
        [object[]]$Tools
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
        $params = @{
            Uri     = $Uri
            Method  = 'POST'
            Headers = $headers
            Body    = $body | ConvertTo-Json -Depth 10
        }
        
        try {
            $response = Invoke-RestMethod @params

            if ($response.error) {
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
                return "No content in response from API."
            }

            $toolUses = @($response.content | Where-Object { $_.type -eq 'tool_use' })
            if ($toolUses.Count -gt 0) {
                $body.messages += @{
                    role    = 'assistant'
                    content = $response.content
                }

                foreach ($call in $toolUses) {
                    $functionName = $call.name
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
                    return ($textBlocks | ForEach-Object { $_.text }) -join ''
                }
                return "No text content in response."
            }
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorMessage = $_.ErrorDetails.Message
            Write-Error "Anthropic API Error (HTTP $statusCode): $errorMessage"
            return "Error calling Anthropic API: $($_.Exception.Message)"
        }

        $iteration++
    }

    return "Maximum iterations reached without completing the response."
}
