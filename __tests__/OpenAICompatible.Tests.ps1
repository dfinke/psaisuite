BeforeAll {
    Import-Module "$PSScriptRoot\..\PSAISuite.psd1" -Force
}

Describe 'Invoke-OpenAICompatibleProvider' {
    BeforeEach {
        $global:openAICompatibleOriginalEndpoint = $env:OpenAICompatibleEndpoint
        $global:openAICompatibleOriginalKey = $env:OpenAICompatibleKey
        $global:openAICompatibleOriginalAltKey = $env:OPENAI_COMPATIBLE_API_KEY
        $env:OpenAICompatibleEndpoint = 'https://example.invalid/v1'
        $env:OpenAICompatibleKey = 'test-compatible-key'
        Remove-Item Env:OPENAI_COMPATIBLE_API_KEY -ErrorAction SilentlyContinue
        $global:openAICompatibleRequest = $null

        Mock -ModuleName PSAISuite Invoke-RestMethod {
            param($Uri, $Method, $Headers, $Body)
            [void]($global:openAICompatibleRequest = [PSCustomObject]@{
                Uri     = $Uri
                Method  = $Method
                Headers = $Headers
                Body    = $Body | ConvertFrom-Json
            })

            [PSCustomObject]@{
                choices = @(
                    [PSCustomObject]@{
                        message = [PSCustomObject]@{
                            content = 'OpenAI-compatible response'
                        }
                    }
                )
            }
        }
    }

    AfterEach {
        if ($null -eq $global:openAICompatibleOriginalEndpoint) {
            Remove-Item Env:OpenAICompatibleEndpoint -ErrorAction SilentlyContinue
        }
        else {
            $env:OpenAICompatibleEndpoint = $global:openAICompatibleOriginalEndpoint
        }

        if ($null -eq $global:openAICompatibleOriginalKey) {
            Remove-Item Env:OpenAICompatibleKey -ErrorAction SilentlyContinue
        }
        else {
            $env:OpenAICompatibleKey = $global:openAICompatibleOriginalKey
        }

        if ($null -eq $global:openAICompatibleOriginalAltKey) {
            Remove-Item Env:OPENAI_COMPATIBLE_API_KEY -ErrorAction SilentlyContinue
        }
        else {
            $env:OPENAI_COMPATIBLE_API_KEY = $global:openAICompatibleOriginalAltKey
        }
    }

    It 'sends an OpenAI-compatible request to the configured endpoint' {
        InModuleScope PSAISuite {
            $global:openAICompatibleResult = Invoke-OpenAICompatibleProvider -ModelName 'meta-llama/Llama-3.1-8B-Instruct' -Messages @(@{ role = 'user'; content = 'Hello' })
        }

        $global:openAICompatibleResult | Should -Be 'OpenAI-compatible response'
        $global:openAICompatibleRequest.Uri | Should -Be 'https://example.invalid/v1/chat/completions'
        $global:openAICompatibleRequest.Method | Should -Be 'POST'
        $global:openAICompatibleRequest.Headers.Authorization | Should -Be 'Bearer test-compatible-key'
        $global:openAICompatibleRequest.Body.model | Should -Be 'meta-llama/Llama-3.1-8B-Instruct'
        $global:openAICompatibleRequest.Body.messages[0].content | Should -Be 'Hello'
        $global:openAICompatibleRequest.Body.stream | Should -BeFalse
    }

    It 'accepts a full chat completions endpoint without appending another path segment' {
        $env:OpenAICompatibleEndpoint = 'https://example.invalid/v1/chat/completions'

        InModuleScope PSAISuite {
            Invoke-OpenAICompatibleProvider -ModelName 'custom-model' -Messages @(@{ role = 'user'; content = 'Hello' }) | Out-Null
        }

        $global:openAICompatibleRequest.Uri | Should -Be 'https://example.invalid/v1/chat/completions'
    }

    It 'normalizes mixed-case chat completions paths without doubling segments' {
        $env:OpenAICompatibleEndpoint = 'https://example.invalid/v1/Chat/Completions?tenant=demo'

        InModuleScope PSAISuite {
            Invoke-OpenAICompatibleProvider -ModelName 'custom-model' -Messages @(@{ role = 'user'; content = 'Hello' }) | Out-Null
        }

        $global:openAICompatibleRequest.Uri | Should -Be 'https://example.invalid/v1/chat/completions?tenant=demo'
    }

    It 'preserves query strings when building the chat completions URI' {
        $env:OpenAICompatibleEndpoint = 'https://example.invalid/openai/v1?tenant=demo'

        InModuleScope PSAISuite {
            Invoke-OpenAICompatibleProvider -ModelName 'custom-model' -Messages @(@{ role = 'user'; content = 'Hello' }) | Out-Null
        }

        $global:openAICompatibleRequest.Uri | Should -Be 'https://example.invalid/openai/v1/chat/completions?tenant=demo'
    }

    It 'omits the authorization header when no key is configured' {
        Remove-Item Env:OpenAICompatibleKey -ErrorAction SilentlyContinue

        InModuleScope PSAISuite {
            Invoke-OpenAICompatibleProvider -ModelName 'custom-model' -Messages @(@{ role = 'user'; content = 'Hello' }) | Out-Null
        }

        $global:openAICompatibleRequest.Headers.ContainsKey('Authorization') | Should -BeFalse
    }

    It 'executes tool calls and sends tool output in the next request' {
        $global:openAICompatibleRequestCount = 0
        $global:openAICompatibleSecondRequest = $null
        Mock -ModuleName PSAISuite Invoke-RestMethod {
            param($Uri, $Method, $Headers, $Body)
            [void]($global:openAICompatibleRequestCount++)
            $request = $Body | ConvertFrom-Json

            if ($global:openAICompatibleRequestCount -eq 1) {
                return [PSCustomObject]@{
                    choices = @(
                        [PSCustomObject]@{
                            message = [PSCustomObject]@{
                                role       = 'assistant'
                                content    = $null
                                tool_calls = @(
                                    [PSCustomObject]@{
                                        id       = 'call-1'
                                        function = [PSCustomObject]@{
                                            name      = 'Get-Date'
                                            arguments = '{}'
                                        }
                                    }
                                )
                            }
                        }
                    )
                }
            }

            [void]($global:openAICompatibleSecondRequest = $request)
            [PSCustomObject]@{
                choices = @(
                    [PSCustomObject]@{
                        message = [PSCustomObject]@{ content = 'Tool completed' }
                    }
                )
            }
        }

        InModuleScope PSAISuite {
            $global:openAICompatibleResult = Invoke-OpenAICompatibleProvider -ModelName 'custom-model' -Messages @(@{ role = 'user'; content = 'Use a tool' }) -MaxIterations 2
        }

        $global:openAICompatibleResult | Should -Be 'Tool completed'
        $global:openAICompatibleRequestCount | Should -Be 2
        @($global:openAICompatibleSecondRequest.messages | Where-Object { $_.role -eq 'tool' }).Count | Should -Be 1
        ($global:openAICompatibleSecondRequest.messages | Where-Object { $_.role -eq 'tool' }).tool_call_id | Should -Be 'call-1'
    }

    It 'reports a clear error when no endpoint is configured' {
        Remove-Item Env:OpenAICompatibleEndpoint -ErrorAction SilentlyContinue

        InModuleScope PSAISuite {
            {
                Invoke-OpenAICompatibleProvider -ModelName 'custom-model' -Messages @(@{ role = 'user'; content = 'Hello' }) | Out-Null
            } | Should -Throw '*OpenAICompatibleEndpoint*'
        }
    }
}

