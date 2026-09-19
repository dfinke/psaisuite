<#
.SYNOPSIS
    Invokes a user-configured OpenAI-compatible chat completions endpoint.

.DESCRIPTION
    The Invoke-OpenAICompatibleProvider function sends requests to an
    OpenAI-compatible endpoint configured through environment variables and
    returns generated text. This is useful for self-hosted or infrastructure-
    hosted model servers such as vLLM, TGI, or other OpenAI-compatible APIs.

.PARAMETER ModelName
    The model identifier exposed by the configured endpoint.

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.PARAMETER Tools
    An array of tool definitions for function calling. Strings are resolved as
    PowerShell command names; hashtables can be supplied as provider-neutral or
    OpenAI-compatible tool definitions.

.PARAMETER MaxIterations
    The maximum number of tool-calling rounds allowed before the request stops.

.EXAMPLE
    $env:OpenAICompatibleEndpoint = 'http://127.0.0.1:8000/v1'
    Invoke-ChatCompletion -Model 'openaicompatible:meta-llama/Llama-3.1-8B-Instruct' `
        -Messages 'Explain retrieval-augmented generation in one paragraph.'

.NOTES
    Set OpenAICompatibleEndpoint to the base OpenAI-compatible API path (for
    example, https://host.example/v1) or directly to the chat completions URL.
    If the endpoint requires authentication, set OpenAICompatibleKey or
    OPENAI_COMPATIBLE_API_KEY. The key is optional for unauthenticated servers.
#>
function Invoke-OpenAICompatibleProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,

        [Parameter(Mandatory)]
        [hashtable[]]$Messages,

        [object[]]$Tools,

        [ValidateRange(1, 100)]
        [int]$MaxIterations = 5
    )

    if ([string]::IsNullOrWhiteSpace($env:OpenAICompatibleEndpoint)) {
        throw 'Please set the OpenAICompatibleEndpoint environment variable to the base OpenAI-compatible API URL.'
    }

    $allowedToolNames = @()
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
        $allowedToolNames = @(Get-ToolInvocationNames -Tools $Tools)
    }

    $chatCompletionsUri = Get-OpenAICompatibleUri -Endpoint $env:OpenAICompatibleEndpoint -ResourcePath 'chat/completions'

    $apiKey = if ($env:OpenAICompatibleKey) {
        $env:OpenAICompatibleKey
    }
    else {
        $env:OPENAI_COMPATIBLE_API_KEY
    }

    $headers = @{
        'Content-Type' = 'application/json'
    }

    if (-not [string]::IsNullOrWhiteSpace($apiKey)) {
        $headers.Authorization = "Bearer $apiKey"
    }

    $body = [ordered]@{
        model    = $ModelName
        messages = [hashtable[]]$Messages
        stream   = $false
    }

    if ($Tools) {
        $body.tools = @($Tools)
        $body.tool_choice = 'auto'
    }

    $iteration = 0

    while ($iteration -lt $MaxIterations) {
        $params = @{
            Uri     = $chatCompletionsUri
            Method  = 'POST'
            Headers = $headers
            Body    = $body | ConvertTo-Json -Depth 20
        }

        try {
            $response = Invoke-RestMethod @params
        }
        catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode.value__
            }

            $errorMessage = $_.ErrorDetails.Message
            if ([string]::IsNullOrWhiteSpace($errorMessage)) {
                $errorMessage = $_.Exception.Message
            }

            if ($statusCode) {
                $message = "OpenAI-compatible API Error (HTTP $statusCode): $errorMessage"
            }
            else {
                $message = "OpenAI-compatible API Error: $errorMessage"
            }

            Write-Error $message
            throw $message
        }

        if ($response.error) {
            $errorMessage = if ($response.error.message) { $response.error.message } else { $response.error | Out-String }
            $message = "OpenAI-compatible API Error: $errorMessage"
            Write-Error $message
            throw $message
        }

        if (-not $response.choices -or @($response.choices).Count -eq 0) {
            return 'No choices in response from OpenAI-compatible API.'
        }

        $assistantMessage = $response.choices[0].message
        $toolCalls = @()
        if ($assistantMessage.tool_calls) {
            $toolCalls = @($assistantMessage.tool_calls)
        }

        if ($toolCalls.Count -gt 0) {
            $assistantContent = $assistantMessage.content
            if ($assistantContent -is [array]) {
                $assistantContent = ($assistantContent | ForEach-Object {
                        if ($_.text) { $_.text } else { [string]$_ }
                    }) -join ''
            }

            if ([string]::IsNullOrWhiteSpace([string]$assistantContent)) {
                $assistantContent = $null
            }
            else {
                $assistantContent = [string]$assistantContent
            }

            $nextMessages = New-Object 'System.Collections.Generic.List[hashtable]'
            foreach ($message in @($body.messages)) {
                $nextMessages.Add($message)
            }

            $assistantReplayMessage = @{
                role       = if ($assistantMessage.role) { $assistantMessage.role } else { 'assistant' }
                tool_calls = @($toolCalls)
            }

            if ($null -ne $assistantContent) {
                $assistantReplayMessage.content = $assistantContent
            }

            if ($assistantMessage.PSObject.Properties['name']) {
                $assistantReplayMessage.name = $assistantMessage.name
            }

            $nextMessages.Add($assistantReplayMessage)

            foreach ($call in $toolCalls) {
                $functionName = $call.function.name
                $functionArgs = @{}
                $argumentParseError = $null

                if ($call.function.arguments) {
                    try {
                        $functionArgs = $call.function.arguments | ConvertFrom-Json -AsHashtable
                    }
                    catch {
                        $argumentParseError = "Error parsing tool arguments for $functionName`: $($_.Exception.Message)"
                    }
                }

                try {
                    if ($argumentParseError) {
                        $result = $argumentParseError
                    }
                    elseif ($allowedToolNames.Count -eq 0) {
                        $result = "Error: Tool $functionName was requested but no tools were supplied for this request."
                    }
                    else {
                        $result = Invoke-OpenAIToolExecutor -FunctionName $functionName -FunctionArgs $functionArgs -AllowedToolNames $allowedToolNames
                    }
                }
                catch {
                    $result = "Error executing $functionName`: $($_.Exception.Message)"
                }

                $nextMessages.Add(@{
                    role         = 'tool'
                    name         = $functionName
                    tool_call_id = $call.id
                    content      = [string]$result
                })
            }

            $body.messages = [hashtable[]]$nextMessages.ToArray()
            $iteration++
            continue
        }

        $content = $assistantMessage.content
        if ($content -is [array]) {
            $content = ($content | ForEach-Object {
                    if ($_.text) { $_.text } else { [string]$_ }
                }) -join ''
        }

        if ([string]::IsNullOrWhiteSpace([string]$content)) {
            return 'No text content in response from OpenAI-compatible API.'
        }

        return [string]$content
    }

    return "Maximum iterations reached without completing the response after $MaxIterations iterations."
}
