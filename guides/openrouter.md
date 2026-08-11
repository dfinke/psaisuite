# OpenRouter

To use OpenRouter with `psaisuite` you will need to [create an account](https://openrouter.ai/). After logging in, go to the [API Keys](https://openrouter.ai/settings/keys) section in your account settings and generate a new key. Once you have your key, add it to your environment as follows:
```shell
$env:OpenRouterKey = "your-openrouter-api-key"
```

## List of Available AI Model

Here are a few examples of models you can use with this provider

- mistral/ministral-8b
- deepseek/deepseek-chat-v3-0324
- openai/o1-pro
- google/gemini-2.5-pro-preview-03-25

More can be found in this link: https://openrouter.ai/models

## Create a Chat Completion

Install `psaisuite` from the PowerShell Gallery.

```powershell
Install-Module PSAISuite
```

In your code:

```powershell
# Import the module
Import-Module PSAISuite

$provider = "OpenRouter"
$model_id = "mistral/ministral-8b"

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Messages $Message -Model $model
```

```shell
Messages  : {"role":"user","content":"What is the capital of France?"}
Response  : The capital of France is Paris. Paris is known for its iconic landmarks such as the Eiffel Tower, the Louvre Museum, and Notre-Dame Cathedral. It is also the largest city in France.
Model     : OpenRouter:mistral/ministral-8b
Provider  : openrouter
ModelName : mistral/ministral-8b
Timestamp : 4/5/2025 12:56:05 PM
```
