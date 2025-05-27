<#
.SYNOPSIS
Invokes a completion request to a specified AI model provider.

.DESCRIPTION
The Invoke-ChatCompletion function sends a prompt to a specified AI model provider and returns the completion response. 
The model provider and model name must be specified in the 'provider:model' format. The function dynamically constructs 
the provider-specific function name and invokes it to get the response. It can also accept context via the pipeline.

.PARAMETER Messages
The messages to be sent to the AI model for completion. This parameter is mandatory and can accept either:
- A string, which will be wrapped in a user message automatically
- A hashtable array containing properly formatted chat messages

.PARAMETER Context
Context provided via the pipeline. This will be prepended to the Messages as a user message.

.PARAMETER Model
The model to be used for the completion request, specified in 'provider:model' format. Defaults to "openai:gpt-4o-mini".

.PARAMETER TextOnly
A switch parameter that, if specified, returns only the response text. If not specified, a custom object containing 
the response text, model information, and timestamp is returned.

.PARAMETER IncludeElapsedTime
A switch parameter that, if specified, measures and includes the elapsed time of the API request in the output.

.PARAMETER Functions
An array of function definitions that the model can call. Each function should be a hashtable with the schema following the OpenAI function calling format.

.EXAMPLE
$Message = New-ChatMessage -Prompt "Hello, world!"
Invoke-ChatCompletion -Messages $Message -Model "openai:gpt-4o-mini"

Sends the prompt "Hello, world!" to the OpenAI GPT-4o-mini model and returns the completion response.

.EXAMPLE
Invoke-ChatCompletion -Messages "Hello, world!" -Model "openai:gpt-4o-mini" -TextOnly

Sends the string "Hello, world!" as a user message to the OpenAI GPT-4o-mini model and returns only the completion response text.

.EXAMPLE
$Message = New-ChatMessage -Prompt "Hello, world!"
Invoke-ChatCompletion -Messages $Message -Model "openai:gpt-4o-mini" -IncludeElapsedTime

Sends the prompt and returns the completion response with the elapsed time information.

.EXAMPLE
Get-Content .\\README.md | Invoke-ChatCompletion -Messages "Summarize this document." -Model "openai:gpt-4o-mini"

Sends the content of README.md as context along with the prompt "Summarize this document." to the model.

.EXAMPLE
"This is context from the pipeline" | Invoke-ChatCompletion -Messages "Explain the context." -Model "openai:gpt-4o-mini"

Sends the pipeline string as context along with the prompt "Explain the context." to the model.

.NOTES
The function dynamically constructs the provider-specific function name based on the provider specified in the Model 
parameter. If the provider function does not exist, an error is thrown.
Pipeline input is treated as context and prepended to the messages.

