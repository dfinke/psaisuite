<#
.SYNOPSIS
    Invokes the Cerebras API to generate responses using specified models.

.DESCRIPTION
    The Invoke-CerebrasProvider function sends requests to the Cerebras API and returns the generated content.
    It requires an API key to be set in the environment variable 'CEREBRAS_API_KEY'.

.PARAMETER ModelName
    The name of the Cerebras model to use (e.g., 'llama3.1-8b', 'llama3.1-70b').
    List of models: https://inference-docs.cerebras.ai/

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Explain quantum computing in simple terms'
    $response = Invoke-CerebrasProvider -ModelName 'llama3.1-8b' -Messages $Message

.NOTES
    Requires the CEREBRAS_API_KEY environment variable to be set with a valid API key.
    API Reference: https://inference-docs.cerebras.ai/
#>
function Invoke-CerebrasProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages
    )

    $headers = @{
        'Authorization' = "Bearer $env:CEREBRAS_API_KEY"
        'Content-Type'  = 'application/json'
    }

    $body = @{
        'model'    = $ModelName
        'messages' = $Messages
    }

    $Uri = "https://api.cerebras.ai/v1/chat/completions"

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
        Write-Error "Cerebras API Error (HTTP $statusCode): $errorMessage"
        return "Error calling Cerebras API: $($_.Exception.Message)"
    }
}
