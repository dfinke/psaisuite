<#
.SYNOPSIS
    Invokes Vercel AI Gateway using its OpenAI-compatible Chat Completions API.

.DESCRIPTION
    The Invoke-VercelProvider function sends requests to Vercel AI Gateway and
    returns generated text. AI Gateway can route a request to models from
    multiple providers by using a model name such as
    'anthropic/claude-sonnet-4.6'.

.PARAMETER ModelName
    The AI Gateway model name. Use the provider/model format documented by
    Vercel, for example 'openai/gpt-5.6' or 'anthropic/claude-sonnet-4.6'.

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.PARAMETER Tools
    An array of tool definitions for function calling. Strings are resolved as
    PowerShell command names; hashtables can be supplied as provider-neutral or
    OpenAI-compatible tool definitions.

.PARAMETER MaxIterations
    The maximum number of tool-calling rounds allowed before the request stops.

.EXAMPLE
    $message = New-ChatMessage -Prompt 'Explain edge computing in one paragraph.'
    Invoke-VercelProvider -ModelName 'openai/gpt-5.6' -Messages $message

.EXAMPLE
    Invoke-ChatCompletion -Model 'vercel:anthropic/claude-sonnet-4.6' `
        -Messages 'List the files in the current directory.' `
        -Tools Get-ChildItem

.NOTES
    Requires AI_GATEWAY_API_KEY or VERCEL_OIDC_TOKEN to be set. API reference:
    https://vercel.com/docs/ai-gateway/openai-compat/rest-api
#>
function Invoke-VercelProvider {
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

    $apiKey = if ($env:AI_GATEWAY_API_KEY) {
        $env:AI_GATEWAY_API_KEY
    }
    elseif ($env:VERCEL_OIDC_TOKEN) {
        $env:VERCEL_OIDC_TOKEN
    }

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        Write-Error 'Please set the AI_GATEWAY_API_KEY or VERCEL_OIDC_TOKEN environment variable with a valid Vercel AI Gateway credential.'
        return
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

        # AI Gateway follows the OpenAI Chat Completions tool schema.
        $Tools = ConvertTo-ProviderToolSchema -Tools $toolDefinitions -Provider openai
        $allowedToolNames = @(Get-ToolInvocationNames -Tools $Tools)
    }

    $headers = @{
        Authorization = "Bearer $apiKey"
        'Content-Type' = 'application/json'
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

    $uri = 'https://ai-gateway.vercel.sh/v1/chat/completions'
    $iteration = 0

    while ($iteration -lt $MaxIterations) {
        $params = @{
            Uri     = $uri
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
                Write-Error "Vercel AI Gateway API Error (HTTP $statusCode): $errorMessage"
            }
            else {
                Write-Error "Vercel AI Gateway API Error: $errorMessage"
            }

            return "Error calling Vercel AI Gateway: $($_.Exception.Message)"
        }

        if ($response.error) {
            $errorMessage = if ($response.error.message) { $response.error.message } else { $response.error | Out-String }
            Write-Error "Vercel AI Gateway API Error: $errorMessage"
            return "Error: $errorMessage"
        }

        if (-not $response.choices -or @($response.choices).Count -eq 0) {
            return 'No choices in response from Vercel AI Gateway.'
        }

        $assistantMessage = $response.choices[0].message
        $toolCalls = @()
        if ($assistantMessage.tool_calls) {
            $toolCalls = @($assistantMessage.tool_calls)
        }

        if ($toolCalls.Count -gt 0) {
            $body.messages += $assistantMessage

            foreach ($call in $toolCalls) {
                $functionName = $call.function.name
                $functionArgs = @{}

                if ($call.function.arguments) {
                    try {
                        $functionArgs = $call.function.arguments | ConvertFrom-Json -AsHashtable
                    }
                    catch {
                        $functionArgs = @{}
                    }
                }

                try {
                    if ($allowedToolNames.Count -eq 0) {
                        $result = "Error: Tool $functionName was requested but no tools were supplied for this request."
                    }
                    else {
                        $result = Invoke-OpenAIToolExecutor -FunctionName $functionName -FunctionArgs $functionArgs -AllowedToolNames $allowedToolNames
                    }
                }
                catch {
                    $result = "Error executing $functionName`: $($_.Exception.Message)"
                }

                $body.messages += @{
                    role         = 'tool'
                    tool_call_id = $call.id
                    content      = [string]$result
                }
            }

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
            return 'No text content in response from Vercel AI Gateway.'
        }

        return [string]$content
    }

    return "Maximum iterations reached without completing the response after $MaxIterations iterations."
}
