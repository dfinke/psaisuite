# DeepSeek

PSAISuite uses DeepSeek's **Responses API** for text generation and local
PowerShell function calling. It sends full conversation history on each
request; DeepSeek does not store the conversation for later continuation.

## Setup

Set your existing DeepSeek credential:

```powershell
$env:DeepSeekKey = 'your-deepseek-api-key'
Import-Module PSAISuite
```

Command-name tools use `Register-Tool`, provided by the **PSAI** module.
Install it with `Install-Module PSAI` if it is not already available.
Prebuilt function schemas can be supplied without that registration dependency.

Use `-Model deepseek:` and tab completion to select a model from the live
catalog. Current examples use `deepseek-flash`; `deepseek-v4-pro` is also
documented by DeepSeek. Availability follows the provider's model catalog.

## Text and pipeline context

```powershell
Invoke-ChatCompletion 'Explain this error.' -Model deepseek:deepseek-flash

Get-Content ./README.md |
    Invoke-ChatCompletion -Messages 'Summarize this file.' -Model deepseek:deepseek-flash
```

## Give the model PowerShell tools

```powershell
New-AgentHarness 'Read the files and identify the top customer.' `
    -Model deepseek:deepseek-flash `
    -Tools Get-ChildItem, Get-Content, Get-Date `
    -MaxIterations 5 -Verbose
```

The model requests a function; PSAISuite runs it locally and sends its output
back to DeepSeek. It repeats until there is a final answer or the request
limit is reached. Tools run with your PowerShell session's permissions.
Only the supplied tool names may run. Malformed JSON, unknown arguments,
missing required arguments, and incomplete PowerShell parameter sets are
returned as tool errors without executing the command.

Custom functions work too:

```powershell
function Get-ServiceSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)
    Get-Service -Name $Name | Select-Object Name, Status
}

New-AgentHarness 'Check the Spooler service.' -Model deepseek:deepseek-flash -Tools Get-ServiceSummary
```

`-Tools` also accepts provider-neutral schemas (`Name`, `Description`,
`Parameters`), OpenAI Chat Completions function schemas, and flat Responses
function schemas. The named command must exist in the current session.

## Interactive conversations

```powershell
New-AgentHarness -Model deepseek:deepseek-flash -Tools Get-Date, Get-ChildItem, Get-Content
```

Enter prompts with `Read-Host`; enter `exit`, `quit`, or an empty line to
finish. DeepSeek's full Responses history, including reasoning and tool
exchanges, is retained for follow-up questions during this invocation.
`-PassThru` returns the editable harness object instead; each
`GetResponse(prompt)` call on that object still starts a fresh conversation.

## Thinking, progress, and limits

`Invoke-ChatCompletion -EffortLevel` maps `none` to thinking disabled,
`minimal/low` to low, `medium/high/xhigh` to high, and `max` to max.
Omitting the parameter uses the API's default. `SpeedLevel` is not supported.

`MaxIterations` limits model requests, including tool rounds and the final
answer; it is not a token budget. An incomplete API response is reported
explicitly, and no tools from that incomplete response run. API failures and
exhausted request limits are terminating errors.

PowerShell progress shows waiting, request rounds, tool starts/completions,
and failures. `-Verbose` retains the activity log; the returned answer remains
plain text. These updates happen at request/tool boundaries rather than
streaming live thinking or answer tokens.

## Explicit continuation with Raw

```powershell
$first = Invoke-ChatCompletion 'What is the date?' -Model deepseek:deepseek-flash -Tools Get-Date -Raw
$next = @($first.Conversation) + @(@{ role = 'user'; content = 'What year is that?' })
Invoke-ChatCompletion -Messages $next -Model deepseek:deepseek-flash -Tools Get-Date
```

`-Raw` adds `Conversation`, the replayable Responses input items. Keep the
history with the same model and tool definitions. This includes reasoning and
tool results; treat it as conversation data, rather than a display transcript.
The implementation does not use `previous_response_id` or server-side storage.

## Validation

These explicit checks make real API calls using the configured credentials:

```powershell
pwsh -NoProfile -File ./__tests__/Test-DeepSeekResponsesLive.ps1
pwsh -NoProfile -File ./__tests__/Test-AgentHarnessLive.ps1 -Model deepseek:deepseek-flash
pwsh -NoProfile -File ./__tests__/Test-AgentProgressLive.ps1 -Models deepseek:deepseek-flash
```

References: [Responses API](https://api-docs.deepseek.com/guides/responses_api/),
[tool calling](https://api-docs.deepseek.com/guides/tool_calls/), and
[thinking mode](https://api-docs.deepseek.com/guides/thinking_mode/).
