function Get-OpenAICompatibleUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Endpoint,

        [Parameter(Mandatory)]
        [ValidateSet('chat/completions', 'models')]
        [string]$ResourcePath
    )

    $builder = [System.UriBuilder]$Endpoint.Trim()
    $path = $builder.Path.TrimEnd('/')

    if ($path.EndsWith('/chat/completions', [System.StringComparison]::OrdinalIgnoreCase)) {
        $path = $path.Substring(0, $path.Length - '/chat/completions'.Length)
    }
    elseif ($path.EndsWith('/models', [System.StringComparison]::OrdinalIgnoreCase)) {
        $path = $path.Substring(0, $path.Length - '/models'.Length)
    }

    $builder.Path = "$path/$ResourcePath"
    return $builder.Uri.AbsoluteUri
}
