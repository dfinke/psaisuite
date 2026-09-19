function Invoke-OpenAIToolExecutor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FunctionName,

        [hashtable]$FunctionArgs = @{},

        [string[]]$AllowedToolNames = @()
    )

    if (Get-Command Invoke-OpenAITool -ErrorAction SilentlyContinue) {
        return Invoke-OpenAITool -FunctionName $FunctionName -FunctionArgs $FunctionArgs
    }

    $resolvedCommand = Get-Command -Name $FunctionName -CommandType Cmdlet, Function, ExternalScript, Application -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $FunctionName } |
        Select-Object -First 1

    if ($AllowedToolNames -contains $FunctionName -and $resolvedCommand) {
        return (& $resolvedCommand.Name @FunctionArgs | Out-String)
    }

    return 'Error: Tool execution is unavailable because Invoke-OpenAITool is not loaded.'
}
