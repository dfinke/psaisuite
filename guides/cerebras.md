# Cerebras

To use Cerebras with `psaisuite` you will need to [create an account](https://cloud.cerebras.ai/). Once logged in, go to the [API Keys](https://cloud.cerebras.ai/platform/apikeys) section and generate a new API key. Once you have your key, add it to your environment as follows:

```shell
$env:CEREBRAS_API_KEY = "your-cerebras-api-key"
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

$provider = "cerebras"
$model_id = "llama3.1-8b"

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Message $Message -Model $model
```

```shell
Messages  : {"role":"user","content":"What is the capital of France?"}
Response  : The capital of France is Paris.
Model     : cerebras:llama3.1-8b
Provider  : cerebras
ModelName : llama3.1-8b
Timestamp : Thu 31 07 2026 12:00:00 PM
```
