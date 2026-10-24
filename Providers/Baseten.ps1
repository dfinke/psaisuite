<#
.SYNOPSIS
    Invokes the Baseten API to generate responses using specified models.

.DESCRIPTION
    The Invoke-BasetenProvider function sends requests to the Baseten OpenAI-compatible
    inference API and returns the generated content. It requires an API key to be set
    in the environment variable 'BASETEN_API_KEY'.

.PARAMETER ModelName
    The name of the Baseten model to use (e.g., 'openai/gpt-oss-120b').

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.PARAMETER Tools
    An array of tool definitions for function calling. Can be strings (command names)
    or hashtables.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'In a single line, who and what are you?'
    $response = Invoke-BasetenProvider -ModelName 'openai/gpt-oss-120b' -Messages $Message

.EXAMPLE
    $response = Invoke-BasetenProvider -ModelName 'openai/gpt-oss-120b' -Messages $messages -Tools "Get-ChildItem"

.NOTES
    Requires the BASETEN_API_KEY environment variable to be set with a valid Baseten API key.
    API Reference: https://docs.baseten.co/reference/openai-model-api
#>
function Invoke-BasetenProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages,
        [object[]]$Tools
    )

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

    if (-not $env:BASETEN_API_KEY) {
        Write-Error "Please set the BASETEN_API_KEY environment variable with a valid Baseten API key."
        return
    }

    $headers = @{
        'Authorization' = "******"
        'Content-Type'  = 'application/json'
    }

    $body = @{
        model    = $ModelName
        messages = [hashtable[]]$Messages
    }

    if ($Tools) {
        $body['tools'] = $Tools
    }

    $uri = 'https://inference.baseten.co/v1/chat/completions'

    $maxIterations = 5
    $iteration = 0

    while ($iteration -lt $maxIterations) {
        $params = @{
            Uri     = $uri
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
            Write-Error "Baseten API Error (HTTP $statusCode): $errorMessage"
            return "Error calling Baseten API: $($_.Exception.Message)"
        }

        $iteration++
    }

    return "Maximum iterations reached without completing the response."
}
