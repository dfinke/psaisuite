<#
.SYNOPSIS
    Invokes the OpenRouter API to generate responses using specified models.

.DESCRIPTION
    The Invoke-OpenRouterProvider function sends requests to the OpenRouter API and returns the generated content.
    It requires an API key to be set in the environment variable 'OpenRouterKey'.

.PARAMETER ModelName
    The name of the OpenRouter model to use (e.g., 'google/gemini-2.5-pro-preview-03-25', 'openai/gpt-4o').

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Write a PowerShell function to calculate factorial'
    $response = Invoke-OpenRouterProvider -ModelName 'openrouter:google/gemini-2.5-pro-preview-03-25' -Messages $Message
    
.NOTES
    Requires the OpenRouterKey environment variable to be set with a valid API key.
    API Reference: https://openrouter.ai/docs/api-reference/overview
#>
function Invoke-OpenRouterProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages
    )
    
    $headers = @{
        'Authorization' = "Bearer $env:OpenRouterKey"        
        'content-type'  = 'application/json'
    }
    
    $body = @{
        'model'    = $ModelName
        'messages' = $Messages
    }

    $Uri = "https://openrouter.ai/api/v1/chat/completions"
    
    $params = @{
        Uri     = $Uri
        Method  = 'POST'
        Headers = $headers
        Body    = $body | ConvertTo-Json -Depth 10
    }
    
    try {
        $response = Invoke-RestMethod @params
        if($response.Error) {
            Write-Error "OpenRouter API Error: $($response.Error)"
            return "Error calling OpenRouter API: $($response.Error)"
        }
        return $response.choices[0].message.content
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.ErrorDetails.Message
        Write-Error "OpenRouter API Error (HTTP $statusCode): $errorMessage"
        return "Error calling OpenRouter API: $($_.Exception.Message)"
    }
}
