<#
.SYNOPSIS
    Invokes the LM Studio API to generate responses using specified models.

.DESCRIPTION
    The Invoke-LMStudioProvider function sends requests to the LM Studio API and returns the generated content.
    LM Studio is a local model server that allows you to run models on your own hardware.
    Make sure LM Studio is running locally using the default port 1234 or set the LMSTUDIO_API_URL environment variable.

.PARAMETER ModelName
    The name of the LM Studio model to use (e.g., 'lmstudio-community/Meta-Llama-3.1-8B-Instruct-GGUF').

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Write a PowerShell function to calculate factorial'
    $response = Invoke-LMStudioProvider -ModelName 'lmstudio-community/Meta-Llama-3.1-8B-Instruct-GGUF' -Message $Message
    
.NOTES
    API Reference: https://lmstudio.ai/docs/api
    Uses the OpenAI-compatible /v1/chat/completions endpoint.
    Set LMSTUDIO_API_URL environment variable to override the default URL (http://localhost:1234).
    Set LMSTUDIO_API_KEY environment variable if your LM Studio instance requires authentication.
#>
function Invoke-LMStudioProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages
    )
    
    $headers = @{
        'content-type' = 'application/json'
    }
    
    # Add API key if available
    if ($env:LMSTUDIO_API_KEY) {
        $headers['Authorization'] = "Bearer $env:LMSTUDIO_API_KEY"
    }
    
    $body = @{
        'model'    = $ModelName
        'messages' = $Messages
    }

    # Use environment variable or default to localhost:1234
    if ($env:LMSTUDIO_API_URL) {
        $LMStudioBaseUri = $env:LMSTUDIO_API_URL
    }
    else {
        $LMStudioBaseUri = "http://localhost:1234"
    }

    # Test connectivity to LM Studio
    try {
        Invoke-RestMethod -Uri "$LMStudioBaseUri/" -TimeoutSec 5 | Out-Null
    }
    catch {
        Write-Error "Error connecting to LM Studio API at $LMStudioBaseUri. Check if LM Studio is running! : $($_.Exception.Message)"
        return "Error connecting to LM Studio API at $LMStudioBaseUri. Check if LM Studio is running! : $($_.Exception.Message)"
    }
    
    $Uri = "$LMStudioBaseUri/v1/chat/completions"

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
        Write-Error "LM Studio API Error (HTTP $statusCode): $errorMessage"
        return "Error calling LM Studio API: $($_.Exception.Message)"
    }
}