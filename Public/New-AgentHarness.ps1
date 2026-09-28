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
    handled within each request by the provider. GetResponse starts a fresh
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

        [Parameter(Mandatory, ParameterSetName = 'Object')]
        [switch]$PassThru
    )

    $harness = [pscustomobject]@{
        Model         = $Model
        Tools         = $Tools
        SystemPrompt  = $SystemPrompt
        MaxIterations = $MaxIterations
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

        $response = Invoke-ChatCompletion @parameters
        $messages = $parameters.Messages + @(@{ role = 'assistant'; content = $response })
        $response
    }
}
