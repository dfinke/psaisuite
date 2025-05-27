<#
.SYNOPSIS
    Invokes the xAI API to generate responses using specified models.

.DESCRIPTION
    The Invoke-XAIProvider function sends requests to the xAI API and returns the generated content.
    It requires an API key to be set in the environment variable 'xAIKey'.
    Supports function calling when the Functions parameter is provided.

.PARAMETER ModelName
    The name of the xAI model to use (e.g., 'grok-1').

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.PARAMETER Functions
    Optional. An array of function definitions that the model can call.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Explain quantum computing'
    $response = Invoke-XAIProvider -ModelName 'grok-1' -Message $Message
    
.NOTES
    Requires the xAIKey environment variable to be set with a valid API key.
    API Reference: https://docs.x.ai/
#>
function Invoke-XAIProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages,
        [Parameter()]
        [array]$Functions
    )
    
    $headers = @{
        'Authorization' = "Bearer $env:xAIKey"
        'content-type'  = 'application/json'
    }
    
    $body = @{
        'model'    = $ModelName
        'messages' = $Messages
    }

    # Add functions to the request if provided
    if ($Functions) {
        $body['functions'] = $Functions
    }

    $Uri = "https://api.x.ai/v1/chat/completions"
    
    $params = @{
        Uri     = $Uri
        Method  = 'POST'
        Headers = $headers
        Body    = $body | ConvertTo-Json -Depth 10
    }
    
    try {
        $response = Invoke-RestMethod @params
        
        # Check if the response contains a function call
        $message = $response.choices[0].message
        if ($message.PSObject.Properties.Name -contains 'function_call') {
            # Return the entire message object including function_call
            return $message
        }
        else {
            # Return just the content for backward compatibility
            return $message.content
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.ErrorDetails.Message
        Write-Error "xAI API Error (HTTP $statusCode): $errorMessage"
        return "Error calling xAI API: $($_.Exception.Message)"
    }
}
