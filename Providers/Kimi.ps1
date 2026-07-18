<#
.SYNOPSIS
    Invokes the Kimi Code API to generate responses using specified models.

.DESCRIPTION
    The Invoke-KimiProvider function sends requests to Kimi Code's OpenAI-compatible
    chat completions endpoint and returns generated content. It requires an API key
    in the KIMI_API_KEY environment variable.

.PARAMETER ModelName
    The Kimi Code model identifier, such as 'k3' or 'kimi-for-coding'.

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.PARAMETER Tools
    An array of tool definitions for function calling. Can be strings (command names)
    or hashtables.

.NOTES
    Kimi Code requires reasoning_content to be preserved when returning tool results
    while thinking is enabled. This provider appends the complete assistant message
    from the API response before sending tool output.
#>
function Invoke-KimiProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,

        [Parameter(Mandatory)]
        [hashtable[]]$Messages,

        [object[]]$Tools
    )

    if (-not $env:KIMI_API_KEY) {
        throw "Kimi Code API key not found. Please set the KIMI_API_KEY environment variable."
    }

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

    $module = Get-Module -Name PSAISuite
    $moduleVersion = if ($module -and $module.Version) { $module.Version } else { 'unknown' }

    $headers = @{
        'Authorization' = "Bearer $env:KIMI_API_KEY"
        'Content-Type'  = 'application/json'
        'User-Agent'    = "PSAISuite/$moduleVersion"
    }

    $body = @{
        model    = $ModelName
        messages = [hashtable[]]$Messages
    }

    if ($Tools) {
        $body['tools'] = $Tools
    }

    $uri = 'https://api.kimi.com/coding/v1/chat/completions'
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

            if (-not $response.choices -or $response.choices.Count -eq 0) {
                return 'No choices in response from API.'
            }

            $assistantMessage = $response.choices[0].message

            if ($assistantMessage.tool_calls) {
                # Preserve every property returned by Kimi, including reasoning_content.
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

                if (-not $content) {
                    return 'No text content in response.'
                }

                return $content
            }
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorMessage = $_.ErrorDetails.Message
            Write-Error "Kimi Code API Error (HTTP $statusCode): $errorMessage"
            return "Error calling Kimi Code API: $($_.Exception.Message)"
        }

        $iteration++
    }

    return 'Maximum iterations reached without completing the response.'
}
