function Invoke-OpenAIToolExecutor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FunctionName,

        [hashtable]$FunctionArgs = @{}
    )

    if (Get-Command Invoke-OpenAITool -ErrorAction SilentlyContinue) {
        return Invoke-OpenAITool -FunctionName $FunctionName -FunctionArgs $FunctionArgs
    }

    return 'Error: Tool execution is unavailable because Invoke-OpenAITool is not loaded.'
}
