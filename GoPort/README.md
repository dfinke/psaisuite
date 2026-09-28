# GoPort

This folder contains a Go port of the core `PSAISuite` chat completion flow:

- `New-ChatMessage` → `NewChatMessage`
- `Invoke-ChatCompletion` → `InvokeChatCompletion`
- All PowerShell providers → Go provider types

## Supported providers

| Provider key | Go constructor | Environment variable(s) |
|---|---|---|
| `openai` | `NewOpenAIProvider` | `OpenAIKey` |
| `anthropic` | `NewAnthropicProvider` | `AnthropicKey` |
| `google` | `NewGoogleProvider` | `GeminiKey` |
| `groq` | `NewGroqProvider` | `GROQ_API_KEY` |
| `mistral` | `NewMistralProvider` | `MistralKey` |
| `deepseek` | `NewDeepSeekProvider` | `DeepSeekKey` |
| `github` | `NewGitHubProvider` | `GITHUB_TOKEN` |
| `perplexity` | `NewPerplexityProvider` | `PerplexityKey` |
| `openrouter` | `NewOpenRouterProvider` | `OpenRouterKey` |
| `nebius` | `NewNebiusProvider` | `NebiusKey` |
| `inception` | `NewInceptionProvider` | `INCEPTION_API_KEY` |
| `xai` | `NewXAIProvider` | `xAIKey` |
| `azureai` | `NewAzureAIProvider` | `AzureAIKey`, `AzureAIEndpoint` |
| `ollama` | `NewOllamaProvider` | `OLLAMA_HOST` (optional, default `http://localhost:11434`) |

## Quick start

```bash
cd GoPort
go test ./...
```

## Usage in Go

```go
package main

import (
    "context"
    "fmt"
    "github.com/dfinke/psaisuite/GoPort/psaisuite"
)

func main() {
    registry := psaisuite.ProviderRegistry{
        "openai":    psaisuite.NewOpenAIProvider(nil),
        "anthropic": psaisuite.NewAnthropicProvider(nil),
        "google":    psaisuite.NewGoogleProvider(nil),
        "groq":      psaisuite.NewGroqProvider(nil),
        "ollama":    psaisuite.NewOllamaProvider(nil),
        // add more providers as needed
    }

    resp, err := psaisuite.InvokeChatCompletion(context.Background(), psaisuite.CompletionRequest{
        Model:    "openai:gpt-4o-mini",
        Messages: "What is the capital of France?",
    }, registry)
    if err != nil {
        panic(err)
    }
    fmt.Println(resp.Response)
}
```

## CLI example

An example command-line program is provided at `GoPort/cmd/psaisuite-cli`. It
registers all providers automatically and selects the provider from the
`--model` flag.

```bash
cd GoPort
go build ./cmd/psaisuite-cli

# OpenAI
OpenAIKey=<key> ./psaisuite-cli --prompt "Hello" --model openai:gpt-4o-mini

# Anthropic
AnthropicKey=<key> ./psaisuite-cli --prompt "Hello" --model anthropic:claude-3-haiku-20240307

# Google Gemini
GeminiKey=<key> ./psaisuite-cli --prompt "Hello" --model google:gemini-2.0-flash

# Groq
GROQ_API_KEY=<key> ./psaisuite-cli --prompt "Hello" --model groq:llama3-70b-8192

# Ollama (local, no key required)
./psaisuite-cli --prompt "Hello" --model ollama:llama3.2:latest

# Azure AI
AzureAIKey=<key> AzureAIEndpoint=<endpoint> ./psaisuite-cli --prompt "Hello" --model azureai:gpt-4
```

You can also set context inputs and use the default model via the
`PSAISUITE_DEFAULT_MODEL` environment variable:

```bash
PSAISUITE_DEFAULT_MODEL=groq:llama3-70b-8192 \
GROQ_API_KEY=<key> \
./psaisuite-cli --prompt "Summarize this" --context "line1|line2|line3"
```
