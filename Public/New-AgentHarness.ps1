function New-AgentHarness {
    <#
    .SYNOPSIS
    Runs an agent with a prompt or an interactive conversation.

    .DESCRIPTION
    With Prompt, runs one request through PSAISuite's model/tool loop and
    returns the response. Without Prompt, reads input with Read-Host and
    retains user messages and final assistant replies for follow-up turns.
    Enter exit, quit, or an empty line to end the interactive conversation.
    Use PassThru to return an editable harness without starting a conversation.
    OpenAI, Anthropic, DeepSeek, and Vercel show request/tool progress while running.
    Add Verbose to retain the activity log. Progress is separate from the answer.

    .PARAMETER Prompt
    The prompt to run immediately, including any tool calls needed to answer it.
    Omit this parameter to start an interactive conversation.

    .PARAMETER PassThru
    Return the configuration object with a GetResponse(prompt) method without
    reading input, calling a model, or executing tools. Cannot be used with Prompt.

    .PARAMETER Model
    The provider:model identifier. Defaults to openai:gpt-5.6-luna.

    .PARAMETER Tools
    PowerShell command names or tool schemas accepted by Invoke-ChatCompletion.
    Defaults to no tools.

    .PARAMETER SystemPrompt
    Instructions sent with each request.

    .PARAMETER MaxIterations
    Maximum tool-calling rounds for providers that support this setting.

    .PARAMETER ToolRoot
    DeepSeek's file-tool boundary. Defaults to the directory where the harness
    is created and stays fixed across interactive turns. It confines built-in
    Get-ChildItem and Get-Content; custom functions retain session permissions.

    .PARAMETER ToolPolicy
    Local execution options for DeepSeek: configurable read/output/listing
    limits and a BeforeInvoke permission callback. Does not change the model's
    reasoning capabilities. Resource limits can be raised or disabled with zero.

    .EXAMPLE
    New-AgentHarness -Prompt 'List the files in the current directory.' -Tools Get-ChildItem

    .EXAMPLE
    New-AgentHarness -Model 'anthropic:claude-sonnet-4-6' -Tools Get-Date

    Starts an interactive conversation. Enter exit or quit to finish.

    .EXAMPLE
    $harness = New-AgentHarness -PassThru -Tools Get-Date
    $harness.MaxIterations = 3
    $harness.GetResponse('What is the current date?')

    .NOTES
    Interactive history lasts only for this invocation. Tool exchanges are
    handled within each request by the provider. DeepSeek also retains the
    complete Responses conversation between interactive turns, including
    reasoning and tool results. GetResponse starts a fresh
    conversation on each call. Tools run with the current user's permissions.
    Provider credentials and model overrides follow Invoke-ChatCompletion.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Delegates requests and tool execution to Invoke-ChatCompletion; PassThru only creates an in-memory configuration object.')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Displays interactive exit instructions on the host without mixing them into response output.')]
    [CmdletBinding(DefaultParameterSetName = 'Run')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Run')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$Prompt,

        [ValidateNotNullOrEmpty()]
        [string]$Model = 'openai:gpt-5.6-luna',

        [object[]]$Tools = @(),

        [string]$SystemPrompt = 'You are a helpful assistant.',

        [ValidateRange(1, 100)]
        [int]$MaxIterations = 5,

        [ValidateNotNullOrEmpty()]
        [string]$ToolRoot,

        [hashtable]$ToolPolicy,

        [Parameter(Mandatory, ParameterSetName = 'Object')]
        [switch]$PassThru
    )

    $effectiveModel = if ($env:PSAISUITE_DEFAULT_MODEL) { $env:PSAISUITE_DEFAULT_MODEL } else { $Model }
    if (($PSBoundParameters.ContainsKey('ToolRoot') -or $PSBoundParameters.ContainsKey('ToolPolicy')) -and $effectiveModel -notlike 'deepseek:*') {
        throw 'ToolRoot and ToolPolicy are currently supported only for the DeepSeek provider.'
    }
    if ($effectiveModel -like 'deepseek:*') {
        if (-not $ToolRoot) { $ToolRoot = (Get-Location).Path }
        $policy = New-AgentToolPolicy -Root $ToolRoot -Options $ToolPolicy
        $ToolRoot = $policy.Root
    }
    $harness = [pscustomobject]@{
        Model         = $Model
        Tools         = $Tools
        SystemPrompt  = $SystemPrompt
        MaxIterations = $MaxIterations
        ToolRoot      = $ToolRoot
        ToolPolicy    = $ToolPolicy
    }

    $harness | Add-Member -MemberType ScriptMethod -Name GetResponse -Value {
        param(
            [ValidateNotNullOrEmpty()]
            [string]$Prompt
        )

        $parameters = @{
            Messages = @(
                @{ role = 'system'; content = $this.SystemPrompt }
                @{ role = 'user'; content = $Prompt }
            )
            Model         = $this.Model
            Tools         = $this.Tools
            MaxIterations = $this.MaxIterations
        }

        if ($this.ToolRoot) { $parameters.ToolRoot = $this.ToolRoot }
        if ($null -ne $this.ToolPolicy) { $parameters.ToolPolicy = $this.ToolPolicy }
        Invoke-ChatCompletion @parameters
    }

    if ($PassThru) {
        return $harness
    }

    if ($PSBoundParameters.ContainsKey('Prompt')) {
        return $harness.GetResponse($Prompt)
    }

    $messages = @(@{ role = 'system'; content = $SystemPrompt })
    Write-Host 'Enter a prompt. Type exit or quit, or press Enter on an empty line, to finish.'

    while ($true) {
        $userInput = Read-Host -Prompt 'You'
        if ([string]::IsNullOrWhiteSpace($userInput) -or $userInput.Trim() -in @('exit', 'quit')) {
            break
        }

        $parameters = @{
            Messages      = $messages + @(@{ role = 'user'; content = $userInput })
            Model         = $Model
            Tools         = $Tools
            MaxIterations = $MaxIterations
            ErrorAction   = 'Stop'
        }

        $effectiveModel = if ($env:PSAISUITE_DEFAULT_MODEL) { $env:PSAISUITE_DEFAULT_MODEL } else { $Model }
        if ($effectiveModel -like 'deepseek:*') {
            $parameters.ToolRoot = $harness.ToolRoot
            if ($null -ne $harness.ToolPolicy) { $parameters.ToolPolicy = $harness.ToolPolicy }
            $result = Invoke-ChatCompletion @parameters -Raw
            $messages = @($result.Conversation)
            $result.Response
        }
        else {
            $response = Invoke-ChatCompletion @parameters
            $messages = $parameters.Messages + @(@{ role = 'assistant'; content = $response })
            $response
        }
    }
}
