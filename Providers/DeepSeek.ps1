function Invoke-DeepSeekProvider {
    <#
    .SYNOPSIS
    Runs DeepSeek Responses requests with local PowerShell function tools.
    .PARAMETER ModelName
    A model returned by DeepSeek's model catalog, such as deepseek-flash.
    .PARAMETER Messages
    Messages or Responses input items. Supply the previous Conversation plus a
    new user message to continue a stateless conversation, including reasoning.
    .PARAMETER Tools
    PowerShell command names or function schemas. Only registered tools may run.
    Command names require Register-Tool (provided by PSAI).
    .PARAMETER MaxIterations
    Maximum model requests, including tool-calling rounds and the final answer.
    .PARAMETER EffortLevel
    Reasoning effort. none disables thinking; compatible values map to low,
    high, or max according to DeepSeek's documented mapping.
    .NOTES
    Uses https://api.deepseek.com/responses and the DeepSeekKey environment
    variable. Returns text and conversation metadata to Invoke-ChatCompletion.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModelName,
        [Parameter(Mandatory)]
        [object[]]$Messages,
        [object[]]$Tools,
        [ValidateRange(1, 100)]
        [int]$MaxIterations = 5,
        [ValidateSet('none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max')]
        [string]$EffortLevel
    )

    if ([string]::IsNullOrWhiteSpace($env:DeepSeekKey)) {
        throw 'Set the DeepSeekKey environment variable before using DeepSeek.'
    }

    $registeredTools = @{}
    $responseTools = @()
    foreach ($tool in $Tools) {
        $definition = if ($tool -is [string]) {
            if (-not (Get-Command Register-Tool -ErrorAction SilentlyContinue)) {
                throw 'Command-name tools require Register-Tool from PSAI. Install PSAI or supply function schemas.'
            }
            Register-Tool $tool -ErrorAction Stop
        }
        else { $tool }

        $schemas = @(ConvertTo-ProviderToolSchema -Tools @($definition) -Provider openai -ErrorAction Stop)
        if ($schemas.Count -ne 1) { throw 'Each DeepSeek tool must have a valid function schema.' }
        $schema = if ($schemas[0].function) { $schemas[0].function } else { $schemas[0] }
        $name = [string]$schema.name
        if ($name -cnotmatch '^[a-zA-Z0-9_-]{1,128}$') { throw "Invalid DeepSeek tool name: $name" }
        if ($registeredTools.ContainsKey($name)) { throw "Duplicate DeepSeek tool name: $name" }
        if (-not (Get-Command -Name $name -ErrorAction SilentlyContinue)) { throw "Tool command not found: $name" }
        $parameters = if ($schema.parameters) { $schema.parameters } else { @{ type = 'object'; properties = @{} } }
        $registeredTools[$name] = $parameters
        $responseTools += @{
            type = 'function'
            name = $name
            description = if ($schema.description) { $schema.description } else { $name }
            parameters = $parameters
        }
    }

    $instructionMessages = @($Messages | Where-Object { $_.role -in @('system', 'developer') })
    $body = @{
        model = $ModelName
        input = @($Messages | Where-Object { $_.role -notin @('system', 'developer') })
        stream = $false
    }
    $instructions = (@($instructionMessages | ForEach-Object {
        ConvertTo-OpenAIInstructionText -Content $_.content
    }) -join "`n`n")
    if ($instructions) { $body.instructions = $instructions }
    if ($responseTools.Count -gt 0) {
        $body.tools = $responseTools
        $body.tool_choice = 'auto'
    }
    $reasoningEffort = if ($EffortLevel) {
        switch ($EffortLevel) {
            'none' { 'none' }
            { $_ -in @('minimal', 'low') } { 'low' }
            'max' { 'max' }
            default { 'high' }
        }
    }
    if ($reasoningEffort) { $body.reasoning = @{ effort = $reasoningEffort } }

    $headers = @{ Authorization = "Bearer $env:DeepSeekKey"; 'Content-Type' = 'application/json' }
    $activity = New-AgentActivity -Provider 'DeepSeek' -Model $ModelName -MaxIterations $MaxIterations
    $seenCalls = @{}
    foreach ($item in $body.input) {
        if ($item.type -eq 'function_call' -and $item.call_id) { $seenCalls[[string]$item.call_id] = $true }
    }

    try {
        for ($round = 1; $round -le $MaxIterations; $round++) {
            Write-AgentActivity -Activity $activity -Message 'Waiting for response' -Round $round
            try {
                $response = Invoke-RestMethod -Uri 'https://api.deepseek.com/responses' -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 50) -ErrorAction Stop
            }
            catch [System.Management.Automation.PipelineStoppedException] { throw }
            catch {
                $detail = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
                throw "DeepSeek API request failed: $detail"
            }
            if ($response.error -or $response.status -eq 'failed') {
                throw "DeepSeek response failed: $($response.error.message)"
            }
            if ($response.status -eq 'incomplete') {
                Write-AgentActivity -Activity $activity -Message "Stopped: incomplete response ($($response.incomplete_details.reason))" -Completed
                throw "DeepSeek response is incomplete ($($response.incomplete_details.reason)). No tools from this response were executed."
            }
            if ($response.status -ne 'completed') { throw "Unexpected DeepSeek response status: $($response.status)" }
            $output = @($response.output)
            if ($output.Count -eq 0 -or $null -eq $output[0]) { throw 'DeepSeek returned no response content.' }
            $calls = @($output | Where-Object type -eq 'function_call')
            # Validate the whole batch before executing anything; do not replay IDs.
            foreach ($call in $calls) {
                if ([string]::IsNullOrWhiteSpace($call.call_id) -or $seenCalls.ContainsKey([string]$call.call_id)) {
                    throw 'DeepSeek returned a missing or duplicate tool call ID; no tools from this response were executed.'
                }
                $seenCalls[[string]$call.call_id] = $true
            }
            $body.input = @($body.input) + $output
            if ($calls.Count -gt 0) {
                Write-AgentActivity -Activity $activity -Message "Model requested $($calls.Count) tool call(s)"
                foreach ($call in $calls) {
                    $timer = [System.Diagnostics.Stopwatch]::StartNew()
                    Write-AgentActivity -Activity $activity -Message "Tool started: $($call.name)"
                    $toolResult = Invoke-RegisteredAgentTool -Name $call.name -Arguments $call.arguments -RegisteredTools $registeredTools
                    $timer.Stop()
                    $state = if ($toolResult.Failed) { 'Tool failed' } else { 'Tool completed' }
                    Write-AgentActivity -Activity $activity -Message "$($state): $($call.name) ($($timer.ElapsedMilliseconds) ms)"
                    $body.input += @{ type = 'function_call_output'; call_id = $call.call_id; output = $toolResult.Output }
                }
                continue
            }

            $text = (@($output | Where-Object type -eq 'message' | ForEach-Object {
                $_.content | Where-Object type -eq 'output_text' | ForEach-Object text
            }) -join '')
            if ([string]::IsNullOrWhiteSpace($text)) { throw 'DeepSeek completed without answer text or function calls.' }
            Write-AgentActivity -Activity $activity -Message 'Response completed' -Completed
            return [pscustomobject]@{
                Text = $text
                Conversation = @($instructionMessages) + @($body.input)
                MaxIterations = $MaxIterations
                RequestedEffortLevel = $EffortLevel
                ReasoningEffort = $reasoningEffort
                RequestedSpeedLevel = $null
                ServiceTier = $null
            }
        }
        Write-AgentActivity -Activity $activity -Message 'Stopped: maximum iterations reached' -Completed
        throw "Maximum iterations reached without completing the DeepSeek response after $MaxIterations iterations."
    }
    catch [System.Management.Automation.PipelineStoppedException] { throw }
    catch {
        Write-AgentActivity -Activity $activity -Message 'Request failed' -Completed
        throw
    }
    finally { Write-AgentActivity -Activity $activity -Message 'Request stopped' -Completed }
}
