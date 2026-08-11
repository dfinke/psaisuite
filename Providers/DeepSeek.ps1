<#
.SYNOPSIS
    Invokes the DeepSeek API to generate responses using specified models.

.DESCRIPTION
    The Invoke-DeepSeekProvider function sends requests to the DeepSeek API and returns the generated content.
    It requires an API key to be set in the environment variable 'DeepSeekKey'.

.PARAMETER ModelName
    The name of the DeepSeek model to use (e.g., 'deepseek-chat', 'deepseek-coder').

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Write a binary search algorithm in Python'
    $response = Invoke-DeepSeekProvider -ModelName 'deepseek-coder' -Messages $Message
    
.NOTES
    Requires the DeepSeekKey environment variable to be set with a valid API key.
    API Reference: https://platform.deepseek.com/docs
#>
function Invoke-DeepSeekProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages
    )
    
    $headers = @{
        'Authorization' = "Bearer $env:DeepSeekKey"
        'content-type'  = 'application/json'
    }
    
    $body = @{
        'model'    = $ModelName
        'messages' = [hashtable[]]$Messages
    }

    $Uri = "https://api.deepseek.com/v1/chat/completions"
    
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
        Write-Error "DeepSeek API Error (HTTP $statusCode): $errorMessage"
        return "Error calling DeepSeek API: $($_.Exception.Message)"
    }
}
