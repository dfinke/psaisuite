# Vercel AI Gateway

PSAISuite's `vercel` provider uses Vercel AI Gateway's OpenAI-compatible Chat
Completions API. One gateway key can route requests to models from multiple
providers. Model names use Vercel's `provider/model` format, while PSAISuite
uses the normal `provider:model` prefix:

```text
vercel:anthropic/claude-sonnet-4.6
vercel:openai/gpt-5.6
```

## Setup

Create an AI Gateway API key in the Vercel dashboard and set it in the process
environment:

```powershell
$env:AI_GATEWAY_API_KEY = "your-vercel-ai-gateway-key"
```

When running inside a Vercel environment, `VERCEL_OIDC_TOKEN` can be used as a
fallback credential:

```powershell
$env:VERCEL_OIDC_TOKEN = "your-vercel-oidc-token"
```

## Create a chat completion

```powershell
Import-Module PSAISuite

$message = New-ChatMessage -Prompt "Explain edge computing in one paragraph."
Invoke-ChatCompletion `
    -Messages $message `
    -Model "vercel:openai/gpt-5.6"
```

The provider sends the request to
`https://ai-gateway.vercel.sh/v1/chat/completions` and returns the assistant's
text. Any model listed in Vercel's AI Gateway model catalog can be selected by
using its `provider/model` name.

## Tool calling

Vercel AI Gateway accepts the same OpenAI function-tool schema used by the
OpenAI provider. PowerShell command names and custom tool definitions are both
supported:

```powershell
Invoke-ChatCompletion `
    -Messages "List the files in the current directory." `
    -Model "vercel:anthropic/claude-sonnet-4.6" `
    -Tools Get-ChildItem `
    -MaxIterations 5
```

`MaxIterations` limits successive tool-calling rounds and defaults to five.
Tool errors are returned to the model as tool output so it can correct an
invalid call or explain the failure.

## Provider routing

AI Gateway can try alternate upstream providers for a model. Provider-specific
options are available through Vercel's API, but the PSAISuite provider keeps the
same portable message and tool interface used by the other PSAISuite providers.
See Vercel's [AI Gateway REST API documentation](https://vercel.com/docs/ai-gateway/openai-compat/rest-api)
for the current model catalog, routing options, and gateway behavior.
