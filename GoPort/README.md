# GoPort

This folder contains a Go port of the core `PSAISuite` chat completion flow:

- `New-ChatMessage` → `NewChatMessage`
- `Invoke-ChatCompletion` → `InvokeChatCompletion`
- `Invoke-OpenAIProvider` → `OpenAIProvider.Complete`

## Quick start

```bash
cd GoPort
go test ./...
```

## CLI example

An example command-line program is provided at `GoPort/cmd/psaisuite-cli`. Build and run it like:

```bash
cd GoPort
go build ./cmd/psaisuite-cli
./psaisuite-cli --prompt "Hello" --model openai:gpt-4o-mini
```

Set your OpenAI API key in the `OpenAIKey` environment variable before running.
