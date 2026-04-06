# FireworksAI

To use FireworksAI with `PSAISuite` you will need to [create an account](https://app.fireworks.ai/account/home/). Once logged in, go to your [API Keys](https://app.fireworks.ai/settings/users/api-keys) page and generate an API key.

Set the following environment variable in your PowerShell session:

```shell
$env:FireworksAIKey = "your-fireworksai-api-key"
```

## Deployments

If you have deployed models under your account_id, for PSAISuite to interact with those models, you must also reference your FireworksAI account_id. So this by setting the following environment variable in your PowerShell session:

```shell
$env:FireworksID = "your-fireworksai-account_id"
```

When your Fireworks AI account has not deployed any models, the function allows the `$env:FireworksID` environment variable to be omitted. In this case, the function automatically falls back to the default `account_id` value of `"fireworks"`, enabling access to fireworks default models.

---

# Tab Completion

The PSAISuite module registers an argument completer that retrieves model names from each provider’s REST API. If no models are found, the completer will indicate this during TAB completion with "No models were returned for account ID: <account_id>". If your account has deployed models but the TAB completer is not returning any model names, verify that your `FireworksID` environment variable is set correctly. As a troubleshooting step, removing this environment variable will cause the default **fireworks** account ID to be used, which should return a set of default models if you have not any models deployed under your own ID.

## Create a Chat Completion

Install `PSAISuite` from the PowerShell Gallery.

```powershell
Install-Module PSAISuite
```

In your code:

```powershell
# Import the module
Import-Module PSAISuite

$provider = "fireworksai"
$model_id = "deepseek-v3p1"

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "Explain Fireworks.ai in one line"
Invoke-ChatCompletion -Messages $Message -Model $model
```

---

## See Also

- [PSAISuite Usage Guide](../README.md)
