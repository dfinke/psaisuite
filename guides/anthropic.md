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
Invoke-ChatCompletion -Messages $Message -Model $model
```

```shell
Messages  : {"role":"user","content":"What is the capital of France?"}
Response  : The capital of France is Paris.
Model     : anthropic:claude-3-5-sonnet-20241022
Provider  : anthropic
ModelName : claude-3-5-sonnet-20241022
Timestamp : Sun 03 09 2025 9:23:42 AM
```

## Effort and speed

Anthropic models that support adaptive thinking can receive an effort level through
`output_config.effort`. Supported values are `low`, `medium`, `high`, `xhigh`, and `max`.
The model must support adaptive thinking; older Claude models may reject this option.

```powershell
Invoke-ChatCompletion `
	-Messages "Review this implementation" `
	-Model "anthropic:claude-sonnet-4-6" `
	-EffortLevel high `
	-SpeedLevel fast
```

Anthropic maps `fast` and `priority` to its priority-capable service tier, while `flex`
uses the standard-only tier. The raw response includes the requested levels and the
service tier reported by Anthropic.

When Anthropic handles a request or executes tools, `Invoke-ChatCompletion` displays
timestamped progress for each request round and tool, then closes the progress display
when the response completes.
