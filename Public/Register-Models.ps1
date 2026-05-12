# ChatCompletionProviders is a top‑level list of supported providers, referenced for argument completion and tooltip display.
# Easily extended for future new providers.
# Tooltip can be custom per provider.
$script:ChatCompletionProviders = @{
    openai      = @{ Tooltip = 'AI Provider: OpenAI' }
    google      = @{ Tooltip = 'AI Provider: Google' }
    github      = @{ Tooltip = 'AI Provider: GitHub' }
    openrouter  = @{ Tooltip = 'AI Provider: OpenRouter' }
    anthropic   = @{ Tooltip = 'AI Provider: Anthropic' }
    deepseek    = @{ Tooltip = 'AI Provider: DeepSeek' }
    xai         = @{ Tooltip = 'AI Provider: xAI' }
    mistral     = @{ Tooltip = 'AI Provider: Mistral' }
    fireworksai = @{ Tooltip = 'AI Provider: Fireworks AI' }
    novita      = @{ Tooltip = 'AI Provider: Novita' }
    poe         = @{ Tooltip = 'AI Provider: Poe' }
}

function ConvertTo-ModelCatalogItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('id', 'name', 'model')]
        [string] $ModelId,
        [Parameter(Mandatory)]
        [string] $Provider,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Description,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Summary,
        [int] $MaxDescriptionWords = 100,
        [regex] $IdReplacementPattern = [string]::Empty
    )

    process {
        $normalizedDescription = if ($Description) { $Description }
        elseif ($Summary) { $Summary }
        else { "The $Provider $ModelId metadata does not include a description." }

        # Reform first 100 words of description as a description snippet as Arg Completer toolTips displays null with too much content.
        $normalizedDescription = (
            $normalizedDescription -split '\s+' | Select-Object -First $MaxDescriptionWords
        ) -join ' '

        # output model id and description - typically used by the argument completer.
        [pscustomobject]@{
            id          = [regex]::Replace($ModelId, $IdReplacementPattern, '') # Optional regex replacement to simplify each model id for toolTip display
            description = $normalizedDescription
        }
    }
}

