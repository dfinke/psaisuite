# OpenAI

To use OpenAI with `psaisuite` you will need to [create an account](https://platform.openai.com/). After logging in, go to the [API Keys](https://platform.openai.com/api-keys) section in your account settings and generate a new key. Once you have your key, add it to your environment as follows:

```shell
$env:OpenAIKey = "your-openai-api-key"
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

$provider = "openai"
$model_id = "gpt-4o"

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Messages $Message -Model $model
```

```shell
Messages  : {"role":"user","content":"What is the capital of France?"}
Response  : The capital of France is Paris.
Model     : openai:gpt-4o
Provider  : openai
ModelName : gpt-4o
Timestamp : Sun 03 09 2025 9:56:29 AM
```

## Effort and speed levels

OpenAI requests can optionally use Codex-style effort and speed levels. These
options are currently supported only by the OpenAI provider and are omitted
from the request when they are not specified.

```powershell
$message = New-ChatMessage -Prompt "Solve this carefully."

$result = Invoke-ChatCompletion `
    -Messages $message `
    -Model "openai:gpt-5.6" `
    -EffortLevel low `
    -SpeedLevel fast `
    -Raw

# Values requested by the caller
$result.EffortLevel
$result.SpeedLevel

# Effective values reported by the OpenAI Responses API
$result.ReasoningEffort
$result.ServiceTier
```

The normal output remains response text. Use `-Raw` to inspect the requested
levels and the effective `ReasoningEffort` and `ServiceTier` returned by OpenAI.
