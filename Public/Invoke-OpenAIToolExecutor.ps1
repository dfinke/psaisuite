function Invoke-OpenAIToolExecutor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FunctionName,

        [hashtable]$FunctionArgs = @{},

        [string[]]$AllowedToolNames = @()
    )

    if ($AllowedToolNames -notcontains $FunctionName) {
        return "Error: Function $FunctionName is not allowed"
    }

    $resolvedCommand = Get-Command -Name $FunctionName -CommandType Cmdlet, Function, ExternalScript, Application -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $FunctionName } |
        Select-Object -First 1

    if (Get-Command Invoke-OpenAITool -ErrorAction SilentlyContinue) {
        return Invoke-OpenAITool -FunctionName $FunctionName -FunctionArgs $FunctionArgs
    }

    if ($resolvedCommand) {
        return (& $resolvedCommand @FunctionArgs | Out-String)
    }

    return "Error: Function $FunctionName not found"
}
