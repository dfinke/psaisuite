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

    if ($AllowedToolNames -contains $FunctionName -and (Get-Command $FunctionName -ErrorAction SilentlyContinue)) {
        return (& $FunctionName @FunctionArgs | Out-String)
    }

    return 'Error: Tool execution is unavailable because Invoke-OpenAITool is not loaded.'
}
