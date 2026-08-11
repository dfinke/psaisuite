# Inception

To use Inception with `psaisuite` you will need to [create an account](https://inceptionlabs.ai/). After logging in, go to your dashboard and generate a new API key. Once you have your key, add it to your environment as follows:

```shell
$env:INCEPTION_API_KEY = "your-inception-api-key"
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

$provider = "inception"
$model_id = "mercury-coder"

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "What is a diffusion model?"
Invoke-ChatCompletion -Messages $Message -Model $model
```

```shell
Messages  : {"role":"user","content":"What is a diffusion model?"}
Response  : [Inception's response here]
Model     : inception:mercury-coder
Provider  : inception
ModelName : mercury-coder
Timestamp : Sun 03 09 2025 9:56:29 AM
```
