<#
.SYNOPSIS
    Invokes the Azure AI Foundry API to generate responses using specified models.

.DESCRIPTION
    The Invoke-AzureAIProvider function sends requests to the Azure AI Foundry API and returns the generated content.
    It requires an API key to be set in the environment variable 'AzureAIKey' and an endpoint URL in 'AzureAIEndpoint'.
    Supports Azure OpenAI deployment endpoints as well as Azure AI Foundry model endpoints, including Microsoft MAI models.

.PARAMETER ModelName
    The name of the Azure AI model to use (e.g., 'gpt-4', 'gpt-35-turbo'). 
    Models available depend on your deployment configuration in Azure AI Studio.

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Explain quantum computing'
    $response = Invoke-AzureAIProvider -ModelName 'gpt-4' -Messages $Message

.EXAMPLE
    $response = Invoke-AzureAIProvider -ModelName 'MAI-DS-R1' -Messages $Message
    
.NOTES
    Requires the AzureAIKey environment variable to be set with a valid API key.
    Requires the AzureAIEndpoint environment variable to be set with your Azure AI endpoint.
    API Reference: https://learn.microsoft.com/en-us/azure/ai-services/openai/
#>
function Invoke-AzureAIProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages
    )
    
    if (-not $env:AzureAIKey) {
        throw "Azure AI API key not found. Please set the AzureAIKey environment variable."
    }
    
    if (-not $env:AzureAIEndpoint) {
        throw "Azure AI endpoint not found. Please set the AzureAIEndpoint environment variable."
    }
    
    $apiKey = $env:AzureAIKey
    $endpoint = $env:AzureAIEndpoint.TrimEnd('/')
    
    $body = @{
        'messages'              = $Messages
        'max_completion_tokens' = 800
    }
    
    if ($endpoint -match '/openai/v1$') {
        $Uri = "$endpoint/chat/completions"
        $body['model'] = $ModelName
    }
    elseif ($endpoint -match '\.services\.ai\.azure\.com(?:/models)?$') {
        if ($endpoint -match '/models$') {
            $baseEndpoint = $endpoint
        }
        else {
            $baseEndpoint = "$endpoint/models"
        }
        $Uri = "$baseEndpoint/chat/completions?api-version=2024-05-01-preview"
        $body['model'] = $ModelName
    }
    else {
        # Determine API version based on the model
        $apiVersion = "2023-05-15"
        # Special handling for o3-mini model which requires a newer API version
        if ($ModelName -eq "o3-mini") {
            $apiVersion = "2024-12-01-preview"
        }
        $Uri = "$endpoint/openai/deployments/$ModelName/chat/completions?api-version=$apiVersion"
    }
    
    $params = @{
        Uri     = $Uri
        Method  = 'POST'
        Headers = @{
            'api-key'      = $apiKey
            'Content-Type' = 'application/json'
        }
        Body    = $body | ConvertTo-Json -Depth 10
    }
    
    try {
        $response = Invoke-RestMethod @params
        # Azure OpenAI has a response structure similar to OpenAI
        return $response.choices[0].message.content
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.ErrorDetails.Message
        Write-Error "Azure AI API Error (HTTP $statusCode): $errorMessage"
        return "Error calling Azure AI API: $($_.Exception.Message)"
    }
}
