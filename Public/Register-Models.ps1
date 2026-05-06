$script:completionResults = 'openai', 'google', 'github', 'openrouter', 'anthropic', 'deepseek', 'xAI', 'mistral', 'fireworksai', 'novita', 'poe' | Sort-Object

Register-ArgumentCompleter -CommandName 'Invoke-ChatCompletion' -ParameterName 'Model' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParams)

    if ($wordToComplete -notmatch ':') {
        $script:completionResults | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new("$($_):", $_, 'ParameterValue', "Provider: $_")
        }
    }
    else {
        $provider, $partial = $wordToComplete -split ':', 2
        switch ($provider.ToLower()) {
            'openai' {
                $response = Invoke-RestMethod https://api.openai.com/v1/models -Headers @{"Authorization" = "Bearer $env:OPENAIKEY" }
                $models = $response.data.id
            }
            'google' {
                $response = Invoke-RestMethod https://generativelanguage.googleapis.com/v1beta/models/?key=$env:GEMINIKEY
                $models = $response.models.name -replace ("models/", "")
            }
            'github' {
                $models = (Invoke-RestMethod https://models.github.ai/catalog/models).id
            }
            'openrouter' {
                $models = (Invoke-RestMethod https://openrouter.ai/api/v1/models).data.id
            }
            'anthropic' {
                $response = Invoke-RestMethod https://api.anthropic.com/v1/models -Headers @{
                    "x-api-key"         = $env:ANTHROPICKEY
                    "anthropic-version" = "2023-06-01"
                }
                $models = $response.data.id
            }
            'deepseek' {
                $response = Invoke-RestMethod https://api.deepseek.com/models -Headers @{
                    "Authorization" = "Bearer $env:DEEPSEEKKEY"
                    "content-type"  = "application/json"
                }

                $models = $response.data.id
            }
            'xai' {
                $response = Invoke-RestMethod https://api.x.ai/v1/models -Headers @{
                    'Authorization' = "Bearer $env:xAIKey"
                    'content-type'  = 'application/json'
                }

                $models = $response.data.id
            }
            'mistral' {
                $response = Invoke-RestMethod https://api.mistral.ai/v1/models -Headers @{
                    "Authorization" = "Bearer $env:MistralKey"
                    "Accept"        = "application/json"
                }

                $models = $response.data.id | Sort-Object
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
                $models = $response.models.name | ForEach-Object { $_ -replace "^accounts/$([regex]::Escape($account_id))/models/" } | Sort-Object
            }
            'novita' {
                $response = Invoke-RestMethod https://api.novita.ai/openai/v1/models -Headers @{
                    "Authorization" = "Bearer $env:NovitaKey"
                    "Content-Type"  = "application/json"
                }

                $models = $response.data.id | Sort-Object
            }

            default {
                Write-Error "Unknown provider: $provider"
                return
            }
        }

        $models | Where-Object { $_ -like "$partial*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new("$($provider):$($_)", "$($provider):$($_)", 'ParameterValue', "Model: $($_)")
        }
    }
}