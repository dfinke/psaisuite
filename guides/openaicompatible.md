# OpenAI-Compatible Endpoint

Use PSAISuite's `openaicompatible` provider when you have an OpenAI-compatible
chat completions server that PSAISuite should call directly.

This is the supported path for infrastructure platforms where you deploy your
own model server rather than calling a vendor-managed shared inference API. As
of 2026-09-19, PSAISuite does not add a dedicated `iren` provider because the
public IREN AI Cloud material reviewed for this change describes GPU cloud
infrastructure instead of a documented first-party PSAISuite-ready inference
endpoint.

## Setup

Set the endpoint to the base OpenAI-compatible API URL (for example, a vLLM or
TGI deployment exposing `/v1/chat/completions` and `/v1/models`):

```powershell
$env:OpenAICompatibleEndpoint = "http://127.0.0.1:8000/v1"
```

If the endpoint requires authentication, also set one of these:

```powershell
$env:OpenAICompatibleKey = "your-endpoint-key"
# or
$env:OPENAI_COMPATIBLE_API_KEY = "your-endpoint-key"
```

Authentication is optional so unauthenticated local or private network
deployments also work.

## Usage

```powershell
Invoke-ChatCompletion `
    -Messages "Explain GPU scheduling in one paragraph." `
    -Model "openaicompatible:meta-llama/Llama-3.1-8B-Instruct"
```

Tool workflows use the same bounded loop as the existing OpenAI-compatible
gateway integrations:

```powershell
Invoke-ChatCompletion `
    -Messages "List the files in the current directory." `
    -Model "openaicompatible:meta-llama/Llama-3.1-8B-Instruct" `
    -Tools Get-ChildItem `
    -MaxIterations 3
```

`-Model` tab completion queries the configured endpoint's `/models` route when
`OpenAICompatibleEndpoint` is set.
