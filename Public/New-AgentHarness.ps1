function New-AgentHarness {
    <#
    .SYNOPSIS
    Creates a configurable agent harness over Invoke-ChatCompletion.

    .DESCRIPTION
    Returns an object with Model, Tools, SystemPrompt, and MaxIterations
    properties and a GetResponse(prompt) method. Each call starts a fresh
    conversation and delegates the model/tool loop to PSAISuite.
    Creating a harness does not call a model or execute its tools.

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
    $harness = New-AgentHarness -Tools Get-ChildItem
    $harness.GetResponse('List the files in the current directory.')

    .EXAMPLE
    $harness = New-AgentHarness -Model 'anthropic:claude-sonnet-4-6' -Tools Get-Date
    $harness.MaxIterations = 3
    $harness.GetResponse('What is the current date?')

    .NOTES
    This is a configuration wrapper, not a sandbox or conversation store.
    Provider credentials and model overrides follow Invoke-ChatCompletion.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory configuration object only; no model calls, tool execution, or external state changes occur during construction.')]
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$Model = 'openai:gpt-5.6-luna',

        [object[]]$Tools = @(),

        [string]$SystemPrompt = 'You are a helpful assistant.',

        [ValidateRange(1, 100)]
        [int]$MaxIterations = 5
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

    $harness
}
