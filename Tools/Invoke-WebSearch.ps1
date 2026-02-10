function Invoke-WebSearch {
    param(
        [Parameter(Mandatory)]
        [string]$query

    )

    $tavilyParams = @{
        api_key = $env:TAVILY_API_KEY
        query   = $query
    }

    $body = $tavilyParams | ConvertTo-Json -Depth 10

    Invoke-RestMethod -Method Post -Uri "https://api.tavily.com/search" -ContentType 'application/json' -Body $body
}