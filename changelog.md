# v0.5.3

- Thank you to Daniel Bradley [GitHub](https://github.com/DanielBradley1), [X](https://x.com/DanielatOCN)

    - Update environment variable name for Groq API key from `GROQ_API_KEY` to `GROQ_KEY` for consistency.

# v0.5.2

- Invoke-ChatCompletion:
    - You can omit `-Messages`/`-Prompt` when piping context into `-Context`; piped input becomes the user message.
    - When both `-Messages` and piped `-Context` are provided, the context is added as a separate user message prefixed with "Context:".
- Get-OpenRouterModel improvements:
    - Added -LastWeeks to filter models by recent creation date.
    - Added -Raw to return full model metadata; default view shows Id and Created date.
    - Sorting and simple date filtering for quick discovery of new models.
- Get-GitHubModel improvements:
    - Added -Raw to return full model metadata in addition to simple Id listing.
    - Minor endpoint/format alignment and sorting.
- Azure AI provider updates:
    - Auto-select API version; uses 2024-12-01-preview for o3-mini deployments.
    - Uses max_completion_tokens and removes unsupported parameters; clearer error messages.
- Argument completer:
    - Expanded live model completion for providers: openai, google, github, openrouter, anthropic, deepseek, xai, mistral.
- Misc: small documentation touch-ups and provider consistency fixes.

# v0.5.1

- Added `Get-OpenRouterModel` function to list OpenRouter models supporting tools, with wildcard search capability.
- Added `Get-GitHubModel` function to list GitHub AI models with wildcard search capability.

# v0.4.0

- Added `generateText` alias for `Invoke-ChatCompletion` for easier usage.
- Changed default output of `Invoke-ChatCompletion` to return response text (use `-Raw` to get the full object).
- Removed `-TextOnly` parameter, added `-Raw` parameter for full response object.
- Updated help and examples for `Invoke-ChatCompletion` to reflect new behavior and parameters.
- Improved context handling and message ordering in `Invoke-ChatCompletion`.
- Minor documentation and provider updates.

# v0.3.1

- Added tab completion for the `Mistral` provider to quickly select available models.
- Renamed to Gemini to Google provider.
- Fixed order of messages in the `Invoke-ChatCompletion` function to ensure the correct sequence of user and assistant messages.

# v0.3.0

- Added support for piping data into `Invoke-ChatCompletion` (and `icc` alias) as context for prompts.
- Introduced `icc` alias for `Invoke-ChatCompletion` for easier usage.
- Added tab completion for the `-Model` parameter to quickly select available providers and models.
- Updated documentation and examples to reflect these new features.

# v0.2.5

- Added GitHub provider
- Added documentation for using GitHub models
- See [guides](guides/github.md) for setup and usage

Big thank you to [the-mentor](https://github.com/the-mentor)
- You can now use $env:OLLAMA_HOST and $env:OllamaKey

# v0.2.4 
Big thank you to [the-mentor](https://github.com/the-mentor)
- Added the OpenRouter provider and all related materials

# v0.2.3

Big thank you to [the-mentor](https://github.com/the-mentor)
- Added the Ollama provider and all related materials
- Added the environment variable `PSAISUITE_DEFAULT_MODEL` to set a default model for the module.
- Added the environment variable `PSAISUITE_TEXT_ONLY` to return only the text from the response.

# v0.2.2

- Updated `Invoke-ChatCompletion` to accept a string as input for the `message` parameter, in addition to the existing hashtable format. This allows users to pass a simple string directly, making it easier to use without needing to create a hashtable first.

# v0.2.1

- Added Perplexity provider
- See [guides](guides/perplexity.md)

# v0.2.0

Big thank you to [the-mentor](https://github.com/the-mentor)
- Added `messages` parameter to `Invoke-ChatCompletion` for multiple messages/roles
- Updated all 
    - Providers 
    - Guides
    - Examples

Great work, great contribution!

# v0.1.1

- Added Nebius provider
- Added documentation for using Nebius models
- See [guides](guides/nebius.md) for Nebius setup and usage

- Added Mistral provider
- Added documentation for using Mistral models
- See [guides](guides/mistral.md) for Mistral setup and usage

# v0.1.0

- Changed function name from `Invoke-Completion` to `Invoke-ChatCompletion` for better clarity
- Updated all examples and documentation to use new function name
- Updated module version to reflect breaking change

# v0.0.3

- Added Groq provider
- See [examples](Examples/tryGroq.ps1)
- Added IncludeElapsedTime switch to Invoke-CodeCompletion to measure API request duration
- Added prompt to output in Invoke-CodeCompletion response object

# v0.0.2

- Added AzureAI provider