# Cheaper Inference

Cheaper Inference is an OpenAI-compatible LLM gateway. One API key gives access to models from several labs.

## Getting Started

1. **Create a Cheaper Inference account:**
   - Sign up at [https://cheaperinference.com](https://cheaperinference.com)
2. **Generate an API key:**
   - Create an API key in your account dashboard.
3. **Set your API key in your PowerShell session:**

```powershell
$env:CheaperInferenceKey = "your-cheaperinference-api-key"
```

---

## Tab Completion

The PSAISuite module registers an argument completer that retrieves model names from the Cheaper Inference public model list (`https://api.cheaperinference.com/public/models`). This list does not need an API key. Only text models are shown.

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

$provider = "cheaperinference"
$model_id = "gpt-5.4-mini"

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "A one line summary of PowerShell"
Invoke-ChatCompletion -Messages $Message -Model $model
```

Model ids are bare names, for example `gpt-5.4-mini`, `claude-sonnet-5` or `deepseek-v4-flash`.

---

## Advanced Features

- **Function Calling:**
  - Pass PowerShell function names or tool definitions via the `-Tools` parameter for function-calling support.

---

## Troubleshooting

- **Missing API key:** Ensure `$env:CheaperInferenceKey` is set in your session.
- **Unknown model:** Check the model id against the public model list.
- **HTTP 401:** Check that your API key is correct.

---

## Resources

- [Cheaper Inference Docs](https://cheaperinference.com/docs)
- [Public Model List](https://api.cheaperinference.com/public/models)

---

## See Also

- [PSAISuite Usage Guide](../README.md)
