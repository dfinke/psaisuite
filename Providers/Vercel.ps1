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
        $activity = New-AgentActivity -Provider 'Vercel' -Model $ModelName -MaxIterations $MaxIterations
        Write-AgentActivity -Activity $activity -Message 'Request failed: Vercel AI Gateway credential is missing' -Completed
        Write-Error 'Please set the AI_GATEWAY_API_KEY or VERCEL_OIDC_TOKEN environment variable with a valid Vercel AI Gateway credential.'
        return
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

        # AI Gateway follows the OpenAI Chat Completions tool schema.
        $Tools = ConvertTo-ProviderToolSchema -Tools $toolDefinitions -Provider openai
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
    $activity = New-AgentActivity -Provider 'Vercel' -Model $ModelName -MaxIterations $MaxIterations

    try {
        while ($iteration -lt $MaxIterations) {
            Write-AgentActivity -Activity $activity -Message 'Waiting for response' -Round ($iteration + 1)
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

                Write-AgentActivity -Activity $activity -Message 'Request failed' -Completed

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
                Write-AgentActivity -Activity $activity -Message 'Request failed: provider returned an error' -Completed
                Write-Error "Vercel AI Gateway API Error: $errorMessage"
                return "Error: $errorMessage"
            }

            if (-not $response.choices -or @($response.choices).Count -eq 0) {
                Write-AgentActivity -Activity $activity -Message 'Request failed: no choices in response' -Completed
                return 'No choices in response from Vercel AI Gateway.'
            }

            $assistantMessage = $response.choices[0].message
            $toolCalls = @()
            if ($assistantMessage.tool_calls) {
                $toolCalls = @($assistantMessage.tool_calls)
            }

            if ($toolCalls.Count -gt 0) {
                Write-AgentActivity -Activity $activity -Message "Model requested $($toolCalls.Count) tool call(s)"
                $body.messages += $assistantMessage

                foreach ($call in $toolCalls) {
                    $functionName = $call.function.name
                    $functionArgs = @{}
                    $toolStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    Write-AgentActivity -Activity $activity -Message "Tool started: $functionName"

                    if ($call.function.arguments) {
                        try {
                            $functionArgs = $call.function.arguments | ConvertFrom-Json -AsHashtable
                        }
                        catch {
                            $functionArgs = @{}
                        }
                    }

                    $toolFailed = $false
                    try {
                        if (Get-Command Invoke-OpenAITool -ErrorAction SilentlyContinue) {
                            $result = Invoke-OpenAITool -FunctionName $functionName -FunctionArgs $functionArgs
                            $toolFailed = ([string]$result) -match '^Error(?: executing|:)'
                        }
                        elseif (Get-Command $functionName -ErrorAction SilentlyContinue) {
                            $toolResult = @(& $functionName @functionArgs 2>&1)
                            $toolFailed = @($toolResult | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count -gt 0
                            $result = $toolResult | Out-String
                        }
                        else {
                            $toolFailed = $true
                            $result = "Error: Function $functionName not found"
                        }
                    }
                    catch {
                        $toolFailed = $true
                        $result = "Error executing $functionName`: $($_.Exception.Message)"
                    }

                    $toolStopwatch.Stop()
                    $toolStatus = if ($toolFailed) { 'Tool failed' } else { 'Tool completed' }
                    Write-AgentActivity -Activity $activity -Message "$toolStatus`: $functionName ($($toolStopwatch.ElapsedMilliseconds) ms)"

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
                Write-AgentActivity -Activity $activity -Message 'Request failed: no text in response' -Completed
                return 'No text content in response from Vercel AI Gateway.'
            }

            Write-AgentActivity -Activity $activity -Message 'Response completed' -Completed
            return [string]$content
        }

        Write-AgentActivity -Activity $activity -Message 'Stopped: maximum iterations reached' -Completed
        return "Maximum iterations reached without completing the response after $MaxIterations iterations."
    }
    finally {
        Write-AgentActivity -Activity $activity -Message 'Request stopped' -Completed
    }
}
