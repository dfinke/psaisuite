# CursorAI

CursorAI provides privacy-focused AI interactions with support for local processing and secure API endpoints. To use CursorAI with `psaisuite`, you will need to [create an account with CursorAI](https://cursor.sh/) and obtain an API key. 

**Note:** CursorAI's API details may vary - please consult the official CursorAI documentation for the most current API access information.

## Setup

Once you have your API key, add it to your environment:

```powershell
$env:CursorAIKey = "your-cursorai-api-key"
```

## Privacy Mode Configuration

For enhanced privacy and security, you can configure a custom endpoint:

```powershell
# Optional: Configure custom endpoint for privacy mode
$env:CursorAIEndpoint = "https://your-private-cursor-endpoint/v1"
```

When a custom endpoint is configured, PSAISuite will:
- Use the specified endpoint instead of the default
- Include privacy mode headers in API requests
- Support local processing capabilities (if available through your endpoint)

## Create a Chat Completion

Install `psaisuite` from the PowerShell Gallery:

```powershell
Install-Module PSAISuite
```

In your code:

```powershell
# Import the module
Import-Module PSAISuite

$provider = "cursorai"
$model_id = "gpt-4"  # CursorAI supports various models

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "Write a secure PowerShell function to validate user input"
Invoke-ChatCompletion -Message $Message -Model $model
```

```shell
Messages  : {"role":"user","content":"Write a secure PowerShell function to validate user input"}
Response  : Here's a secure PowerShell function for user input validation...
Model     : cursorai:gpt-4
Provider  : cursorai
ModelName : gpt-4
Timestamp : Thu 06 04 2025 2:15:30 AM
```

## Supported Models

CursorAI supports various models through its privacy-focused infrastructure, including:
- `gpt-4`
- `gpt-3.5-turbo`
- `claude-3-5-sonnet`
- `claude-3-haiku`
- And other models available through Cursor's platform

## Privacy Mode Features

- **Secure API Endpoints**: Custom endpoints for sensitive data handling
- **Local Processing**: Support for local inference when configured
- **Enterprise Privacy**: Compliance with enterprise security requirements
- **Data Protection**: Enhanced privacy controls for sensitive workloads

## Examples

### Basic Usage
```powershell
$message = New-ChatMessage -Prompt "Explain the benefits of privacy-focused AI"
Invoke-ChatCompletion -Message $message -Model "cursorai:gpt-4"
```

### Privacy Mode with Custom Endpoint
```powershell
# Configure privacy mode
$env:CursorAIEndpoint = "https://private.cursor.sh/v1"

$message = New-ChatMessage -Prompt "Analyze this sensitive code for security issues"
Invoke-ChatCompletion -Message $message -Model "cursorai:claude-3-5-sonnet"
```

### Text-Only Response
```powershell
$response = Invoke-ChatCompletion -Message "Write a brief privacy policy" -Model "cursorai:gpt-4" -TextOnly
Write-Host $response
```

## Troubleshooting

### Common Issues

1. **API Key Not Found**: Ensure the `CursorAIKey` environment variable is set correctly
2. **Endpoint Configuration**: Verify custom endpoints are accessible and properly formatted
3. **Model Availability**: Check that the specified model is available through your CursorAI account

### Error Messages

- `CursorAI API key not found`: Set the `$env:CursorAIKey` environment variable
- `API Endpoint Not Found`: Verify your custom endpoint configuration
- `Access Denied`: Check your API key permissions and account status