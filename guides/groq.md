# Groq

To use Groq with `psaisuite` you will need to [create a free account](https://console.groq.com/). Once logged in, go to the [API Keys](https://console.groq.com/keys) section in your account settings and generate a new Groq API key. Once you have your key, add it to your environment as follows:

```shell
$env:GROQ_API_KEY = "your-groq-api-key"
```

## Create a Chat Completion

Install `psaisuite` from the PowerShell Gallery.

```powershell
Install-Module PSAISuite
```

In your code:

```powershell
# Import the module
Import-Module PSAISuite

$provider = "groq"
$model_id = "llama3-70b-8192"

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Message $Message -Model $model
```

```shell
Messages  : {"role":"user","content":"What is the capital of France?"}
Response  : The capital of France is Paris.
Model     : groq:llama3-70b-8192
Provider  : groq
ModelName : llama3-70b-8192
Timestamp : Sun 03 09 2025 9:52:05 AM
```
