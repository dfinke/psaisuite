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
- [DeepSeek](guides/deepseek.md)
- [GitHub](guides/github.md)
- [Google](guides/google.md)
- [Groq](guides/groq.md)
- [Inception](guides/inception.md)
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
$env:NebiusKey="your-nebius-api-key"
$env:GITHUB_TOKEN="your-github-token" # Add GitHub token
# ... and so on for other providers
$env:INCEPTION_API_KEY="your-inception-api-key"
```

### Azure AI Foundry

You will need to set the `AzureAIKey` and `AzureAIEndpoint` environment variables.

```powershell
$env:AzureAIKey = "your-azure-ai-key"
$env:AzureAIEndpoint = "your-azure-ai-endpoint"
```

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
> - You can use the `icc` or `generateText` alias instead of `Invoke-ChatCompletion` in all examples above.

See [PIPE-EXAMPLES.md](./PIPE-EXAMPLES.md) for more details and examples.

## Tool Calling (Function Calling)

PSAISuite supports tool calling, allowing AI models to execute functions and commands during conversations. This feature enables more interactive and dynamic interactions with LLMs.

### Using Tools

You can pass tools to `Invoke-ChatCompletion` using the `-Tools` parameter. Tools can be specified as:
- Cmdlet objects: Pass the cmdlet directly (e.g., Get-ChildItem), and it will be registered as a tool
- Pre-defined tool schemas (hashtables): Custom tool definitions

Example using a built-in command:

```powershell
Invoke-ChatCompletion -Messages "List the files in the current directory" -Tools Get-ChildItem -Model "openai:gpt-4.1"
```

This will allow the AI model to call the `Get-ChildItem` cmdlet to list directory contents. The model may respond with something like:

```
The files in the current directory are:
- README.md
- LICENSE
- PSAISuite.psd1
- ...
```

Example with custom tool definition:

```powershell
$customTool = @{
    Name = "Get-Weather"
    Description = "Get current weather for a location"
    Parameters = @{
        type = "object"
        properties = @{
            location = @{
                type = "string"
                description = "City name"
            }
        }
        required = @("location")
    }
}

Invoke-ChatCompletion -Messages "What's the weather in New York?" -Tools $customTool -Model "openai:gpt-4o"
```

Currently, tool calling is supported for the OpenAI provider. Support for other providers will be added in future updates.

Using `PSAISuite` to generate chat completion responses from different providers.

### List Available Providers

You can list all available AI providers using the `Get-ChatProviders` function:

```powershell
# Get a list of all available providers
Get-ChatProviders
```

### List OpenRouter Models by Name and Get All Properties

You can list OpenRouter models by name using the `Get-OpenRouterModel` function. Use the `-Raw` switch to return all properties for matching models:

```powershell
# List all OpenRouter models with 'gpt' in their name
Get-OpenRouterModel -Name '*gpt*'

# List all OpenRouter models and return all properties
Get-OpenRouterModel -Raw

# List models by name and return all properties
Get-OpenRouterModel -Name '*gpt*' -Raw
```

The `-Raw` switch returns the full model object from the OpenRouter API, including all available properties.


### Generate Chat Completions

```powershell
# Import the module
Import-Module PSAISuite

$models = @("openai:gpt-4o", "anthropic:claude-3-5-sonnet-20240620", "azureai:gpt-4o", "nebius:meta-llama/Llama-3.3-70B-Instruct")

$message = New-ChatMessage -Prompt "What is the capital of France?"

foreach($model in $models) {
    Invoke-ChatCompletion -Messages $message -Model $model
}
```

### Generate Chat Completions - Get Full Response Object
```powershell
# Import the module
Import-Module PSAISuite

$message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Messages $message -Raw

# You can also use the alias:
generateText -Messages $message -Raw
```
### Generate Chat Completions - Using Custom Default Model
```powershell
# Import the module
Import-Module PSAISuite

$model = "openai:gpt-4o"
$message = New-ChatMessage  -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Model $model -Messages $message 

# or by setting the environment variable
$env:PSAISUITE_DEFAULT_MODEL = "openai:gpt-4o"
$message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Messages $message 
```


Note that the model name in the Invoke-ChatCompletion call uses the format - `<provider>:<model-name>`.

## Adding support for a provider

documentation coming soon