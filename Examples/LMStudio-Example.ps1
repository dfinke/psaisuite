# Example usage of LM Studio provider with PSAISuite
# Make sure LM Studio is running on your local machine before running this script

# Import the module
Import-Module PSAISuite

# Example 1: Basic usage with default settings
# This will try to connect to http://localhost:1234
$message = New-ChatMessage -Prompt "Write a simple PowerShell function to get the current date"
$response = Invoke-ChatCompletion -Messages $message -Model "lmstudio:your-model-name"
Write-Host "Response:" -ForegroundColor Green
Write-Host $response

# Example 2: Using custom LM Studio URL
$env:LMSTUDIO_API_URL = "http://localhost:1234"  # or your custom URL
$message = "Explain what PowerShell is in one sentence"
$response = Invoke-ChatCompletion -Messages $message -Model "lmstudio:your-model-name"
Write-Host "`nWith custom URL:" -ForegroundColor Green
Write-Host $response

# Example 3: Using API key (if your LM Studio instance requires authentication)
$env:LMSTUDIO_API_KEY = "your-api-key-here"
$message = @{role = "user"; content = "What is the capital of France?"}
$response = Invoke-ChatCompletion -Messages @($message) -Model "lmstudio:your-model-name"
Write-Host "`nWith API key:" -ForegroundColor Green
Write-Host $response

# Example 4: Using pipeline input
"Explain this PowerShell code" | Invoke-ChatCompletion -Messages "Get-Process | Where-Object {$_.CPU -gt 10}" -Model "lmstudio:your-model-name"