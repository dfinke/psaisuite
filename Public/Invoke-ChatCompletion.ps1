<#
.SYNOPSIS
Invokes a completion request to a specified AI model provider.

.DESCRIPTION
The Invoke-ChatCompletion function sends a prompt to a specified AI model provider and returns the completion response text by default. 
The model provider and model name must be specified in the 'provider:model' format. The function dynamically constructs 
the provider-specific function name and invokes it to get the response. It can also accept context via the pipeline.
OpenAI, Anthropic, DeepSeek, and Vercel report request rounds, tool activity, elapsed time, and
completion/failure through PowerShell progress. Add -Verbose for an activity log.

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

.PARAMETER MaxIterations
The maximum number of tool-calling rounds allowed before the request stops.
This parameter is supported by OpenAI, Anthropic, DeepSeek, and Vercel and defaults
to 5.

.PARAMETER ToolRoot
DeepSeek file-tool boundary, defaulting to the current directory. Applies to
the built-in Get-ChildItem and Get-Content cmdlets and their aliases. Other
providers currently reject this parameter. Arbitrary custom functions retain
the session's permissions; this is not an operating-system sandbox.

.PARAMETER ToolPolicy
Local tool-execution options, currently supported by DeepSeek. Configure
MaxReadBytes, MaxOutputCharacters, MaxListedItems, MaxScanEntries, or MaxFilePaths (zero
means unlimited), or supply BeforeInvoke, a scriptblock receiving a call
descriptor and returning one Boolean allow/deny decision. The policy is local
to tool execution and independent of the selected model's reasoning.

.PARAMETER EffortLevel
The provider reasoning effort level. OpenAI supports all listed values;
Anthropic supports low, medium, high, xhigh, and max. DeepSeek maps the listed
values to none, low, high, or max.

.PARAMETER SpeedLevel
The provider processing speed level. Anthropic maps fast and priority to its
priority-capable tier and flex to standard-only capacity.

.PARAMETER IncludeElapsedTime
A switch parameter that, if specified, measures and includes the elapsed time of the API request in the output.

.PARAMETER Raw
A switch parameter that, if specified, returns the full response object (PSCustomObject) instead of just the response text.
DeepSeek also includes Conversation: replayable Responses input items for a
follow-up request, including tool exchanges and reasoning. Keep this history
with the same model and tools; it is not stored on DeepSeek's server.

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

        [ValidateNotNullOrEmpty()]
        [string]$ToolRoot,

        [hashtable]$ToolPolicy,

        [ValidateRange(1, 100)]
        [int]$MaxIterations = 5,

        [ValidateSet('none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max')]
        [string]$EffortLevel,

        [ValidateSet('auto', 'default', 'flex', 'fast', 'priority')]
        [string]$SpeedLevel,

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

        if ($PSBoundParameters.ContainsKey('MaxIterations') -and $provider -notin @('openai', 'anthropic', 'deepseek', 'vercel')) {
            throw "MaxIterations is currently supported only for the OpenAI, Anthropic, DeepSeek, and Vercel providers."
        }

        if ($PSBoundParameters.ContainsKey('ToolRoot') -or $PSBoundParameters.ContainsKey('ToolPolicy')) {
            if ($provider -ne 'deepseek') { throw 'ToolRoot and ToolPolicy are currently supported only for the DeepSeek provider.' }
        }

        if ($EffortLevel -and $provider -eq 'anthropic' -and @('low', 'medium', 'high', 'xhigh', 'max') -notcontains $EffortLevel) {
            throw "Anthropic supports effort levels: low, medium, high, xhigh, and max."
        }

        if ($EffortLevel -and $provider -notin @('openai', 'anthropic', 'deepseek')) {
            throw "EffortLevel is currently supported only for the OpenAI, Anthropic, and DeepSeek providers."
        }

        if ($SpeedLevel -and $provider -notin @('openai', 'anthropic')) {
            throw "SpeedLevel is currently supported only for the OpenAI and Anthropic providers."
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
        if ($PSBoundParameters.ContainsKey('ToolRoot')) { $functionParams.ToolRoot = $ToolRoot }
        if ($PSBoundParameters.ContainsKey('ToolPolicy')) { $functionParams.ToolPolicy = $ToolPolicy }

        if ($provider -in @('openai', 'anthropic', 'deepseek', 'vercel')) {
            $functionParams.MaxIterations = $MaxIterations

            if ($EffortLevel -and $provider -in @('openai', 'anthropic', 'deepseek')) {
                $functionParams.EffortLevel = $EffortLevel
            }

            if ($SpeedLevel -and $provider -in @('openai', 'anthropic')) {
                $functionParams.SpeedLevel = $SpeedLevel
            }
        }

        $providerResult = & $providerFunction @functionParams
        $providerMetadata = $null

        if ($provider -in @('openai', 'anthropic', 'deepseek') -and $providerResult -is [PSCustomObject] -and $providerResult.PSObject.Properties['Text']) {
            $responseText = $providerResult.Text
            $providerMetadata = $providerResult
        }
        else {
            $responseText = $providerResult
        }

        if ($IncludeElapsedTime) {
            $stopwatch.Stop()
            $elapsedTime = $stopwatch.Elapsed
        }

        $responseObject = [PSCustomObject]@{
            Messages  = ($finalMessages | ConvertTo-Json -Depth 50 -Compress)
            Response  = $responseText
            Model     = $Model
            Provider  = $provider
            ModelName = $modelName
            Timestamp = Get-Date
        }

        if ($providerMetadata) {
            if ($provider -eq 'deepseek' -and $providerMetadata.PSObject.Properties['Conversation']) {
                $responseObject | Add-Member -MemberType NoteProperty -Name 'Conversation' -Value $providerMetadata.Conversation
                $responseObject | Add-Member -MemberType NoteProperty -Name 'ToolRoot' -Value $providerMetadata.ToolRoot
                $responseObject | Add-Member -MemberType NoteProperty -Name 'IterationsUsed' -Value $providerMetadata.IterationsUsed
            }
            $responseObject | Add-Member -MemberType NoteProperty -Name 'MaxIterations' -Value $providerMetadata.MaxIterations
            $responseObject | Add-Member -MemberType NoteProperty -Name 'EffortLevel' -Value $providerMetadata.RequestedEffortLevel
            $responseObject | Add-Member -MemberType NoteProperty -Name 'SpeedLevel' -Value $providerMetadata.RequestedSpeedLevel
            $responseObject | Add-Member -MemberType NoteProperty -Name 'ReasoningEffort' -Value $providerMetadata.ReasoningEffort
            $responseObject | Add-Member -MemberType NoteProperty -Name 'ServiceTier' -Value $providerMetadata.ServiceTier
        }

        if ($IncludeElapsedTime) {
            $responseObject | Add-Member -MemberType NoteProperty -Name 'ElapsedTime' -Value $elapsedTime
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
