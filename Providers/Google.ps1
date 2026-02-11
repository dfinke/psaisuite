<#
.SYNOPSIS
    Invokes the Google Gemini API to generate responses using specified models.

.DESCRIPTION
    The Invoke-GoogleProvider function sends requests to the Google Gemini API and returns the generated content.
    It requires an API key to be set in the environment variable 'GeminiKey'.

.PARAMETER ModelName
    The name of the Gemini model to use (e.g., 'gemini-1.0-pro', 'gemini-2.0-flash-exp').
    Note: Use the exact model name as specified by Google without any prefix.

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.PARAMETER Tools
    An array of tool definitions for function calling. Can be strings (command names) or hashtables.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Explain how CRISPR works'
    $response = Invoke-GoogleProvider -ModelName 'gemini-1.5-pro' -Message $Message

.EXAMPLE
    $response = Invoke-GoogleProvider -ModelName 'gemini-2.0-flash' -Messages $messages -Tools "Get-ChildItem"
    
.NOTES
    Requires the GeminiKey environment variable to be set with a valid API key.
    The API key is passed as a URL parameter rather than in the headers.
    API Reference: https://ai.google.dev/gemini-api/docs
#>
function Invoke-GoogleProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages,
        [object[]]$Tools
    )
    
    if (-not $env:GeminiKey) {
        throw "Google Gemini API key not found. Please set the GeminiKey environment variable."
    }
    
    $apiKey = $env:GeminiKey

    # Process tools: if strings, register them; then convert to Google schema
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
        $Tools = ConvertTo-ProviderToolSchema -Tools $toolDefinitions -Provider google
    }
    
    # Build contents array and extract system instruction
    $contents = @()
    $systemInstruction = $null

    foreach ($Msg in $Messages) {
        if ($Msg.role -eq 'system') {
            $systemInstruction = $Msg.content
        }
        elseif ($Msg.role -eq 'user') {
            $contents += @{
                'role'  = 'user'
                'parts' = @(
                    @{
                        'text' = $Msg.content
                    }
                )
            }
        }
        else {
            throw "Invalid message role: $($Msg.role)"
        }
    }
   
    $body = @{
        'contents' = $contents
    }
    
    if ($systemInstruction) {
        $body['system_instruction'] = @{
            'parts' = @(
                @{
                    'text' = $systemInstruction
                }
            )
        }
    }

    if ($Tools) {
        $body['tools'] = @(
            @{
                'function_declarations' = @($Tools)
            }
        )
    }

    $Uri = "https://generativelanguage.googleapis.com/v1beta/models/$($ModelName):generateContent?key=$apiKey"
    
    $maxIterations = 5
    $iteration = 0

    while ($iteration -lt $maxIterations) {
        $params = @{
            Uri     = $Uri
            Method  = 'POST'
            Headers = @{'content-type' = 'application/json' }
            Body    = $body | ConvertTo-Json -Depth 10
        }
        
        try {
            $response = Invoke-RestMethod @params

            if (!$response.candidates) {
                return "No candidates in response from API."
            }

            $candidate = $response.candidates[0]
            $parts = $candidate.content.parts

            # Check for function calls in the response parts
            $functionCalls = @($parts | Where-Object { $_.functionCall })

            if ($functionCalls.Count -gt 0) {
                # Add model response to contents for context
                $body.contents += $candidate.content

                # Execute each function call and collect responses
                $functionResponseParts = @()

                foreach ($fc in $functionCalls) {
                    $call = $fc.functionCall
                    $functionName = $call.name
                    $functionArgs = @{}
                    if ($call.args) {
                        foreach ($prop in $call.args.PSObject.Properties) {
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

                    $responsePart = @{
                        'functionResponse' = @{
                            'name'     = $functionName
                            'response' = @{
                                'result' = $result | Out-String
                            }
                        }
                    }

                    # Pass through the id if present
                    if ($call.id) {
                        $responsePart.functionResponse['id'] = $call.id
                    }

                    $functionResponseParts += $responsePart
                }

                # Add function responses as user content
                $body.contents += @{
                    'role'  = 'user'
                    'parts' = $functionResponseParts
                }
            }
            else {
                # No function calls, extract text from response
                $textParts = $parts | Where-Object { $_.text }
                if ($textParts) {
                    return ($textParts | ForEach-Object { $_.text }) -join ''
                }
                return "No text content in response."
            }
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorMessage = $_.ErrorDetails.Message
            Write-Error "Google Gemini API Error (HTTP $statusCode): $errorMessage"
            return "Error calling Google Gemini API: $($_.Exception.Message)"
        }

        $iteration++
    }

    return "Maximum iterations reached without completing the response."
}
