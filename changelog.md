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