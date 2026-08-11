# Perplexity

To use Perplexity with `psaisuite` you will need to [create an account](https://www.perplexity.ai/) and get an API key. Once you have your key, add it to your environment as follows:

```shell
$env:PerplexityKey = "your-perplexity-api-key"
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

$provider = "perplexity"
$model_id = "sonar"

# Create the model identifier
$model = "{0}:{1}" -f $provider, $model_id
$Message = New-ChatMessage -Prompt "What is the capital of France?"
Invoke-ChatCompletion -Messages $Message -Model $model
```

```shell
Messages  : {"content":"Capital of France","role":"user"}
Response  : The capital of France is **Paris**. Located in the north-central part of the country along
            the Seine River, Paris is not only the capital but also the largest city in France. It
            serves as a major center for culture, commerce, and government, hosting numerous national
            and international institutions, including the French Parliament and several international
            organizations like UNESCO[3][4][5]. Paris has a rich history dating back over 2,000 years
            and is renowned for its iconic landmarks such as the Eiffel Tower, Notre-Dame Cathedral, and
            the Louvre Museum[1][3].
Model     : perplexity:sonar
Provider  : perplexity
ModelName : sonar
Timestamp : Sun 03 16 2025 8:16:30 AM
```

## Available Models

Perplexity offers various models.
Check the [Perplexity AI documentation](https://docs.perplexity.ai/guides/model-cards) for the most up-to-date list of available models.