Describe 'OpenAI-compatible provider dispatch' {
    It 'accepts OpenAI-compatible models and forwards MaxIterations' {
        $global:openAICompatibleDispatch = $null
        Mock -ModuleName PSAISuite Invoke-OpenAICompatibleProvider {
            param($ModelName, $Messages, $MaxIterations)
            [void]($global:openAICompatibleDispatch = @{
                ModelName     = $ModelName
                MaxIterations = $MaxIterations
            })
            'dispatch response'
        }

        $result = Invoke-ChatCompletion -Messages 'Test prompt' -Model 'openaicompatible:custom-model' -MaxIterations 3

        $result | Should -Be 'dispatch response'
        $global:openAICompatibleDispatch.ModelName | Should -Be 'custom-model'
        $global:openAICompatibleDispatch.MaxIterations | Should -Be 3
    }
}

Describe 'OpenAI-compatible model completion' {
    BeforeEach {
        $global:openAICompatibleOriginalEndpoint = $env:OpenAICompatibleEndpoint
        $global:openAICompatibleOriginalKey = $env:OpenAICompatibleKey
        $env:OpenAICompatibleEndpoint = 'https://example.invalid/v1'
        $env:OpenAICompatibleKey = 'test-compatible-key'
        $global:openAICompatibleDiscoveryHeaders = $null
        $global:openAICompatibleDiscoveryUri = $null

        Mock -ModuleName PSAISuite Invoke-RestMethod {
            param($Uri, $Headers)
            $global:openAICompatibleDiscoveryHeaders = $Headers
            $global:openAICompatibleDiscoveryUri = $Uri

            [PSCustomObject]@{
                data = @(
                    [PSCustomObject]@{
                        id          = 'custom-model'
                        description = 'A hosted test model'
                    }
                )
            }
        }
    }

    AfterEach {
        if ($null -eq $global:openAICompatibleOriginalEndpoint) {
            Remove-Item Env:OpenAICompatibleEndpoint -ErrorAction SilentlyContinue
        }
        else {
            $env:OpenAICompatibleEndpoint = $global:openAICompatibleOriginalEndpoint
        }

        if ($null -eq $global:openAICompatibleOriginalKey) {
            Remove-Item Env:OpenAICompatibleKey -ErrorAction SilentlyContinue
        }
        else {
            $env:OpenAICompatibleKey = $global:openAICompatibleOriginalKey
        }
    }

    It 'uses the configured bearer token for model discovery' {
        $completion = TabExpansion2 -inputScript 'Invoke-ChatCompletion -Model openaicompatible:c' -cursorColumn 47

        $global:openAICompatibleDiscoveryHeaders.Authorization | Should -Be 'Bearer test-compatible-key'
        $completion.CompletionMatches.CompletionText | Should -Contain 'openaicompatible:custom-model'
    }

    It 'preserves query strings when building the models URI' {
        $env:OpenAICompatibleEndpoint = 'https://example.invalid/openai/v1?tenant=demo'

        $completion = TabExpansion2 -inputScript 'Invoke-ChatCompletion -Model openaicompatible:c' -cursorColumn 47

        $completion.CompletionMatches.CompletionText | Should -Contain 'openaicompatible:custom-model'
        $global:openAICompatibleDiscoveryUri | Should -Be 'https://example.invalid/openai/v1/models?tenant=demo'
    }

    It 'does not double models paths when the configured endpoint already ends with models' {
        $env:OpenAICompatibleEndpoint = 'https://example.invalid/openai/v1/models?tenant=demo'

        $completion = TabExpansion2 -inputScript 'Invoke-ChatCompletion -Model openaicompatible:c' -cursorColumn 47

        $completion.CompletionMatches.CompletionText | Should -Contain 'openaicompatible:custom-model'
        $global:openAICompatibleDiscoveryUri | Should -Be 'https://example.invalid/openai/v1/models?tenant=demo'
    }

    It 'returns no completions when model discovery fails' {
        Mock -ModuleName PSAISuite Invoke-RestMethod { throw 'discovery failed' }

        $completion = TabExpansion2 -inputScript 'Invoke-ChatCompletion -Model openaicompatible:c' -cursorColumn 47

        @($completion.CompletionMatches).Count | Should -Be 0
    }
}
