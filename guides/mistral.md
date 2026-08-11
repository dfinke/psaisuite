# Mistral

To use Mistral with `psaisuite` you will need to [create an account](https://console.mistral.ai/) and obtain an API key. Once logged in, go to the [API Keys](https://console.mistral.ai/api-keys/) section and create a new API key. Once you have your key, add it to your environment as follows:

```shell
$env:MistralKey = "your-mistral-api-key"
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

$provider = "mistral"
$model_id = "mistral-medium"

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Messages $Message -Model $model
```

```shell
Messages  : {"role":"user","content":"What is the capital of France?"}
Response  : The capital of France is Paris.
Model     : mistral:mistral-medium
Provider  : mistral
ModelName : mistral-medium
Timestamp : Sun 03 09 2025 9:45:30 AM
```
