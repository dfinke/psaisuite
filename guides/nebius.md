# Nebius

To use Nebius with `psaisuite` you will need to [create an account](https://console.nebius.ai/) and obtain an API key. Once you have your key, add it to your environment as follows:

```shell
$env:NebiusKey = "your-nebius-api-key"
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

$provider = "nebius"
$model_id = "meta-llama/Llama-3.3-70B-Instruct"

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Messages $Message -Model $model
```

```shell
Messages  : {"role":"user","content":"What is the capital of France?"}
Response  : The capital of France is Paris.
Model     : nebius:meta-llama/Llama-3.3-70B-Instruct
Provider  : nebius
ModelName : meta-llama/Llama-3.3-70B-Instruct
Timestamp : Mon 03 10 2025 10:26:34 PM
```
