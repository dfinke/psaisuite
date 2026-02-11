<#
.SYNOPSIS
    Invokes the OpenAI API to generate responses using specified models.

.DESCRIPTION
    The Invoke-OpenAIProvider function sends requests to the OpenAI API and returns the generated content.
    It requires an API key to be set in the environment variable 'OpenAIKey'.

.PARAMETER ModelName
    The name of the OpenAI model to use (e.g., 'gpt-4', 'gpt-3.5-turbo').

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.PARAMETER Tools
    An array of tool definitions for function calling. Can be strings (command names) or hashtables.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Write a PowerShell function to calculate factorial'
    $response = Invoke-OpenAIProvider -ModelName 'gpt-4' -Message $Message
    
.EXAMPLE
    $response = Invoke-OpenAIProvider -ModelName 'gpt-4' -Messages $messages -Tools "Get-ChildItem"

.NOTES
    Requires the OpenAIKey environment variable to be set with a valid API key.
    Uses OpenAI's Responses API for all models.
    API Reference: https://platform.openai.com/docs/api-reference/responses
#>
function Invoke-OpenAIProvider {
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
        'Authorization' = "Bearer $env:OpenAIKey"
        'OpenAI-Beta'   = 'responses=v1'
        'content-type'  = 'application/json'
    }
    
    $Uri = "https://api.openai.com/v1/responses"
    
    $body = @{
        'model' = $ModelName
        'input' = $Messages
    }
    # Add tools if provided - convert from Chat Completions format to Responses API format
    if ($Tools) {
        $body['tools'] = @($Tools | ForEach-Object {
                @{
                    type        = 'function'
                    name        = $_.function.name
                    description = $_.function.description
                    parameters  = $_.function.parameters
                }
            })
    }
    
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
            
            # Check if the response contains an error
            if ($response.error) {
                Write-Error $response.error.message
                return "Error: $($response.error.message)"
            }
            
            # Check if output exists
            if (!$response.output) {
                return "No output in response from API."
            }
            
            # Check for function calls in the response output
            $functionCalls = $response.output | Where-Object { $_.type -eq 'function_call' }
            
            if ($functionCalls) {
                # Add all response output items to the input for context
                $body.input += $response.output
                
                # Execute function calls and add results
                foreach ($call in $functionCalls) {
                    $functionName = $call.name
                    $functionArgs = $call.arguments | ConvertFrom-Json -AsHashtable
                    
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
                    
                    $body.input += @{
                        type    = 'function_call_output'
                        call_id = $call.call_id
                        output  = $result | Out-String
                    }
                }
            }
            else {
                # No function calls, extract text from message output items
                # Responses API returns: output[].type='message', output[].content[].type='output_text'
                $textOutput = ($response.output | Where-Object { $_.type -eq 'message' } | ForEach-Object {
                        if ($_.content -is [array]) {
                            ($_.content | Where-Object { $_.type -eq 'output_text' } | ForEach-Object { $_.text }) -join ''
                        }
                        elseif ($_.content) {
                            $_.content
                        }
                    }) -join ''
                if (!$textOutput) {
                    return "No text content in response."
                }
                return $textOutput
            }
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorMessage = $_.ErrorDetails.Message
            Write-Error "OpenAI API Error (HTTP $statusCode): $errorMessage"
            return "Error calling OpenAI API: $($_.Exception.Message)"
        }
        
        $iteration++
    }
    
    return "Maximum iterations reached without completing the response."
}
