# Example of using function calling with xAI provider

# Import the module
Import-Module ../PSAISuite.psd1

# Define a simple PowerShell function that the model can call
function Get-CurrentWeather {
    param(
        [Parameter(Mandatory)]
        [string]$location,
        
        [Parameter()]
        [string]$unit = "celsius"
    )
    
    # This is a mock implementation - in a real application, this would call a weather API
    $weatherData = @{
        location = $location
        temperature = if ($unit -eq "celsius") { 22 } else { 72 }
        conditions = "Partly Cloudy"
        humidity = "45%"
        unit = $unit
    }
    
    return $weatherData | ConvertTo-Json
}

# Define the function schema for the AI model in OpenAI format
$functionDefinitions = @(
    @{
        "name" = "Get-CurrentWeather"
        "description" = "Get the current weather in a location"
        "parameters" = @{
            "type" = "object"
            "properties" = @{
                "location" = @{
                    "type" = "string"
                    "description" = "The city and state, e.g. San Francisco, CA"
                }
                "unit" = @{
                    "type" = "string"
                    "enum" = @("celsius", "fahrenheit")
                    "description" = "The unit of temperature to use. Default is celsius."
                }
            }
            "required" = @("location")
        }
    }
)

# Create a user message
$userMessage = @{
    'role' = 'user'
    'content' = "What's the weather like in Seattle?"
}

# Call the xAI provider with function definitions
Write-Host "Calling xAI with function definitions..." -ForegroundColor Yellow

# Note: This requires xAIKey environment variable to be set
$response = Invoke-ChatCompletion -Messages $userMessage -Model xAI:grok-3-fast -Functions $functionDefinitions

Write-Host "Response:" -ForegroundColor Green
$response

# The response will include function call details if the model decided to call a function
# In a real application, you could examine:
# - If $response.FunctionCall exists, the model wants to call a function
# - The actual response is in $response.Response

Write-Host "`nNote: This example requires the xAI provider and API key to be configured." -ForegroundColor Yellow
Write-Host "If it's not configured, you'll see an error message." -ForegroundColor Yellow