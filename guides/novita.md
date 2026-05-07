# Novita

Novita is a cloud inference platform providing access to 10,000+ open-source models via OpenAI-compatible APIs. It supports LLM chat completions, embeddings, image/video/audio generation, batch processing, GPU compute, and secure agent sandboxes.

## Getting Started

1. **Create a Novita account:**
   - Sign up at [https://novita.ai](https://novita.ai)
2. **Generate an API key:**
   - Go to [Key Management](https://novita.ai/settings/key-management) and create an API key.
3. **Set your API key in your PowerShell session:**

```powershell
$env:NovitaKey = "your-Novita-api-key"
```

---

## Tab Completion

The PSAISuite module registers an argument completer that retrieves model names from Novita’s REST API. If no models are found, the completer will indicate this during TAB completion. If you do not see any models, verify your `NovitaKey` environment variable is set correctly and your account has access to the selected models.

---

## Create a Chat Completion

Install `PSAISuite` from the PowerShell Gallery if you haven't already:

```powershell
Install-Module PSAISuite
```

Example usage:

```powershell
# Import the module
Import-Module PSAISuite

$provider = "Novita"
$model_id = "deepseek-v3-0324"

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "A one line summary of Novita"
Invoke-ChatCompletion -Messages $Message -Model $model
```

---

## Advanced Features

- **Function Calling:**
  - Pass PowerShell function names or tool definitions via the `-Tools` parameter for function-calling support.
- **Async Content Generation:**
  - For image, video, or audio generation, use the async task APIs and poll for results using the returned `task_id`.
- **Batch Processing:**
  - Use the batch API for large-scale LLM inference (see [Novita docs](https://novita.ai/docs/skill.md)).
- **GPU Compute & Sandboxes:**
  - Provision GPU instances or spawn secure agent sandboxes for advanced workloads.

---

## Troubleshooting

- **Missing API key:** Ensure `$env:NovitaKey` is set in your session.
- **No models returned:** Check your API key and model access. Use the model browser or `GET /v1/models`.
- **Rate limits:** See [rate limits guide](https://novita.ai/docs/guides/llm-rate-limits).
- **Error codes:** See [error codes](https://novita.ai/docs/guides/error).

---

## Resources

- [Novita Docs](https://novita.ai/docs)
- [Model API Reference](https://novita.ai/docs/api-reference/model-apis-llm-create-chat-completion)
- [Skill Guide](https://novita.ai/docs/skill.md)
- [Model Browser](https://novita.ai/models)
- Read https://novita.ai/docs/skill.md and follow the instructions to integrate Novita AI.

---

## See Also

- [PSAISuite Usage Guide](../README.md)
