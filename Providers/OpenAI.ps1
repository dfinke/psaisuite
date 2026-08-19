<#
.SYNOPSIS
    Invokes the OpenAI API to generate responses using specified models.

.DESCRIPTION
    The Invoke-OpenAIProvider function sends requests to the OpenAI API and returns the generated content.
    It requires an API key to be set in the environment variable 'OpenAIKey'.

.PARAMETER ModelName
    The name of the OpenAI model to use (e.g., 'gpt-4', 'gpt-3.5-turbo').

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.PARAMETER Tools
    An array of tool definitions for function calling. Can be strings (command names) or hashtables.

.PARAMETER MaxIterations
    The maximum number of Responses API tool-calling rounds allowed before the request stops.

.PARAMETER EffortLevel
    The requested OpenAI reasoning effort level. Supported values are model-dependent.

.PARAMETER SpeedLevel
    The requested OpenAI processing speed level, such as "fast" or "default".

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Write a PowerShell function to calculate factorial'
    $response = Invoke-OpenAIProvider -ModelName 'gpt-4' -Messages $Message
    
.EXAMPLE
    $response = Invoke-OpenAIProvider -ModelName 'gpt-4' -Messages $messages -Tools "Get-ChildItem"

.NOTES
    Requires the OpenAIKey environment variable to be set with a valid API key.
    Uses OpenAI's Responses API for all models.
    API Reference: https://platform.openai.com/docs/api-reference/responses
#>

function Get-OpenAIProjectInstructionFiles {
    param(
        [string]$StartingDirectory = (Get-Location).Path
    )

    try {
        $startingDirectoryItem = Get-Item -LiteralPath $StartingDirectory -ErrorAction Stop
    }
    catch {
        Write-Verbose "[$((Get-Date).ToString('o'))] Unable to inspect project instructions from '$StartingDirectory': $($_.Exception.Message)"
        return @()
    }

    $ancestors = New-Object 'System.Collections.Generic.List[System.IO.DirectoryInfo]'
    $currentDirectory = $startingDirectoryItem
    $projectRootIndex = -1

    while ($null -ne $currentDirectory) {
        [void]$ancestors.Add($currentDirectory)

        if (Test-Path -LiteralPath (Join-Path $currentDirectory.FullName '.git')) {
            $projectRootIndex = $ancestors.Count - 1
            break
        }

        $parentDirectory = $currentDirectory.Parent
        if ($null -eq $parentDirectory -or $parentDirectory.FullName -eq $currentDirectory.FullName) {
            break
        }

        $currentDirectory = $parentDirectory
    }

    # Without a project marker, only the current directory is in scope.
    if ($projectRootIndex -lt 0) {
        $projectRootIndex = 0
    }

    $instructionFiles = @()
    for ($index = $projectRootIndex; $index -ge 0; $index--) {
        $instructionPath = Join-Path $ancestors[$index].FullName 'AGENTS.md'
        if (Test-Path -LiteralPath $instructionPath -PathType Leaf) {
            try {
                $instructionFiles += Get-Item -LiteralPath $instructionPath -ErrorAction Stop
            }
            catch {
                Write-Verbose "[$((Get-Date).ToString('o'))] Unable to inspect '$instructionPath': $($_.Exception.Message)"
            }
        }
    }

    return @($instructionFiles)
}

