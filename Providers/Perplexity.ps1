<#
.SYNOPSIS
    Invokes the Perplexity API to generate responses using specified models.

.DESCRIPTION
    The Invoke-PerplexityProvider function sends requests to the Perplexity API and returns the generated content.
    It requires an API key to be set in the environment variable 'PerplexityKey'.

.PARAMETER ModelName
    The name of the Perplexity model to use (e.g., 'llama-3-sonar-small-32k', 'sonar-medium-online', 'mistral-7b-instruct').

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Write a PowerShell function to calculate factorial'
    $response = Invoke-PerplexityProvider -ModelName 'sonar-medium-online' -Messages $Message
    
.NOTES
    Requires the PerplexityKey environment variable to be set with a valid API key.
    API Reference: https://docs.perplexity.ai/reference/post_chat_completions
#>
function Invoke-PerplexityProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages
    )
    
    $headers = @{
        'Authorization' = "Bearer $env:PerplexityKey"        
        'content-type'  = 'application/json'
    }
    
    $body = @{
        'model'    = $ModelName
        'messages' = $Messages
    }

    $Uri = "https://api.perplexity.ai/chat/completions"
    
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
        Write-Error "Perplexity API Error (HTTP $statusCode): $errorMessage"
        return "Error calling Perplexity API: $($_.Exception.Message)"
    }
}
