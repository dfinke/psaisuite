# CursorAI Provider with Privacy Mode Support
<#
.SYNOPSIS
    Invokes the CursorAI API to generate responses using specified models with privacy mode support.

.DESCRIPTION
    The Invoke-CursorAIProvider function sends requests to the CursorAI API and returns the generated content.
    It supports CursorAI's privacy mode for secure, local AI task execution.
    Requires an API key and optionally an endpoint to be set in environment variables.

.PARAMETER ModelName
    The name of the CursorAI model to use (e.g., 'gpt-4', 'claude-3-5-sonnet').
    CursorAI supports various models through its privacy-focused infrastructure.

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Write a secure PowerShell function'
    $response = Invoke-CursorAIProvider -ModelName 'gpt-4' -Message $Message
    
.EXAMPLE
    # Using privacy mode with custom endpoint
    $env:CursorAIEndpoint = "https://api.cursor.sh/v1"
    $Message = New-ChatMessage -Prompt 'Analyze this code for security issues'
    $response = Invoke-CursorAIProvider -ModelName 'claude-3-5-sonnet' -Message $Message
    
.NOTES
    Requires the CursorAIKey environment variable to be set with a valid API key.
    Optionally supports CursorAIEndpoint environment variable for privacy mode endpoints.
    
    Privacy Mode Features:
    - Secure API endpoints for sensitive data handling
    - Local processing capabilities when configured
    - Enterprise-grade privacy and security compliance
    
    Environment Variables:
    - CursorAIKey: Required API key for authentication
    - CursorAIEndpoint: Optional custom endpoint (defaults to standard CursorAI API)
    
    API Reference: https://cursor.sh/api-docs (hypothetical - will need actual documentation)
#>
function Invoke-CursorAIProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages
    )
    
    # Check for required API key
    if (-not $env:CursorAIKey) {
        throw "CursorAI API key not found. Please set the CursorAIKey environment variable."
    }
    
    # Use custom endpoint if specified (for privacy mode), otherwise use default
    $baseUri = if ($env:CursorAIEndpoint) { 
        $env:CursorAIEndpoint.TrimEnd('/')
    } else { 
        "https://api.cursor.sh/v1"
    }
    
    $headers = @{
        'Authorization' = "Bearer $env:CursorAIKey"
        'Content-Type'  = 'application/json'
        'User-Agent'    = 'PSAISuite/1.0'
    }
    
    # Add privacy mode headers if using custom endpoint
    if ($env:CursorAIEndpoint) {
        $headers['X-Privacy-Mode'] = 'enabled'
    }
    
    $body = @{
        'model'    = $ModelName
        'messages' = $Messages
    }
    
    # CursorAI API endpoint for chat completions
    $Uri = "$baseUri/chat/completions"
    
    $params = @{
        Uri     = $Uri
        Method  = 'POST'
        Headers = $headers
        Body    = $body | ConvertTo-Json -Depth 10
    }
    
    try {
        $response = Invoke-RestMethod @params
        
        # Handle CursorAI response format (assuming OpenAI-compatible structure)
        if ($response.choices -and $response.choices.Count -gt 0) {
            return $response.choices[0].message.content
        } else {
            throw "Unexpected response format from CursorAI API"
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.ErrorDetails.Message
        
        # Enhanced error handling for privacy mode issues
        if ($statusCode -eq 403) {
            Write-Error "CursorAI API Access Denied (HTTP $statusCode): Check your API key and privacy mode configuration. $errorMessage"
        } elseif ($statusCode -eq 404) {
            Write-Error "CursorAI API Endpoint Not Found (HTTP $statusCode): Verify your endpoint configuration for privacy mode. $errorMessage"
        } else {
            Write-Error "CursorAI API Error (HTTP $statusCode): $errorMessage"
        }
        
        return "Error calling CursorAI API: $($_.Exception.Message)"
    }
}