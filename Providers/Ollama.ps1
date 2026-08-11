
<#
.SYNOPSIS
    Invokes the Ollama API to generate responses using specified models.

.DESCRIPTION
    The Invoke-OllamaProvider function sends requests to the Ollama API and returns the generated content.
    Ollama is a local model server that allows you to run models on your own hardware.
    Make sure ollama is running locally using the default port 11434 or set the OLLAMA_HOST environment variable.

.PARAMETER ModelName
    The name of the Ollama model to use (e.g., 'deepseek-r1:latest', deepseek-r1:14b').

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Write a PowerShell function to calculate factorial'
    $response = Invoke-OllamaProvider -ModelName 'deepseek-r1:latest' -Messages $Message
    
.NOTES
    API Reference: https://github.com/ollama/ollama/blob/main/docs/openai.md
#>
function Invoke-OllamaProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages
    )
    
    $headers = @{
        'Authorization' = "Bearer $env:OllamaKey"
        'content-type'  = 'application/json'
    }
    
    $body = @{
        'model'    = $ModelName
        'messages' = $Messages
    }

    if ($env:OLLAMA_HOST) {
        $OllamaBaseUri = $env:OLLAMA_HOST
    }
    else {
        $OllamaBaseUri = "http://localhost:11434"
    }

    try {
        Invoke-RestMethod -Uri "$OllamaBaseUri/" | Out-Null
    }
    catch {
        Write-Error "Error connecting to the Ollama's API, Check if Ollama is running! : $($_.Exception.Message)"
        return "Error connecting to the Ollama's API, Check if Ollama is running! : $($_.Exception.Message)"
    }
    
    $Uri = "$OllamaBaseUri/v1/chat/completions"

    $params = @{
        Uri     = $Uri
        Method  = 'POST'
        Headers = $headers
        Body    = $body | ConvertTo-Json -Depth 10
    }
    
    try {
        $response = Invoke-RestMethod @params
        return $response.choices[0].message.content
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.ErrorDetails.Message
        Write-Error "Ollama API Error (HTTP $statusCode): $errorMessage"
        return "Error calling Ollama API: $($_.Exception.Message)"
    }
}
