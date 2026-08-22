# LM Studio

To use LM Studio with `psaisuite` you will need to download and install LM Studio from https://lmstudio.ai.

LM Studio is a desktop application that allows you to run large language models locally on your machine. It provides an OpenAI-compatible API that `psaisuite` can connect to.

## Setup

1. Download and install LM Studio from https://lmstudio.ai
2. Start LM Studio and load a model of your choice
3. Go to the "Developer" tab in LM Studio to start the local server
4. The default server address is `http://localhost:1234`

## Environment Variables

- `LMSTUDIO_API_URL`: Set this to override the default URL (default: `http://localhost:1234`)
- `LMSTUDIO_API_KEY`: Set this if your LM Studio instance requires authentication (optional)

## Create a Chat Completion

Install `psaisuite` from the PowerShell Gallery.

```powershell
Install-Module PSAISuite
```

In your code:

```powershell
# Import the module
Import-Module PSAISuite

# Make sure LM Studio is running with a model loaded
# Default connection will use http://localhost:1234

$provider = "lmstudio"
$model_id = "your-loaded-model-name"  # Use the model name as shown in LM Studio

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Message $Message -Model $model
```

## Using Custom URL

If you're running LM Studio on a different port or remote machine:

```powershell
# Set custom LM Studio URL
$env:LMSTUDIO_API_URL = "http://localhost:5678"
# or for a remote instance
$env:LMSTUDIO_API_URL = "http://your-server:1234"

$Message = New-ChatMessage -Prompt "Hello, world!"
Invoke-ChatCompletion -Message $Message -Model "lmstudio:your-model-name"
```

## Using API Key

If your LM Studio instance requires authentication:

```powershell
# Set API key
$env:LMSTUDIO_API_KEY = "your-api-key"

$Message = New-ChatMessage -Prompt "Hello, world!"
Invoke-ChatCompletion -Message $Message -Model "lmstudio:your-model-name"
```

## Sample Output

```shell
Messages  : {"role":"user","content":"What is the capital of France?"}
Response  : The capital of France is Paris.
Model     : lmstudio:your-model-name
Provider  : lmstudio
ModelName : your-model-name
Timestamp : 1/5/2025 10:30:45 AM
```

## Troubleshooting

If you get connection errors:

1. Make sure LM Studio is running
2. Verify that the local server is started in the "Developer" tab
3. Check that the URL and port are correct
4. Ensure a model is loaded and ready to serve requests