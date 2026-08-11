# xAI

To use xAI with `psaisuite` you will need an [API key](https://console.x.ai/). Generate a new key and once you have your key, add it to your environment as follows:

```shell
$env:XAIKey = "your-xai-api-key"
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

$provider = "xai"
$model_id = "grok-beta"

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Messages $Message -Model $model
```

```shell
Messages  : {"role":"user","content":"What is the capital of France?"}
Response  : The capital of France is **Paris**.
Model     : xai:grok-beta
Provider  : xai
ModelName : grok-beta
Timestamp : Sun 03 09 2025 9:28:17 AM
```

Happy coding! If you’d like to contribute, please read our [Contributing Guide](CONTRIBUTING.md).
