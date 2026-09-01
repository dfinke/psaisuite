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

## Tool calling and iteration limits

Anthropic models can call registered PowerShell tools. Use `-MaxIterations` to
control how many successive tool-calling rounds are allowed; it defaults to 5.

```powershell
Invoke-ChatCompletion `
	-Messages "Find the files and summarize their contents." `
	-Model "anthropic:claude-3-5-sonnet-20241022" `
	-Tools "Get-ChildItem" `
	-MaxIterations 10
```

Anthropic adaptive thinking can be configured with `-EffortLevel` values of
`low`, `medium`, `high`, `xhigh`, and `max`. The `-SpeedLevel` option accepts
`fast`, `priority`, and `flex`; `flex` maps to standard-only capacity.

```powershell
Invoke-ChatCompletion `
	-Messages "Solve this carefully." `
	-Model "anthropic:claude-sonnet-4-6" `
	-EffortLevel medium `
	-SpeedLevel fast
```
