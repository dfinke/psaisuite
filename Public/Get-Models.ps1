Register-ArgumentCompleter -CommandName 'Get-Models' -ParameterName 'Model' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParams)
   
    if ($wordToComplete -notmatch ':') {
        $completionResults = 'openai', 'google', 'github', 'openrouter'
        $completionResults | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new("$($_):", $_, 'ParameterValue', "Provider: $_")
        }
    }    
    else {
        $provider, $partial = $wordToComplete -split ':', 2
        switch ($provider.ToLower()) {
            'openai' {                
                $response = Invoke-RestMethod https://api.openai.com/v1/models -Headers @{"Authorization" = "Bearer $env:OPENAI_API_KEY" }
                $models = $response.data.id 
            }
            'google' {
                $response = Invoke-RestMethod https://generativelanguage.googleapis.com/v1beta/models/?key=$env:GEMINIKEY
                $models = $response.models.name -replace ("models/", "") 
            }
            'github' {
                $models = (Invoke-RestMethod https://models.inference.ai.azure.com/models).name
            }
            'openrouter' {
                $models = (Invoke-RestMethod https://models.github.ai/catalog/models).id
            }
            default {
                $models = @()
            }
        }
        
        $models | Where-Object { $_ -like "$partial*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new("$($provider):$($_)", "$($provider):$($_)", 'ParameterValue', "Model: $($_)")
        }
    }
}

function Get-Models {
    param(
        [string]$Model
    )

    $Model
}