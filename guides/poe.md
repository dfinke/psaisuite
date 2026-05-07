# POE (Quora)

To use POE with `PSAISuite`, you will need to [create a POE account](https://poe.com/). Once logged in, go to your [API > API Keys](https://poe.com/api/keys) page and create an API key.

Set the following environment variable in your PowerShell session:

```shell
$env:POEKey = "your-poe-api-key"
```

## Model Selection

POE provides access to a variety of models. You can specify the model you want to use by setting the model name in your `-Model` parameter. Refer to the POE documentation or the PSAISuite tab completion for available model names.

---

## Tab Completion

The PSAISuite module registers an argument completer that retrieves model names from each provider’s REST API. If no models are found, the completer will indicate this during TAB completion. If the TAB completer is not returning any model names, verify that your `POEKey` environment variable is set correctly.

## Create a Chat Completion

Install `PSAISuite` from the PowerShell Gallery.

```powershell
Install-Module PSAISuite
```

In your code:

```powershell
# Import the module
Import-Module PSAISuite

$provider = "poe"
$model_id = "gpt-3.5-turbo"  # Example model, replace as needed

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "Explain POE in one line"
Invoke-ChatCompletion -Messages $Message -Model $model
```

---

## See Also

- [PSAISuite Usage Guide](../README.md)
