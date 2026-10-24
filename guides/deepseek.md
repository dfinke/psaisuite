# DeepSeek

Starting in **PSAISuite v0.10.0**, DeepSeek uses the **Responses API** for text generation and local
PowerShell function calling. It sends full conversation history on each
request; DeepSeek does not store the conversation for later continuation.

## Migrating from v0.9.x

The provider now calls `/responses` instead of `/v1/chat/completions`.
Your `DeepSeekKey` credential and normal text-returning commands stay the same.
Choose a currently available model with tab completion instead of relying on
older `deepseek-chat` or `deepseek-coder` examples. API failures, incomplete
responses, and exhausted request limits now raise terminating errors.

File tools default to the starting folder. Use ToolRoot when the files are in
another directory. For manual follow-ups, reuse the full Conversation from
Raw output so reasoning and tool results are preserved.

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

### Directory scope and execution policy

File tools default to the directory where you start the request. An empty
folder produces an empty result; it does not authorize searching elsewhere.
Choose another directory explicitly when needed:

```powershell
New-AgentHarness 'Read the files and summarize them.' `
    -Model deepseek:deepseek-flash -Tools Get-ChildItem, Get-Content `
    -ToolRoot 'D:\data\sales'
```

The boundary is enforced in the local tool runner for the built-in
`Get-ChildItem` and `Get-Content` commands and their aliases. Relative paths
resolve under ToolRoot. Paths outside it, other PowerShell providers, and
symlinks/junctions are rejected. Recursion is supported in trees without links.
This does not sandbox arbitrary custom functions, which retain the session's
permissions. Other providers currently reject ToolRoot and ToolPolicy rather
than silently suggesting they enforce the same boundary.

Policy is separate from model reasoning. DeepSeek is the first adapter wired
to the reusable tool policy; new models use the same execution interface.
You can tune the defaults or add a permission callback for your own tools:

```powershell
$policy = @{
    MaxReadBytes = 20MB
    MaxOutputCharacters = 0 # Unlimited; the caller decides the budget.
    BeforeInvoke = {
        param($call)
        # Receives Name, Arguments, resolved CommandInfo, and Root.
        $call.Command.Name -ne 'Remove-Item'
    }
}
New-AgentHarness 'Read the files.' -Model deepseek:deepseek-flash `
    -Tools Get-ChildItem, Get-Content -ToolRoot 'D:\data' -ToolPolicy $policy
```

BeforeInvoke must return exactly one Boolean decision; false or an exception
denies the call. It can govern custom tools too. The model does not receive or
modify this callback. Tool registration still determines which tools exist.

| Option | Default | Meaning |
|---|---:|---|
| MaxReadBytes | 1 MiB | Combined size of files selected by one Get-Content call |
| MaxOutputCharacters | 20,000 | Text returned to the model per tool result |
| MaxListedItems | 1,000 | Items returned by one directory listing |
| MaxScanEntries | 4,096 | Entries inspected before a recursive listing |
| MaxFilePaths | 100 | Paths selected by one file-tool call |

Each numeric option accepts zero for unlimited. Truncation is labelled in the
tool result. Get-Content -Wait, alternate data streams, and wildcard directory
segments require a purpose-built tool; leaf filename wildcards are supported.

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
Invoke-ChatCompletion -Messages $next -Model deepseek:deepseek-flash -Tools Get-Date -ToolRoot $first.ToolRoot
```

`-Raw` adds `Conversation`, the replayable Responses input items. Keep the
history with the same model and tool definitions. This includes reasoning and
tool results; treat it as conversation data, rather than a display transcript.
The implementation does not use `previous_response_id` or server-side storage.
Raw results also include ToolRoot and IterationsUsed. Harnesses pin their
starting root across interactive turns and GetResponse calls; caller directory
changes do not silently expand the scope. Keep any custom ToolPolicy with the
conversation when continuing it manually.

## Validation

These explicit checks make real API calls using the configured credentials:

```powershell
pwsh -NoProfile -File ./__tests__/Test-DeepSeekResponsesLive.ps1
pwsh -NoProfile -File ./__tests__/Test-AgentHarnessLive.ps1 -Model deepseek:deepseek-flash
pwsh -NoProfile -File ./__tests__/Test-AgentProgressLive.ps1 -Models deepseek:deepseek-flash
```

The filesystem/policy checks use real tools and temporary files without API calls:

```powershell
pwsh -NoProfile -File ./__tests__/Test-AgentFileBoundary.ps1
```

References: [Responses API](https://api-docs.deepseek.com/guides/responses_api/),
[tool calling](https://api-docs.deepseek.com/guides/tool_calls/), and
[thinking mode](https://api-docs.deepseek.com/guides/thinking_mode/).
