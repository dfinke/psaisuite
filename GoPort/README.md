# GoPort

This folder contains a Go port of the core `PSAISuite` chat completion flow:

- `New-ChatMessage` → `NewChatMessage`
- `Invoke-ChatCompletion` → `InvokeChatCompletion`
- `Invoke-OpenAIProvider` → `OpenAIProvider.Complete`

## Quick start

```bash
cd /home/runner/work/psaisuite/psaisuite/GoPort
go test ./...
```