function Get-OpenAITextHash {
    param(
        [AllowNull()]
        [string]$Text
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Text)
        return ([System.BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '')
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-OpenAIProjectInstructionState {
    $entries = @()

    foreach ($instructionFile in @(Get-OpenAIProjectInstructionFiles)) {
        try {
            $content = Get-Content -LiteralPath $instructionFile.FullName -Raw -ErrorAction Stop
            $entries += [PSCustomObject]@{
                Path    = $instructionFile.FullName
                Content = $content
                Hash    = Get-OpenAITextHash -Text $content
            }
        }
        catch {
            Write-Verbose "[$((Get-Date).ToString('o'))] Unable to read '$($instructionFile.FullName)': $($_.Exception.Message)"
        }
    }

    if ($entries.Count -eq 0) {
        return $null
    }

    $sections = foreach ($entry in $entries) {
        "--- BEGIN $($entry.Path) ---`n$($entry.Content)`n--- END $($entry.Path) ---"
    }

    $signature = (($entries | ForEach-Object { "$($_.Path)::$($_.Hash)" }) -join '|')
    $text = @(
        'Project instructions loaded from AGENTS.md. Treat these as project guidance for this request.'
        'They do not override system, developer, user, safety, or tool constraints.'
        ''
        ($sections -join "`n`n")
    ) -join "`n"

    return [PSCustomObject]@{
        Signature = $signature
        Text      = $text
        Paths     = @($entries | ForEach-Object { $_.Path })
    }
}

function Get-OpenAIInstructionText {
    param(
        [object[]]$Messages,
        [AllowNull()]
        [object]$ProjectInstructionState
    )

    $instructionSections = @($Messages | ForEach-Object {
            $content = $_

            if ($null -eq $content) {
                return
            }

            if ($content -is [string]) {
                $text = $content
            }
            elseif ($content -is [System.Collections.IDictionary]) {
                if ($content.Contains('text')) {
                    $text = [string]$content['text']
                }
                elseif ($content.Contains('content')) {
                    $text = ConvertTo-OpenAIInstructionText -Content $content['content']
                }
                else {
                    $text = $content | ConvertTo-Json -Depth 20 -Compress
                }
            }
            elseif ($content -is [System.Collections.IEnumerable]) {
                $text = (@($content | ForEach-Object {
                            ConvertTo-OpenAIInstructionText -Content $_
                        }) -join '')
            }
            elseif ($content.PSObject.Properties['text']) {
                $text = [string]$content.text
            }
            elseif ($content.PSObject.Properties['content']) {
                $text = ConvertTo-OpenAIInstructionText -Content $content.content
            }
            else {
                $text = [string]$content
            }

            if (-not [string]::IsNullOrWhiteSpace($text)) {
                $text
            }
        })

    if ($ProjectInstructionState) {
        $instructionSections += $ProjectInstructionState.Text
    }

    if ($instructionSections.Count -eq 0) {
        return $null
    }

    return $instructionSections -join "`n`n"
}

function ConvertTo-OpenAIInstructionText {
    param(
        [AllowNull()]
        [object]$Content
    )

    if ($null -eq $Content) {
        return $null
    }

    if ($Content -is [string]) {
        return $Content
    }

    if ($Content -is [System.Collections.IDictionary]) {
        if ($Content.Contains('text')) {
            return [string]$Content['text']
        }

        if ($Content.Contains('content')) {
            return ConvertTo-OpenAIInstructionText -Content $Content['content']
        }

        return $Content | ConvertTo-Json -Depth 20 -Compress
    }

    if ($Content -is [System.Collections.IEnumerable]) {
        return (@($Content | ForEach-Object {
                    ConvertTo-OpenAIInstructionText -Content $_
                }) -join '')
    }

    if ($Content.PSObject.Properties['text']) {
        return [string]$Content.text
    }

    if ($Content.PSObject.Properties['content']) {
        return ConvertTo-OpenAIInstructionText -Content $Content.content
    }

    return [string]$Content
}

function Write-OpenAIActivity {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [int]$Iteration,
        [int]$MaxIterations
    )

    $timestampedMessage = "[$((Get-Date).ToString('o'))] $Message"
    Write-Verbose $timestampedMessage

    $percentComplete = 0
    if ($MaxIterations -gt 0) {
        $percentComplete = [Math]::Min(99, [Math]::Max(0, [int](($Iteration / $MaxIterations) * 100)))
    }

    Write-Progress `
        -Id 9173 `
        -Activity 'OpenAI tool workflow' `
        -Status $timestampedMessage `
        -PercentComplete $percentComplete
}

function Complete-OpenAIActivity {
    Write-Progress -Id 9173 -Activity 'OpenAI tool workflow' -Completed
}

function Invoke-OpenAITool {
    param(
        [Parameter(Mandatory)]
        [string]$FunctionName,
        [hashtable]$FunctionArgs = @{}
    )

    try {
        if (-not (Get-Command $FunctionName -ErrorAction SilentlyContinue)) {
            return "Error: Function $FunctionName not found"
        }

        # Redirect the error stream so non-terminating PowerShell errors are sent
        # back to the model as tool output instead of only being shown to the user.
        $toolOutput = @(& $FunctionName @FunctionArgs 2>&1)
        $toolErrors = @($toolOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
        $toolValues = @($toolOutput | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })

        if ($toolErrors.Count -gt 0) {
            $errorText = ($toolErrors | ForEach-Object {
                    if ($_.Exception -and $_.Exception.Message) { $_.Exception.Message }
                    else { $_ | Out-String }
                }) -join '; '
            $result = "Error executing $FunctionName`: $errorText"

            if ($toolValues.Count -gt 0) {
                $result += "`nPartial output:`n$($toolValues | Out-String)"
            }

            return $result.TrimEnd()
        }

        if ($toolOutput.Count -eq 0) {
            return '(no output)'
        }

        return ($toolOutput | Out-String).TrimEnd()
    }
    catch {
        return "Error executing $FunctionName`: $($_.Exception.Message)"
    }
}

function Invoke-OpenAIProvider {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [hashtable[]]$Messages,
        [object[]]$Tools,
        [ValidateRange(1, 100)]
        [int]$MaxIterations = 5,
        [ValidateSet('none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max')]
        [string]$EffortLevel,
        [ValidateSet('auto', 'default', 'flex', 'fast', 'priority')]
        [string]$SpeedLevel
    )
    
    # Process tools: if strings, register them; then convert to provider schema
    if ($Tools) {
        $toolDefinitions = New-Object System.Collections.Generic.List[object]
        foreach ($tool in $Tools) {
            if ($tool -is [string]) {
                $toolDefinitions.Add((Register-Tool $tool))
            }
            else {
                $toolDefinitions.Add($tool)
            }
        }
        $Tools = ConvertTo-ProviderToolSchema -Tools $toolDefinitions -Provider openai
    }
    
    $headers = @{
        'Authorization' = "Bearer $env:OpenAIKey"
        'OpenAI-Beta'   = 'responses=v1'
        'content-type'  = 'application/json'
    }
    
    $Uri = "https://api.openai.com/v1/responses"
    
    $projectInstructionState = Get-OpenAIProjectInstructionState
    $messageInstructions = @(
        $Messages |
            Where-Object { $_.role -eq 'system' -or $_.role -eq 'developer' } |
            ForEach-Object { $_.content }
    )
    $inputMessages = @($Messages | Where-Object { $_.role -ne 'system' -and $_.role -ne 'developer' })

    $body = @{
        'model' = $ModelName
        'input' = $inputMessages
    }

    $instructionText = Get-OpenAIInstructionText -Messages $messageInstructions -ProjectInstructionState $projectInstructionState
    if ($instructionText) {
        $body['instructions'] = $instructionText
    }

    if ($projectInstructionState) {
        Write-Verbose "[$((Get-Date).ToString('o'))] Loaded AGENTS.md: $($projectInstructionState.Paths -join ', ')"
    }

    if ($EffortLevel) {
        $body['reasoning'] = @{
            effort = $EffortLevel
        }
    }

    if ($SpeedLevel) {
        $body['service_tier'] = $SpeedLevel
    }

    # Add tools if provided - convert from Chat Completions format to Responses API format
    if ($Tools) {
        $body['tools'] = @($Tools | ForEach-Object {
                @{
                    type        = 'function'
                    name        = $_.function.name
                    description = $_.function.description
                    parameters  = $_.function.parameters
                }
            })
    }
    
    $iteration = 0
    
    while ($iteration -lt $MaxIterations) {
        $round = $iteration + 1
        Write-OpenAIActivity -Message "Request started (round $round/$MaxIterations)" -Iteration $iteration -MaxIterations $MaxIterations

        $params = @{
            Uri     = $Uri
            Method  = 'POST'
            Headers = $headers
            Body    = $body | ConvertTo-Json -Depth 10
        }
        
        try {
            $response = Invoke-RestMethod @params
            
            # Check if the response contains an error
            if ($response.error) {
                Complete-OpenAIActivity
                Write-Error $response.error.message
                return "Error: $($response.error.message)"
            }
            
            # Check if output exists
            if (!$response.output) {
                Complete-OpenAIActivity
                return "No output in response from API."
            }
            
            # Check for function calls in the response output
            $functionCalls = $response.output | Where-Object { $_.type -eq 'function_call' }
            
            if ($functionCalls) {
                Write-OpenAIActivity -Message "Model requested $(@($functionCalls).Count) tool call(s)" -Iteration $iteration -MaxIterations $MaxIterations

                # Add all response output items to the input for context
                $body.input += $response.output
                
                # Execute function calls and add results
                foreach ($call in $functionCalls) {
                    $functionName = $call.name
                    $toolStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    Write-OpenAIActivity -Message "Tool started: $functionName" -Iteration $iteration -MaxIterations $MaxIterations

                    try {
                        $functionArgs = if ($call.arguments) {
                            $call.arguments | ConvertFrom-Json -AsHashtable
                        }
                        else {
                            @{}
                        }

                        $result = Invoke-OpenAITool -FunctionName $functionName -FunctionArgs $functionArgs
                    }
                    catch {
                        $result = "Error executing $FunctionName`: $($_.Exception.Message)"
                    }

                    $toolStopwatch.Stop()
                    Write-OpenAIActivity -Message "Tool completed: $functionName ($($toolStopwatch.ElapsedMilliseconds) ms)" -Iteration $iteration -MaxIterations $MaxIterations
                    
                    $body.input += @{
                        type    = 'function_call_output'
                        call_id = $call.call_id
                        output  = $result
                    }
                }

                $updatedProjectInstructionState = Get-OpenAIProjectInstructionState
                $instructionsChanged = if ($null -eq $projectInstructionState) {
                    $null -ne $updatedProjectInstructionState
                }
                else {
                    $null -eq $updatedProjectInstructionState -or $updatedProjectInstructionState.Signature -ne $projectInstructionState.Signature
                }

                if ($instructionsChanged) {
                    $projectInstructionState = $updatedProjectInstructionState
                    $updatedInstructionText = Get-OpenAIInstructionText -Messages $messageInstructions -ProjectInstructionState $projectInstructionState
                    if ($updatedInstructionText) {
                        $body['instructions'] = $updatedInstructionText
                    }
                    else {
                        [void]$body.Remove('instructions')
                    }

                    if ($updatedProjectInstructionState) {
                        Write-OpenAIActivity -Message "AGENTS.md discovered or changed; loaded for next request" -Iteration $iteration -MaxIterations $MaxIterations
                    }
                    else {
                        Write-OpenAIActivity -Message 'AGENTS.md was removed; updated context for next request' -Iteration $iteration -MaxIterations $MaxIterations
                    }
                }
            }
            else {
                # No function calls, extract text from message output items
                # Responses API returns: output[].type='message', output[].content[].type='output_text'
                $textOutput = ($response.output | Where-Object { $_.type -eq 'message' } | ForEach-Object {
                        if ($_.content -is [array]) {
                            ($_.content | Where-Object { $_.type -eq 'output_text' } | ForEach-Object { $_.text }) -join ''
                        }
                        elseif ($_.content) {
                            $_.content
                        }
                }) -join ''
                if (!$textOutput) {
                    Complete-OpenAIActivity
                    return "No text content in response."
                }
                Write-OpenAIActivity -Message "Response completed (round $round/$MaxIterations)" -Iteration $MaxIterations -MaxIterations $MaxIterations
                Complete-OpenAIActivity
                return [PSCustomObject]@{
                    Text                   = $textOutput
                    MaxIterations          = $MaxIterations
                    RequestedEffortLevel   = $EffortLevel
                    RequestedSpeedLevel    = $SpeedLevel
                    ReasoningEffort        = if ($response.reasoning) { $response.reasoning.effort } else { $null }
                    ServiceTier            = $response.service_tier
                }
            }
        }
        catch {
            Complete-OpenAIActivity
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorMessage = $_.ErrorDetails.Message
            Write-Error "OpenAI API Error (HTTP $statusCode): $errorMessage"
            return "Error calling OpenAI API: $($_.Exception.Message)"
        }
        
        $iteration++
    }

    Complete-OpenAIActivity
    return "Maximum iterations reached without completing the response after $MaxIterations iterations."
}
