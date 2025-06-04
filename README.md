# PSAISuite

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/PSAISuite?color=blue)](https://www.powershellgallery.com/packages/PSAISuite)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/PSAISuite)](https://www.powershellgallery.com/packages/PSAISuite)

[![License](https://img.shields.io/github/license/dfinke/PSAISuite)](https://github.com/dfinke/PSAISuite/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/dfinke/PSAISuite?style=social)](https://github.com/dfinke/PSAISuite)
[![GitHub last commit](https://img.shields.io/github/last-commit/dfinke/PSAISuite)](https://github.com/dfinke/PSAISuite/commits/main)
[![GitHub issues](https://img.shields.io/github/issues/dfinke/PSAISuite)](https://github.com/dfinke/PSAISuite/issues)

Simple, unified interface to multiple Generative AI providers.

`PSAISuite` makes it easy for developers to use multiple LLM through a standardized interface. Using an interface similar to OpenAI's, `PSAISuite` makes it easy to interact with the most popular LLMs and compare the results. It is a thin wrapper around the LLM endpoint, and allows creators to seamlessly swap out and test responses from different LLM providers without changing their code. Today, the library is primarily focussed on chat completions. I will expand it cover more use cases in near future.

Currently supported providers are:

- [Anthropic](guides/antrhopic.md)
- [Azure AI Foundry](guides/azureai.md)
- [CursorAI](guides/cursorai.md)
- [DeepSeek](guides/deepseek.md)
- [GitHub](guides/github.md)
- [Google](guides/google.md)
- [Groq](guides/groq.md)
- [Mistral](guides/mistral.md)
- [Nebius](guides/nebius.md)
- [Ollama](guides/ollama.md)
- [OpenAI](guides/openai.md)
- [OpenRouter](guides/openrouter.md)
- [Perplexity](guides/perplexity.md)
- [xAI](guides/xai.md)

## In Action

![alt text](assets/InvokeChatCompletion.png)

## Installation
You can install the module from the PowerShell Gallery.

```powershell
Install-Module PSAISuite
```

## Setup
To get started, you will need API Keys for the providers you intend to use.

The API Keys need to be be set as environment variables.

Set the API keys.

```powershell
$env:OpenAIKey="your-openai-api-key"
$env:AnthropicKey="your-anthropic-api-key"
$env:CursorAIKey="your-cursorai-api-key"
$env:NebiusKey="your-nebius-api-key"
$env:GITHUB_TOKEN="your-github-token" # Add GitHub token
# ... and so on for other providers
```

### Azure AI Foundry

You will need to set the `AzureAIKey` and `AzureAIEndpoint` environment variables.

```powershell
$env:AzureAIKey = "your-azure-ai-key"
$env:AzureAIEndpoint = "your-azure-ai-endpoint"
```

### CursorAI with Privacy Mode

CursorAI supports privacy-focused AI interactions. You need to set the `CursorAIKey` environment variable, and optionally the `CursorAIEndpoint` for privacy mode.

```powershell
$env:CursorAIKey = "your-cursorai-api-key"

# Optional: Use custom endpoint for privacy mode
$env:CursorAIEndpoint = "your-private-cursor-endpoint"
```

**Privacy Mode Features:**
- Secure API endpoints for sensitive data handling
- Local processing capabilities when configured with custom endpoints
- Enterprise-grade privacy and security compliance
- Support for various models (GPT-4, Claude, etc.) through Cursor's privacy infrastructure

## Usage

## Advanced Usage: Piping Data as Context

You can pipe data directly into `Invoke-ChatCompletion` (or its alias `icc`) to use it as context for your prompt. This is useful for summarizing files, analyzing command output, or providing additional information to the model.

For example:

```powershell
Get-Content .\README.md | icc -Messages "Summarize this document." -Model "openai:gpt-4o-mini"
```

You can also use the output of any command:

```powershell
Get-Process | Out-String | icc -Messages "What processes are running?" -Model "openai:gpt-4o-mini"
```


> **Tip:**
> - The `-Model` parameter supports tab completion for available providers and models. Start typing a provider (like `openai:` or `github:`) and press `Tab` to see suggestions.
> - You can use the `icc` alias instead of `Invoke-ChatCompletion` in all examples above.

See [PIPE-EXAMPLES.md](./PIPE-EXAMPLES.md) for more details and examples.

Using `PSAISuite` to generate chat completion responses from different providers.

### List Available Providers

You can list all available AI providers using the `Get-ChatProviders` function:

```powershell
# Get a list of all available providers
Get-ChatProviders
```

### Generate Chat Completions

```powershell
# Import the module
Import-Module PSAISuite

$models = @("openai:gpt-4o", "anthropic:claude-3-5-sonnet-20240620", "cursorai:gpt-4", "azureai:gpt-4o", "nebius:meta-llama/Llama-3.3-70B-Instruct")

$message = New-ChatMessage -Prompt "What is the capital of France?"

foreach($model in $models) {
    Invoke-ChatCompletion -Message $message -Model $model
}
```

### Generate Chat Completions - Return Text Only
```powershell
# Import the module
Import-Module PSAISuite

$message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Message $message -TextOnly
# or by setting the environment variable

$env:PSAISUITE_TEXT_ONLY=$true
$message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Message $message 

```
### Generate Chat Completions - Using Custom Default Model
```powershell
# Import the module
Import-Module PSAISuite

$model = "openai:gpt-4o"
$message = New-ChatMessage  -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Model $model -Message $message 

# or by setting the environment variable
$env:PSAISUITE_DEFAULT_MODEL = "openai:gpt-4o"
$message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Message $message 

```

Note that the model name in the Invoke-ChatCompletion call uses the format - `<provider>:<model-name>`.

## Adding support for a provider

documentation coming soon