$providerModels = $(
    'groq:gemma2-9b-it'
    'groq:llama-3.3-70b-versatile'
    'openai:gpt-4o-mini'
    'xai:grok-2-1212'
    'anthropic:claude-3-7-sonnet-20250219'
    'gemini:gemini-2.0-flash-exp'
)

$prompt = @"
need greet fn 

- concise, one liner
- no usage, explanation
- no fence blocks 
```````n``````
"@

$messages = @(
    @{role = 'system'; content = 'ur an expert in powershell' }
    @{role = 'user'; content = $prompt }
)

$providerModels | ForEach-Object -Parallel {
    $model = $_
    Write-Host "Testing $model"

    Invoke-ChatCompletion -Messages $using:messages -Model $model -IncludeElapsedTime | Select-Object ElapsedTime, Model, Response
} | Format-List

<#
Testing groq:llama-3.3-70b-versatile
Testing openai:gpt-4o-mini
Testing groq:gemma2-9b-it
Testing xai:grok-2-1212
Testing anthropic:claude-3-7-sonnet-20250219

ElapsedTime : 00:00:00.2931218
Model       : groq:gemma2-9b-it
Response    : `function Greet-Me { "_Hello, World!_" }` 
              

Testing gemini:gemini-2.0-flash-exp
ElapsedTime : 00:00:00.3955283
Model       : groq:llama-3.3-70b-versatile
Response    : Function Greet { Param($Name) "Hello, $Name!" }

ElapsedTime : 00:00:00.5089223
Model       : xai:grok-2-1212
Response    : function Greet { "Hello, {0}!" -f $args[0] }

ElapsedTime : 00:00:00.7321668
Model       : openai:gpt-4o-mini
Response    : function Greet { param($name) ; "Hello, $name!" }

ElapsedTime : 00:00:00.5043939
Model       : gemini:gemini-2.0-flash-exp
Response    : $greet = { param($name="World") "Hello, $name!" }
              

ElapsedTime : 00:00:00.9662041
Model       : anthropic:claude-3-7-sonnet-20250219
Response    : ```Function Greet ($name = "World") { "Hello, $name!" }```
#>