Register-ArgumentCompleter -CommandName 'Invoke-ChatCompletion' -ParameterName 'Model' -ScriptBlock {
    param(
        [string] $commandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [System.Management.Automation.Language.CommandAst] $commandAst,
        [Collections.IDictionary] $fakeBoundParams
    )

    if ($wordToComplete -notmatch ':') {
        foreach ($providerName in $script:ChatCompletionProviders.Keys | Sort-Object) {

            # iterate provider names per model referencing each provider tooltip defined in ChatCompletionProviders
            $provider = $script:ChatCompletionProviders[$providerName]
            if ($providerName -like "$wordToComplete*") {
                [System.Management.Automation.CompletionResult]::new(
                    "${providerName}:",
                    $providerName,
                    [System.Management.Automation.CompletionResultType]::ParameterValue,
                    $provider.Tooltip
                )
            }
        }
        return
    }

    $providerName, $partialModelName = $wordToComplete -split ':', 2
    $providerKey = $providerName.ToLower()

    if (-not $script:ChatCompletionProviders[$providerKey]) {
        # provider not found in our supported provider list, return no completions
        return
    }

    # try/catch to fail gracefully (return only) when provider API processing encounters errors
    try {
        switch ($providerKey) {
            'openai' {
                $response = Invoke-RestMethod https://api.openai.com/v1/models -Headers @{"Authorization" = "Bearer $env:OpenAIKey" }
                $models = $response.data | ConvertTo-ModelCatalogItem -Provider $providerKey
            }
            'google' {
                $response = Invoke-RestMethod https://generativelanguage.googleapis.com/v1beta/models/?key=$env:GeminiKey
                # Also simplify each google model id by removing the "models/" prefix
                $models = $response.models | ConvertTo-ModelCatalogItem -Provider $providerKey -IdReplacementPattern '^models/'
            }
            'github' {
                $response = Invoke-RestMethod https://models.github.ai/catalog/models
                $models = $response | ConvertTo-ModelCatalogItem -Provider $providerKey
            }
            'openrouter' {
                $response = Invoke-RestMethod https://openrouter.ai/api/v1/models
                $models = $response.data | ConvertTo-ModelCatalogItem -Provider $providerKey
            }
            'anthropic' {
                $response = Invoke-RestMethod https://api.anthropic.com/v1/models -Headers @{
                    "x-api-key"         = $env:AnthropicKey
                    "anthropic-version" = "2023-06-01"
                }
                $models = $response.data | ConvertTo-ModelCatalogItem -Provider $providerKey
            }
            'deepseek' {
                $response = Invoke-RestMethod https://api.deepseek.com/models -Headers @{
                    "Authorization" = "Bearer $env:DeepSeekKey"
                    "content-type"  = "application/json"
                }

                $models = $response.data | ConvertTo-ModelCatalogItem -Provider $providerKey
            }
            'xai' {
                $response = Invoke-RestMethod https://api.x.ai/v1/models -Headers @{
                    'Authorization' = "Bearer $env:xAIKey"
                    'content-type'  = 'application/json'
                }

                $models = $response.data | ConvertTo-ModelCatalogItem -Provider $providerKey
            }
            'mistral' {
                $response = Invoke-RestMethod https://api.mistral.ai/v1/models -Headers @{
                    "Authorization" = "Bearer $env:MistralKey"
                    "Accept"        = "application/json"
                }

                $models = $response.data | ConvertTo-ModelCatalogItem -Provider $providerKey
            }
            'fireworksai' {
                if ($env:FireworksID) {
                    $candidateAccountId = $env:FireworksID.Trim()
                    if ($candidateAccountId -match '^[a-zA-Z0-9_-]+$') {
                        $account_id = $candidateAccountId
                    }
                    else {
                        $account_id = 'fireworks'
                    }
                }
                else {
                    $account_id = 'fireworks'
                }
                $escaped_account_id = [System.Uri]::EscapeDataString($account_id)
                $readMask = "readMask=name"
                $filter = "filter=supports_serverless=true AND supports_tools=true"
                $response = Invoke-RestMethod "https://api.fireworks.ai/v1/accounts/$escaped_account_id/models?$readMask&$filter" -Headers @{
                    'Authorization' = "Bearer $env:FireworksAIKey"
                    'Content-Type'  = 'application/json'
                }
                # return if no models were found for the specified account_id
                if (0 -eq $response.totalSize) {
                    $message = "No models were returned for account ID: $account_id"
                    $toolTip = "$message Check `$env:FireworksID if you expect deployed models for your own account, or remove it to fall back to the default fireworks catalog."
                    [System.Management.Automation.CompletionResult]::new(
                        "$wordToComplete ",
                        '(keep current model text)',
                        'ParameterValue',
                        $toolTip
                    )
                    [System.Management.Automation.CompletionResult]::new(
                        "$wordToComplete ",
                        $message,
                        'ParameterValue',
                        $toolTip
                    )
                    return
                }
                # Also simplify the fireworks model id by removing the "accounts/account_id/models/" prefix
                $models = $response.models | ConvertTo-ModelCatalogItem -Provider $providerKey -IdReplacementPattern ("accounts/$escaped_account_id/models/")
            }
            'novita' {
                $response = Invoke-RestMethod https://api.novita.ai/openai/v1/models -Headers @{
                    "Authorization" = "Bearer $env:NovitaKey"
                    "Content-Type"  = "application/json"
                }

                $models = $response.data | ConvertTo-ModelCatalogItem -Provider $providerKey
            }
            'poe' {
                ## Note: This endpoint does not require authentication and returns all publicly available models.
                ## However, including the API key in the header is prudent to avoid future regression.
                $response = Invoke-RestMethod https://api.poe.com/v1/models -Headers @{
                    "Authorization" = "Bearer $env:PoeKey"
                    "Content-Type"  = "application/json"
                }

                $models = $response.data | ConvertTo-ModelCatalogItem -Provider $providerKey
            }

            default {
                # don't error out if provider name is not recognized, just return no completions
                return
            }
        }
    }
    catch {
        return
    }

    $models | Sort-Object -Property id |
        Where-Object { $_.id -like "$partialModelName*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                "$($providerName):$($_.id)",
                $_.id,
                [System.Management.Automation.CompletionResultType]::ParameterValue,
                $_.description # model description as CompletionResult toolTip
            )
        }
}