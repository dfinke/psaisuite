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

Supported effort values are `none`, `minimal`, `low`, `medium`, `high`, `xhigh`,
and `max`; availability depends on the selected OpenAI model.

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

## System instructions

Pass system or developer messages alongside the user message. The OpenAI
provider moves those messages into the Responses API `instructions` field so
they remain instruction-level context across tool-calling rounds:

```powershell
$messages = @(
    @{ role = 'system'; content = @(@{ type = 'input_text'; text = 'Use standard Markdown links such as [label](path.md).' }) }
    @{ role = 'developer'; content = 'Keep the response concise.' }
    @{ role = 'user'; content = 'Create an index of the project.' }
)

Invoke-ChatCompletion `
    -Messages $messages `
    -Model 'openai:gpt-5.6'
```

For tool-calling workflows, set `-MaxIterations` to allow more successive
tool calls:

```powershell
$result = Invoke-ChatCompletion `
    -Messages "Find the files and summarize their contents." `
    -Model "openai:gpt-5.6" `
    -Tools "Get-ChildItem" `
    -MaxIterations 10 `
    -Raw
```

When using tools, `-MaxIterations` controls how many tool-calling rounds are
allowed before the request stops. It defaults to 5 and can be increased for
workflows that require several successive tool calls.

## Project instructions

When an `AGENTS.md` file exists in the project root or an applicable
directory above the current location, the OpenAI provider loads it automatically
as project guidance.
The provider checks for new or changed `AGENTS.md` files after each tool round,
so a file created during the current run is available on the next model turn.
If an instruction file is removed, it is also removed from the next request.

The provider reports request, tool, and instruction-refresh activity through
PowerShell progress output. Use `-Verbose` with `Invoke-ChatCompletion` for
timestamped diagnostic messages. Tool failures are returned to the model as
function output so it can correct invalid paths or arguments.
