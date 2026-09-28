BeforeAll {
    Import-Module "$PSScriptRoot\..\PSAISuite.psd1" -Force
}

Describe 'Invoke-BasetenProvider' {
    BeforeEach {
        $global:basetenOriginalApiKey = $env:BASETEN_API_KEY
        $env:BASETEN_API_KEY = 'test-baseten-key'
        $global:basetenRequest = $null

        Mock -ModuleName PSAISuite Invoke-RestMethod {
            param($Uri, $Method, $Headers, $Body)
            [void]($global:basetenRequest = [PSCustomObject]@{
                Uri     = $Uri
                Method  = $Method
                Headers = $Headers
                Body    = $Body | ConvertFrom-Json
            })

            [PSCustomObject]@{
                choices = @(
                    [PSCustomObject]@{
                        message = [PSCustomObject]@{
                            content = 'Baseten response'
                        }
                    }
                )
            }
        }
    }

    AfterEach {
        if ($null -eq $global:basetenOriginalApiKey) {
            Remove-Item Env:BASETEN_API_KEY -ErrorAction SilentlyContinue
        }
        else {
            $env:BASETEN_API_KEY = $global:basetenOriginalApiKey
        }
    }

    It 'sends an OpenAI-compatible request to Baseten' {
        InModuleScope PSAISuite {
            $global:basetenResult = Invoke-BasetenProvider -ModelName 'openai/gpt-oss-120b' -Messages @(@{ role = 'user'; content = 'Hello' })
        }

        $global:basetenResult | Should -Be 'Baseten response'
        $global:basetenRequest.Uri | Should -Be 'https://inference.baseten.co/v1/chat/completions'
        $global:basetenRequest.Method | Should -Be 'POST'
        $global:basetenRequest.Headers.Authorization | Should -Be '******'
        $global:basetenRequest.Body.model | Should -Be 'openai/gpt-oss-120b'
        $global:basetenRequest.Body.messages[0].content | Should -Be 'Hello'
    }

    It 'executes tool calls and sends tool output in the next request' {
        $global:basetenRequestCount = 0
        $global:basetenSecondRequest = $null

        Mock -ModuleName PSAISuite Invoke-RestMethod {
            param($Uri, $Method, $Headers, $Body)
            [void]($global:basetenRequestCount++)
            $request = $Body | ConvertFrom-Json

            if ($global:basetenRequestCount -eq 1) {
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

            [void]($global:basetenSecondRequest = $request)
            [PSCustomObject]@{
                choices = @(
                    [PSCustomObject]@{
                        message = [PSCustomObject]@{ content = 'Tool completed' }
                    }
                )
            }
        }

        InModuleScope PSAISuite {
            $global:basetenResult = Invoke-BasetenProvider -ModelName 'openai/gpt-oss-120b' -Messages @(@{ role = 'user'; content = 'Use a tool' })
        }

        $global:basetenResult | Should -Be 'Tool completed'
        $global:basetenRequestCount | Should -Be 2
        @($global:basetenSecondRequest.messages | Where-Object { $_.role -eq 'tool' }).Count | Should -Be 1
        ($global:basetenSecondRequest.messages | Where-Object { $_.role -eq 'tool' }).tool_call_id | Should -Be 'call-1'
    }

    It 'reports a clear error when BASETEN_API_KEY is missing' {
        Remove-Item Env:BASETEN_API_KEY -ErrorAction SilentlyContinue
        $global:basetenError = $null
        Mock -ModuleName PSAISuite Write-Error {
            param($Message)
            $global:basetenError = $Message
        }

        InModuleScope PSAISuite {
            Invoke-BasetenProvider -ModelName 'openai/gpt-oss-120b' -Messages @(@{ role = 'user'; content = 'Hello' }) | Out-Null
        }

        $global:basetenError | Should -Match 'BASETEN_API_KEY'
    }
}

Describe 'Baseten provider dispatch and completion' {
    It 'accepts Baseten model syntax through Invoke-ChatCompletion' {
        $global:basetenDispatch = $null
        Mock -ModuleName PSAISuite Invoke-BasetenProvider {
            param($ModelName, $Messages, $Tools)
            [void]($global:basetenDispatch = @{
                ModelName = $ModelName
                Messages  = $Messages
                Tools     = $Tools
            })
            'dispatch response'
        }

        $result = Invoke-ChatCompletion -Messages 'Test prompt' -Model 'baseten:openai/gpt-oss-120b'

        $result | Should -Be 'dispatch response'
        $global:basetenDispatch.ModelName | Should -Be 'openai/gpt-oss-120b'
        $global:basetenDispatch.Messages[0].content | Should -Be 'Test prompt'
    }

    It 'registers Baseten in the provider completer catalog' {
        InModuleScope PSAISuite {
            $script:ChatCompletionProviders.ContainsKey('baseten') | Should -BeTrue
        }
    }

    It 'returns Baseten model completions from the OpenAI-compatible models endpoint' {
        Mock -ModuleName PSAISuite Invoke-RestMethod {
            [PSCustomObject]@{
                data = @(
                    [PSCustomObject]@{
                        id          = 'openai/gpt-oss-120b'
                        description = 'Baseten hosted model'
                    }
                )
            }
        }

        $inputScript = 'Invoke-ChatCompletion -Model baseten:o'
        $completion = TabExpansion2 -inputScript $inputScript -cursorColumn $inputScript.Length

        $completion.CompletionMatches.CompletionText | Should -Contain 'baseten:openai/gpt-oss-120b'
    }
}
