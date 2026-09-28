# Together AI

PSAISuite's `together` provider uses Together AI's OpenAI-compatible Chat
Completions API. Model identifiers keep PSAISuite's normal
`provider:model-name` shape:

```text
together:openai/gpt-oss-20b
together:meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo
```

## Setup

Create a Together AI API key and set it in your PowerShell session:

```powershell
$env:TOGETHER_API_KEY = "your-together-ai-api-key"
```

## Create a chat completion

```powershell
Import-Module PSAISuite

$message = New-ChatMessage -Prompt "Explain mixture-of-experts models in one paragraph."
Invoke-ChatCompletion `
    -Messages $message `
    -Model "together:openai/gpt-oss-20b"
```

## Tool calling

Together uses the same OpenAI-compatible tool schema as other compatible
providers, so PowerShell commands and custom tool definitions both work:

```powershell
Invoke-ChatCompletion `
    -Messages "List the files in the current directory." `
    -Model "together:openai/gpt-oss-20b" `
    -Tools Get-ChildItem
```

The Together model completer queries `GET https://api.together.xyz/v1/models`
and surfaces the returned model IDs after you type `together:` and press `Tab`.
If you do not see model completions, verify that `TOGETHER_API_KEY` is set in
your current session.
