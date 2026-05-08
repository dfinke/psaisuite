# Anthropic 

To use Anthropic with `psaisuite` you will need to [create an account](https://console.anthropic.com/login). Once logged in, go to the [API Keys](https://console.anthropic.com/settings/keys)
and click the "Create Key" button and export that key into your environment.

```shell
$env:AnthropicKey = "your-anthropic-api-key"
```

## Create a Chat Completion

Install `psaisuite` from the PowerShell Gallery.

```powershell
Install-Module PSAISuite
```

In your code:

```powershell
# Import the module
Import-Module PSAISuite

$provider = "anthropic"
$model_id = "claude-3-5-sonnet-20241022"

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Message $Message -Model $model
```

```shell
Messages  : {"role":"user","content":"What is the capital of France?"}
Response  : The capital of France is Paris.
Model     : anthropic:claude-3-5-sonnet-20241022
Provider  : anthropic
ModelName : claude-3-5-sonnet-20241022
Timestamp : Sun 03 09 2025 9:23:42 AM
```
