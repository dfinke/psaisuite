<#
.SYNOPSIS
Invokes a completion request to a specified AI model provider.

.DESCRIPTION
The Invoke-ChatCompletion function sends a prompt to a specified AI model provider and returns the completion response text by default. 
The model provider and model name must be specified in the 'provider:model' format. The function dynamically constructs 
the provider-specific function name and invokes it to get the response. It can also accept context via the pipeline.

.PARAMETER Messages
The messages to be sent to the AI model for completion. This parameter is optional and can accept either:
- A string, which will be wrapped in a user message automatically
- A hashtable array containing properly formatted chat messages
If not provided, and content is piped to -Context, the piped content will be used as the message.

.PARAMETER Context
Context provided via the pipeline. If -Messages is also provided, the context will be prepended as a separate user message labeled "Context:". If -Messages is not provided, the piped context will be used as the message.

.PARAMETER Model
The model to be used for the completion request, specified in 'provider:model' format. Defaults to "openai:gpt-4o-mini".

.PARAMETER Tools
An array of tool definitions for function calling. Can be:
- Array of strings (command names) that will be registered as tools
- Array of hashtables (already defined tool schemas)

.PARAMETER IncludeElapsedTime
A switch parameter that, if specified, measures and includes the elapsed time of the API request in the output.

.PARAMETER Raw
A switch parameter that, if specified, returns the full response object (PSCustomObject) instead of just the response text.

.EXAMPLE
$Message = New-ChatMessage -Prompt "Hello, world!"
Invoke-ChatCompletion -Messages $Message -Model "openai:gpt-4o-mini"

Sends the prompt "Hello, world!" to the OpenAI GPT-4o-mini model and returns the completion response text.

.EXAMPLE
Invoke-ChatCompletion -Messages "Hello, world!" -Model "openai:gpt-4o-mini"

Sends the string "Hello, world!" as a user message to the OpenAI GPT-4o-mini model and returns only the completion response text.

.EXAMPLE
$Message = New-ChatMessage -Prompt "Hello, world!"
Invoke-ChatCompletion -Messages $Message -Model "openai:gpt-4o-mini" -IncludeElapsedTime

Sends the prompt and returns the completion response text with the elapsed time information.

.EXAMPLE
Get-Content .\README.md | Invoke-ChatCompletion -Messages "Summarize this document." -Model "openai:gpt-4o-mini"

Sends the content of README.md as context along with the prompt "Summarize this document." to the model.

.EXAMPLE
"This is context from the pipeline" | Invoke-ChatCompletion -Messages "Explain the context." -Model "openai:gpt-4o-mini"

Sends the pipeline string as context along with the prompt "Explain the context." to the model.

.EXAMPLE
Get-Content .\README.md | Invoke-ChatCompletion -Model "openai:gpt-4o-mini"

Uses the piped README.md content as the message when -Messages is not specified.

.EXAMPLE
Invoke-ChatCompletion -Messages "Show raw output" -Raw

Returns the full response object (PSCustomObject) instead of just the response text.

.EXAMPLE
Invoke-ChatCompletion -Messages "List files in current directory" -Tools "Get-ChildItem" -Model "openai:gpt-4o-mini"

Uses the Get-ChildItem command as a tool for function calling.

.NOTES
The function dynamically constructs the provider-specific function name based on the provider specified in the Model 
parameter. If the provider function does not exist, an error is thrown.
Pipeline input is treated as context and prepended to the messages.

#>
function Invoke-ChatCompletion {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('Prompt')]
        [object]$Messages,

        [Parameter(Position = 1)]
        [string]$Model = "openai:gpt-4o-mini",
        
        [Parameter(ValueFromPipeline)]
        [object]$Context,

        [object[]]$Tools,

        [switch]$IncludeElapsedTime,
        [switch]$Raw
    )

    Begin {
        $pipedContext = [System.Collections.Generic.List[string]]::new()
    }

    Process {
        # Capture explicit -Context and pipeline-bound input
        if ($null -ne $Context) {
            $pipedContext.Add(($Context | Out-String).Trim())
        }
    }

    End {
        # Require either -Messages or piped -Context
        if ($null -eq $Messages -and $pipedContext.Count -eq 0) {
            throw "No input provided. Provide -Messages or pipe content into -Context."
        }

        if ($env:PSAISUITE_DEFAULT_MODEL) {
            Write-Verbose "Using default model from environment variable `$env:PSAISUITE_DEFAULT_MODEL: $env:PSAISUITE_DEFAULT_MODEL"
            $Model = $env:PSAISUITE_DEFAULT_MODEL
        }

        $processedMessages = @()
        if ($null -ne $Messages) {
            if ($Messages -is [string]) {
                $processedMessages += @{
                    'role'    = 'user'
                    'content' = $Messages
                }
            }
            elseif ($Messages -is [array]) {
                $processedMessages = $Messages
            }
            else {
                $processedMessages += $Messages
            }
        }

        if ($pipedContext.Count -gt 0) {
            $contextString = $pipedContext -join "`n"
            if ($null -eq $Messages) {
                # Use piped context as the message when -Messages is not provided
                $processedMessages += @{
                    'role'    = 'user'
                    'content' = $contextString
                }
                $finalMessages = $processedMessages
            }
            else {
                # When both are present, add context as a separate note
                $contextMessage = @{
                    'role'    = 'user'
                    'content' = "Context:`n$contextString"
                }
                $finalMessages = $processedMessages + @($contextMessage)
            }
        }
        else {
            $finalMessages = $processedMessages
        }

        if ($Model -match "^([^:]+):(.+)$") {
            $provider = $Matches[1].ToLower()
            $modelName = $Matches[2]
        }
        else {
            throw "Model must be specified in 'provider:model' format."
        }

        $providerFunction = "Invoke-${provider}Provider"

        if (-not (Get-Command $providerFunction -ErrorAction SilentlyContinue)) {
            throw "Unsupported provider: $provider. No function named $providerFunction found."
        }

        if ($IncludeElapsedTime) {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        }

        $functionParams = @{
            ModelName = $modelName
            Messages  = $finalMessages
        }

        if ($Tools) {
            $functionParams.Tools = $Tools
        }

        if ($SystemRole) {
            $functionParams.SystemRole = $SystemRole
        }

        $responseText = & $providerFunction @functionParams

        if ($IncludeElapsedTime) {
            $stopwatch.Stop()
            $elapsedTime = $stopwatch.Elapsed
        }

        $responseObject = [PSCustomObject]@{
            Messages  = ($finalMessages | ConvertTo-Json -Compress)
            Response  = $responseText
            Model     = $Model
            Provider  = $provider
            ModelName = $modelName
            Timestamp = Get-Date
        }

        if ($IncludeElapsedTime) {
            $responseObject | Add-Member -MemberType NoteProperty -Name 'ElapsedTime' -Value $elapsedTime
        }

        if ($SystemRole) {
            $responseObject | Add-Member -MemberType NoteProperty -Name 'SystemRole' -Value $SystemRole
        }

        if ($Raw) {
            return $responseObject
        }

        if ($IncludeElapsedTime) {
            return "$responseText`n`nElapsed Time: $($elapsedTime.ToString('hh\:mm\:ss\.fff'))"
        }
        else {
            return $responseText
        }
    }
}
