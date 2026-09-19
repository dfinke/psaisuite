<#
.SYNOPSIS
    Invokes Together AI using its OpenAI-compatible Chat Completions API.

.DESCRIPTION
    The Invoke-TogetherProvider function sends requests to Together AI and
    returns generated text. Together models keep PSAISuite's normal
    provider-prefixed model format, for example 'together:openai/gpt-oss-20b'.

.PARAMETER ModelName
    The Together model identifier, such as 'openai/gpt-oss-20b'.

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
    Invoke-TogetherProvider -ModelName 'openai/gpt-oss-20b' -Messages $message

.EXAMPLE
    Invoke-ChatCompletion -Model 'together:openai/gpt-oss-20b' `
        -Messages 'List the files in the current directory.' `
        -Tools Get-ChildItem

.NOTES
    Requires TOGETHER_API_KEY to be set. API reference:
    https://docs.together.ai/docs/inference/openai-compatibility
#>
function Invoke-TogetherProvider {
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

    if ([string]::IsNullOrWhiteSpace($env:TOGETHER_API_KEY)) {
        Write-Error 'Please set the TOGETHER_API_KEY environment variable with a valid Together AI API key.'
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

        $Tools = ConvertTo-ProviderToolSchema -Tools $toolDefinitions -Provider openai
    }

    $headers = @{
        Authorization = "******"
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

    $uri = 'https://api.together.xyz/v1/chat/completions'
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
                Write-Error "Together AI API Error (HTTP $statusCode): $errorMessage"
            }
            else {
                Write-Error "Together AI API Error: $errorMessage"
            }

            return "Error calling Together AI: $($_.Exception.Message)"
        }

        if ($response.error) {
            $errorMessage = if ($response.error.message) { $response.error.message } else { $response.error | Out-String }
            Write-Error "Together AI API Error: $errorMessage"
            return "Error: $errorMessage"
        }

        if (-not $response.choices -or @($response.choices).Count -eq 0) {
            return 'No choices in response from Together AI.'
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
                    if (Get-Command Invoke-OpenAITool -ErrorAction SilentlyContinue) {
                        $result = Invoke-OpenAITool -FunctionName $functionName -FunctionArgs $functionArgs
                    }
                    elseif (Get-Command $functionName -ErrorAction SilentlyContinue) {
                        $result = & $functionName @functionArgs | Out-String
                    }
                    else {
                        $result = "Error: Function $functionName not found"
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
            return 'No text content in response from Together AI.'
        }

        return [string]$content
    }

    return "Maximum iterations reached without completing the response after $MaxIterations iterations."
}
