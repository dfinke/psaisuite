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

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Write a PowerShell function to calculate factorial'
    $response = Invoke-OpenAIProvider -ModelName 'gpt-4' -Message $Message
    
.NOTES
    Requires the OpenAIKey environment variable to be set with a valid API key.
    Includes 'assistants=v2' beta header for compatibility with newer API features.
    API Reference: https://platform.openai.com/docs/api-reference
#>
function Invoke-OpenAIProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages
    )
    
    $headers = @{
        'Authorization' = "Bearer $env:OpenAIKey"        
        'content-type'  = 'application/json'
    }
    
    # Convert messages to string prompt for Responses API
    $prompt = ($Messages | Where-Object { $_.role -eq 'user' } | ForEach-Object { $_.content }) -join "`n"
    
    $body = @{
        'model' = $ModelName
        'input' = $prompt
    }

    $Uri = "https://api.openai.com/v1/responses"
    
    $params = @{
        Uri     = $Uri
        Method  = 'POST'
        Headers = $headers
        Body    = $body | ConvertTo-Json -Depth 10
    }
    
    try {
        $response = Invoke-RestMethod @params
        # For Responses API, find the message output and extract text
        if ($response.status -eq "completed" -and $response.output) {
            $messageOutput = $response.output | Where-Object { $_.type -eq "message" } | Select-Object -First 1
            if ($messageOutput -and $messageOutput.content -and $messageOutput.content[0].text) {
                return $messageOutput.content[0].text
            }
        }
        return "No text content found in response. Full response: $($response | ConvertTo-Json -Depth 5)"
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.ErrorDetails.Message
        Write-Error "OpenAI API Error (HTTP $statusCode): $errorMessage"
        return "Error calling OpenAI API: $($_.Exception.Message)"
    }
}
