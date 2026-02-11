<#
.SYNOPSIS
    Invokes the xAI API to generate responses using specified models.

.DESCRIPTION
    The Invoke-XAIProvider function sends requests to the xAI API and returns the generated content.
    It requires an API key to be set in the environment variable 'xAIKey'.

.PARAMETER ModelName
    The name of the xAI model to use (e.g., 'grok-1').

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.PARAMETER Tools
    An array of tool definitions for function calling. Can be strings (command names) or hashtables.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Explain quantum computing'
    $response = Invoke-XAIProvider -ModelName 'grok-1' -Message $Message
    
.NOTES
    Requires the xAIKey environment variable to be set with a valid API key.
    API Reference: https://docs.x.ai/
#>
function Invoke-XAIProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages,
        [object[]]$Tools
    )

    # Process tools: if strings, register them; then convert to provider schema
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
        $Tools = ConvertTo-ProviderToolSchema -Tools $toolDefinitions -Provider openai
    }
    
    $headers = @{
        'Authorization' = "Bearer $env:xAIKey"
        'content-type'  = 'application/json'
    }
    
    $body = @{
        'model'    = $ModelName
        'messages' = $Messages
    }

    if ($Tools) {
        $body['tools'] = $Tools
    }

    $Uri = "https://api.x.ai/v1/chat/completions"
    
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

            if (!$response.choices -or $response.choices.Count -eq 0) {
                return "No choices in response from API."
            }

            $assistantMessage = $response.choices[0].message

            if ($assistantMessage.tool_calls) {
                $body.messages += $assistantMessage

                foreach ($call in $assistantMessage.tool_calls) {
                    $functionName = $call.function.name
                    $functionArgs = @{}
                    if ($call.function.arguments) {
                        $functionArgs = $call.function.arguments | ConvertFrom-Json -AsHashtable
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
                        role         = 'tool'
                        tool_call_id = $call.id
                        content      = $result | Out-String
                    }
                }
            }
            else {
                $content = $assistantMessage.content
                if ($content -is [array]) {
                    $content = ($content | ForEach-Object { $_.text }) -join ''
                }

                if (!$content) {
                    return "No text content in response."
                }

                return $content
            }
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorMessage = $_.ErrorDetails.Message
            Write-Error "xAI API Error (HTTP $statusCode): $errorMessage"
            return "Error calling xAI API: $($_.Exception.Message)"
        }

        $iteration++
    }

    return "Maximum iterations reached without completing the response."
}
