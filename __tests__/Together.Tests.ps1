BeforeAll {
    Import-Module "$PSScriptRoot\..\PSAISuite.psd1" -Force
}

Describe 'Invoke-TogetherProvider' {
    BeforeEach {
        $global:togetherOriginalApiKey = $env:TOGETHER_API_KEY
        $env:TOGETHER_API_KEY = 'test-together-key'
        $global:togetherRequest = $null

        Mock -ModuleName PSAISuite Invoke-RestMethod {
            param($Uri, $Method, $Headers, $Body)
            [void]($global:togetherRequest = [PSCustomObject]@{
                Uri     = $Uri
                Method  = $Method
                Headers = $Headers
                Body    = $Body | ConvertFrom-Json
            })

            [PSCustomObject]@{
                choices = @(
                    [PSCustomObject]@{
                        message = [PSCustomObject]@{
                            content = 'Together response'
                        }
                    }
                )
            }
        }
    }

    AfterEach {
        if ($null -eq $global:togetherOriginalApiKey) {
            Remove-Item Env:TOGETHER_API_KEY -ErrorAction SilentlyContinue
        }
        else {
            $env:TOGETHER_API_KEY = $global:togetherOriginalApiKey
        }
    }

    It 'sends an OpenAI-compatible request to Together AI' {
        InModuleScope PSAISuite {
            $global:togetherResult = Invoke-TogetherProvider -ModelName 'openai/gpt-oss-20b' -Messages @(@{ role = 'user'; content = 'Hello' })
        }

        $global:togetherResult | Should -Be 'Together response'
        $global:togetherRequest.Uri | Should -Be 'https://api.together.xyz/v1/chat/completions'
        $global:togetherRequest.Method | Should -Be 'POST'
        $global:togetherRequest.Headers.Authorization | Should -Be '******'
        $global:togetherRequest.Body.model | Should -Be 'openai/gpt-oss-20b'
        $global:togetherRequest.Body.messages[0].content | Should -Be 'Hello'
        $global:togetherRequest.Body.stream | Should -BeFalse
    }

    It 'executes tool calls and sends tool output in the next request' {
        $global:togetherRequestCount = 0
        $global:togetherSecondRequest = $null

        Mock -ModuleName PSAISuite ConvertTo-ProviderToolSchema {
            @(
                @{
                    type     = 'function'
                    function = @{
                        name        = 'Get-Date'
                        description = 'Get the current date'
                        parameters  = @{
                            type       = 'object'
                            properties = @{}
                        }
                    }
                }
            )
        }

        Mock -ModuleName PSAISuite Invoke-OpenAITool { 'tool output' }

        Mock -ModuleName PSAISuite Invoke-RestMethod {
            param($Uri, $Method, $Headers, $Body)
            [void]($global:togetherRequestCount++)
            $request = $Body | ConvertFrom-Json

            if ($global:togetherRequestCount -eq 1) {
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

            [void]($global:togetherSecondRequest = $request)
            [PSCustomObject]@{
                choices = @(
                    [PSCustomObject]@{
                        message = [PSCustomObject]@{ content = 'Tool completed' }
                    }
                )
            }
        }

        InModuleScope PSAISuite {
            $tool = @{
                Name        = 'Get-Date'
                Description = 'Get the current date'
                Parameters  = @{
                    type       = 'object'
                    properties = @{}
                }
            }

            $global:togetherResult = Invoke-TogetherProvider -ModelName 'openai/gpt-oss-20b' -Messages @(@{ role = 'user'; content = 'Use a tool' }) -Tools $tool -MaxIterations 2
        }

        $global:togetherResult | Should -Be 'Tool completed'
        $global:togetherRequestCount | Should -Be 2
        @($global:togetherSecondRequest.messages | Where-Object { $_.role -eq 'tool' }).Count | Should -Be 1
        ($global:togetherSecondRequest.messages | Where-Object { $_.role -eq 'tool' }).tool_call_id | Should -Be 'call-1'
        ($global:togetherSecondRequest.messages | Where-Object { $_.role -eq 'tool' }).content | Should -Be 'tool output'
    }

    It 'reports a clear error when the API key is missing' {
        Remove-Item Env:TOGETHER_API_KEY -ErrorAction SilentlyContinue
        $global:togetherError = $null

        Mock -ModuleName PSAISuite Write-Error {
            param($Message)
            $global:togetherError = $Message
        }

        InModuleScope PSAISuite {
            Invoke-TogetherProvider -ModelName 'openai/gpt-oss-20b' -Messages @(@{ role = 'user'; content = 'Hello' }) | Out-Null
        }

        $global:togetherError | Should -Match 'TOGETHER_API_KEY'
    }
}

Describe 'Together provider dispatch and completion' {
    It 'accepts Together models' {
        Mock -ModuleName PSAISuite Invoke-TogetherProvider {
            param($ModelName, $Messages)
            $global:togetherDispatch = @{
                ModelName = $ModelName
                Messages  = $Messages
            }
            'dispatch response'
        }

        $result = Invoke-ChatCompletion -Messages 'Hello' -Model 'together:openai/gpt-oss-20b'

        $result | Should -Be 'dispatch response'
        $global:togetherDispatch.ModelName | Should -Be 'openai/gpt-oss-20b'
        $global:togetherDispatch.Messages[0].content | Should -Be 'Hello'
    }

    It 'offers Together as a provider completion' {
        $line = 'Invoke-ChatCompletion -Model toget'
        $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length

        $result.CompletionMatches.CompletionText | Should -Contain 'together:'
    }

    It 'returns Together model completions from the catalog endpoint' {
        $originalApiKey = $env:TOGETHER_API_KEY
        $env:TOGETHER_API_KEY = 'test-together-key'

        Mock -ModuleName PSAISuite Invoke-RestMethod {
            [PSCustomObject]@{
                data = @(
                    [PSCustomObject]@{
                        id          = 'openai/gpt-oss-20b'
                        description = 'Together model'
                    }
                )
            }
        }

        try {
            $line = 'Invoke-ChatCompletion -Model together:'
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length

            $result.CompletionMatches.CompletionText | Should -Contain 'together:openai/gpt-oss-20b'
        }
        finally {
            if ($null -eq $originalApiKey) {
                Remove-Item Env:TOGETHER_API_KEY -ErrorAction SilentlyContinue
            }
            else {
                $env:TOGETHER_API_KEY = $originalApiKey
            }
        }
    }
}
