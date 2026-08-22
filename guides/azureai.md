# Azure AI

To use Azure AI with `psaisuite` you will need to [create an Azure account](https://azure.microsoft.com/free/) and deploy Azure AI Foundry or Azure OpenAI resources. After setting up your Azure AI service, you'll need to get your API key and endpoint URL from the Azure portal. Once you have your key and endpoint, add them to your environment as follows:

```shell
$env:AzureAIKey = "your-azure-ai-api-key"
$env:AzureAIEndpoint = "your-azure-ai-endpoint"
```

`AzureAIEndpoint` can point at:

- an Azure OpenAI resource base URL such as `https://your-resource.openai.azure.com`
- an Azure AI Foundry inference resource such as `https://your-resource.services.ai.azure.com`
- an Azure AI Foundry OpenAI-compatible endpoint such as `https://your-resource.services.ai.azure.com/openai/v1`

This means you can use both Azure OpenAI deployments like `gpt-4o` and Microsoft Foundry models like `MAI-DS-R1` through the same `azureai:` provider.

## Create a Chat Completion

Install `psaisuite` from the PowerShell Gallery.

```powershell
Install-Module PSAISuite
```

In your code:

```powershell
# Import the module
Import-Module PSAISuite

$provider = "azureai"
$model_id = "gpt-4o"  # Use the model you've deployed on your Azure AI service

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Messages $Message -Model $model
```

```shell
Messages  : {"role":"user","content":"What is the capital of France?"}
Response  : The capital of France is Paris.
Model     : azureai:gpt-4o
Provider  : azureai
ModelName : gpt-4o
Timestamp : Sun 03 09 2025 9:56:29 AM
```

## Use a Microsoft MAI model from Azure AI Foundry

Point `AzureAIEndpoint` at your Foundry resource (for example `https://your-resource.services.ai.azure.com`) and use the deployed MAI model name as the model suffix:

```powershell
$env:AzureAIKey = "your-azure-ai-api-key"
$env:AzureAIEndpoint = "https://your-resource.services.ai.azure.com"

Import-Module PSAISuite

$message = New-ChatMessage -Prompt "Summarize the benefits of test-driven development."
Invoke-ChatCompletion -Messages $message -Model "azureai:MAI-DS-R1"
```
