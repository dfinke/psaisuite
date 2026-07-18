# Kimi Code

To use Kimi Code with `PSAISuite`, you need an active Kimi membership with Kimi Code benefits. Create an API key in the [Kimi Code Console](https://www.kimi.com/code) and set it for your PowerShell session:

```powershell
$env:KIMI_API_KEY = "your-kimi-code-api-key"
```

Kimi Code and the pay-as-you-go Kimi Platform use different API keys and endpoints. This provider uses Kimi Code's subscription-backed endpoint, so use a key created in the Kimi Code Console.

## Create a Chat Completion

Install `PSAISuite` from the PowerShell Gallery:

```powershell
Install-Module PSAISuite
```

Then invoke a Kimi Code model:

```powershell
Import-Module PSAISuite

Invoke-ChatCompletion -Messages "Write a PowerShell function that tests whether a number is prime." -Model "kimi:kimi-for-coding"
```

## Available Models

Use tab completion after typing `kimi:` to retrieve the models available to your Kimi Code subscription. Kimi currently documents these model IDs:

- `k3` — Kimi K3; requires an eligible membership tier.
- `kimi-for-coding` — Kimi K2.7 Code; available to Kimi Code members.
- `kimi-for-coding-highspeed` — accelerated K2.7 Code; requires an eligible membership tier.

For example:

```powershell
Invoke-ChatCompletion -Messages "Review this function for edge cases." -Model "kimi:k3"
```

## Tool Calling

Kimi Code supports the existing `-Tools` interface, including custom tool schemas:

```powershell
$tool = @{
    Name = 'Get-Weather'
    Description = 'Gets the current weather for a location.'
    Parameters = @{
        type = 'object'
        properties = @{ location = @{ type = 'string' } }
        required = @('location')
    }
}

Invoke-ChatCompletion -Messages "What is the weather in Boston?" -Tools $tool -Model "kimi:kimi-for-coding"
```

Kimi Code keeps thinking enabled for its coding models. PSAISuite preserves Kimi's reasoning context automatically when the model requests a tool.

## See Also

- [Kimi Code documentation](https://www.kimi.com/code/docs/en/)
- [PSAISuite Usage Guide](../README.md)