#>
function Invoke-ChatCompletion {
    [CmdletBinding()]
    param(
        [object]$Messages,

        [string]$Model = "openai:gpt-4o-mini",
        
        [Parameter(ValueFromPipeline)] # Accepts pipeline input, not positional
        [object]$Context, # Changed from [string] to [object]
    
        [switch]$TextOnly,
        [switch]$IncludeElapsedTime,
        
        [Parameter()]
        [array]$Functions
    )

    Begin {
        # Initialize a list to collect pipeline input
        $pipedContext = [System.Collections.Generic.List[string]]::new()
    }

    Process {
        # Collect pipeline input
        if ($PSBoundParameters.ContainsKey('Context')) {
            # Convert the pipeline object to string before adding
            $pipedContext.Add(($Context | Out-String).Trim())
        }
    }

    End {
        if ($env:PSAISUITE_DEFAULT_MODEL) {
            Write-Verbose "Using default model from environment variable `$env:PSAISUITE_DEFAULT_MODEL: $env:PSAISUITE_DEFAULT_MODEL"
            $Model = $env:PSAISUITE_DEFAULT_MODEL
        }

        # Process the main Messages parameter
        $processedMessages = @()
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
            # Assuming $Messages is a single hashtable message
            $processedMessages += $Messages
        }

        # Prepend piped context if it exists
        if ($pipedContext.Count -gt 0) {
            $contextString = $pipedContext -join "`n"
            $contextMessage = @{
                'role'    = 'user'
                'content' = "Context:\n$contextString"
            }
            # Prepend context message, then the original prompt message
            $finalMessages = $processedMessages + @($contextMessage)
        }
        else {
            $finalMessages = $processedMessages
        }

        # Parse provider and model from the Model parameter
        if ($Model -match "^([^:]+):(.+)$") {
            $provider = $Matches[1].ToLower()
            $modelName = $Matches[2]
        }
        else {
            throw "Model must be specified in 'provider:model' format."
        }

        # Dynamically construct provider function name
        $providerFunction = "Invoke-${provider}Provider"

        # Check if the provider function exists
        if (-not (Get-Command $providerFunction -ErrorAction SilentlyContinue)) {
            throw "Unsupported provider: $provider. No function named $providerFunction found."
        }

        # Start measuring execution time if requested
        if ($IncludeElapsedTime) {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        }

        # Invoke the provider-specific implementation
        $functionParams = @{
            ModelName = $modelName
            Messages  = $finalMessages # Use the potentially modified messages array
        }

        if ($SystemRole) {
            $functionParams.SystemRole = $SystemRole
        }
        
        if ($Functions) {
            $functionParams.Functions = $Functions
        }

        $response = & $providerFunction @functionParams

        # Handle function calls if present
        if ($response -is [hashtable] -and $response.PSObject.Properties.Name -contains 'function_call') {
            # Extract function call details
            $functionCall = $response.function_call
            $functionName = $functionCall.name
            $functionArgs = $functionCall.arguments | ConvertFrom-Json

            Write-Verbose "Function call detected: $functionName"
            
            # Check if the function exists in PowerShell
            if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                try {
                    # Execute the PowerShell function
                    $functionResult = & $functionName @functionArgs
                    
                    # Add the function result as a message
                    $functionResponseMessage = @{
                        'role' = 'function'
                        'name' = $functionName
                        'content' = $functionResult | ConvertTo-Json
                    }
                    
                    # Add the original message and function result to the conversation
                    $updatedMessages = $finalMessages + @($response) + @($functionResponseMessage)
                    
                    # Make another call to the model with the function result
                    $functionParams.Messages = $updatedMessages
                    
                    # Make the follow-up call
                    $response = & $providerFunction @functionParams
                    
                    # Now the response should be regular content
                    $responseText = if ($response -is [hashtable]) { $response.content } else { $response }
                } 
                catch {
                    Write-Error "Error executing function '$functionName': $_"
                    $responseText = "Error executing function: $_"
                }
            }
            else {
                Write-Warning "Function '$functionName' not found in PowerShell context"
                $responseText = "Function call to '$functionName' was requested, but the function is not available."
            }
        }
        else {
            # Handle normal responses
            $responseText = if ($response -is [hashtable]) { $response.content } else { $response }
        }

        # Stop measuring execution time if requested
        if ($IncludeElapsedTime) {
            $stopwatch.Stop()
            $elapsedTime = $stopwatch.Elapsed
        }

        # Return the result based on the TextOnly switch
        if ($TextOnly -or [System.Convert]::ToBoolean($env:PSAISUITE_TEXT_ONLY)) {
            # Format the text output to include the elapsed time if requested
            if ($IncludeElapsedTime) {
                return "$responseText`n`nElapsed Time: $($elapsedTime.ToString('hh\:mm\:ss\.fff'))"
            }
            else {
                return $responseText
            }
        }
        else {
            # Create the base response object
            $responseObject = [PSCustomObject]@{
                Messages  = ($finalMessages | ConvertTo-Json -Compress) # Use finalMessages
                Response  = $responseText
                Model     = $Model
                Provider  = $provider
                ModelName = $modelName
                Timestamp = Get-Date
            }

            # Add function call information if present
            if ($response -is [hashtable] -and $response.PSObject.Properties.Name -contains 'function_call') {
                $responseObject | Add-Member -MemberType NoteProperty -Name 'FunctionCall' -Value $response.function_call
            }

            # Add elapsed time if requested
            if ($IncludeElapsedTime) {
                $responseObject | Add-Member -MemberType NoteProperty -Name 'ElapsedTime' -Value $elapsedTime
            }

            if ($SystemRole) {
                $responseObject | Add-Member -MemberType NoteProperty -Name 'SystemRole' -Value $SystemRole
            }

            return $responseObject
        }
    }
}
