# Baseten

Baseten Model APIs expose an OpenAI-compatible interface for chat completions and
model discovery.

## Getting Started

Create a Baseten API key and set it in your PowerShell session:

```powershell
$env:BASETEN_API_KEY = "your-baseten-api-key"
```

---

## Tab Completion

The PSAISuite module registers an argument completer that retrieves model names
from Baseten's `/v1/models` endpoint. If model completion is empty, verify that
`$env:BASETEN_API_KEY` is set correctly and that your Baseten account can access
the selected model.

---

## Create a Chat Completion

```powershell
Import-Module PSAISuite

$model = 'baseten:openai/gpt-oss-120b'
$message = New-ChatMessage -Prompt 'Explain Baseten in one line'
Invoke-ChatCompletion -Messages $message -Model $model
```

---

## Tool Calling

Baseten uses the same OpenAI-compatible tool schema pattern as other compatible
PSAISuite providers. Pass PowerShell function names or explicit tool definitions
through the `-Tools` parameter when the selected model supports tool calling.

---

## See Also

- [PSAISuite Usage Guide](../README.md)
