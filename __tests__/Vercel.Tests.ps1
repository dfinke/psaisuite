BeforeAll {
    Import-Module "$PSScriptRoot\..\PSAISuite.psd1" -Force
}

Describe 'Invoke-VercelProvider' {
    BeforeEach {
        $global:vercelOriginalGatewayKey = $env:AI_GATEWAY_API_KEY
        $global:vercelOriginalOidcToken = $env:VERCEL_OIDC_TOKEN
        $env:AI_GATEWAY_API_KEY = 'test-gateway-key'
        Remove-Item Env:VERCEL_OIDC_TOKEN -ErrorAction SilentlyContinue
        $global:vercelRequest = $null

        Mock -ModuleName PSAISuite Invoke-RestMethod {
            param($Uri, $Method, $Headers, $Body)
            [void]($global:vercelRequest = [PSCustomObject]@{
                Uri     = $Uri
                Method  = $Method
                Headers = $Headers
                Body    = $Body | ConvertFrom-Json
            })

            [PSCustomObject]@{
                choices = @(
                    [PSCustomObject]@{
                        message = [PSCustomObject]@{
                            content = 'Vercel response'
                        }
                    }
                )
            }
        }
    }

    AfterEach {
        if ($null -eq $global:vercelOriginalGatewayKey) {
            Remove-Item Env:AI_GATEWAY_API_KEY -ErrorAction SilentlyContinue
        }
        else {
            $env:AI_GATEWAY_API_KEY = $global:vercelOriginalGatewayKey
        }

        if ($null -eq $global:vercelOriginalOidcToken) {
            Remove-Item Env:VERCEL_OIDC_TOKEN -ErrorAction SilentlyContinue
        }
        else {
            $env:VERCEL_OIDC_TOKEN = $global:vercelOriginalOidcToken
        }
    }

    It 'sends an OpenAI-compatible request to AI Gateway' {
        InModuleScope PSAISuite {
            $global:vercelResult = Invoke-VercelProvider -ModelName 'anthropic/claude-sonnet-4.6' -Messages @(@{ role = 'user'; content = 'Hello' })
        }

        $global:vercelResult | Should -Be 'Vercel response'
        $global:vercelRequest.Uri | Should -Be 'https://ai-gateway.vercel.sh/v1/chat/completions'
        $global:vercelRequest.Method | Should -Be 'POST'
        $global:vercelRequest.Headers.Authorization | Should -Be 'Bearer test-gateway-key'
        $global:vercelRequest.Body.model | Should -Be 'anthropic/claude-sonnet-4.6'
        $global:vercelRequest.Body.messages[0].content | Should -Be 'Hello'
        $global:vercelRequest.Body.stream | Should -BeFalse
    }

    It 'uses the OIDC token when an AI Gateway API key is absent' {
        Remove-Item Env:AI_GATEWAY_API_KEY -ErrorAction SilentlyContinue
        $env:VERCEL_OIDC_TOKEN = 'test-oidc-token'

        InModuleScope PSAISuite {
            Invoke-VercelProvider -ModelName 'openai/gpt-5.6' -Messages @(@{ role = 'user'; content = 'Hello' }) | Out-Null
        }

        $global:vercelRequest.Headers.Authorization | Should -Be 'Bearer test-oidc-token'
    }

    It 'executes tool calls and sends tool output in the next request' {
        $global:vercelRequestCount = 0
        $global:vercelSecondRequest = $null
        Mock -ModuleName PSAISuite Invoke-RestMethod {
            param($Uri, $Method, $Headers, $Body)
            [void]($global:vercelRequestCount++)
            $request = $Body | ConvertFrom-Json

            if ($global:vercelRequestCount -eq 1) {
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

            [void]($global:vercelSecondRequest = $request)
            [PSCustomObject]@{
                choices = @(
                    [PSCustomObject]@{
                        message = [PSCustomObject]@{ content = 'Tool completed' }
                    }
                )
            }
        }

        InModuleScope PSAISuite {
            $global:vercelResult = Invoke-VercelProvider -ModelName 'openai/gpt-5.6' -Messages @(@{ role = 'user'; content = 'Use a tool' }) -MaxIterations 2
        }

        $global:vercelResult | Should -Be 'Tool completed'
        $global:vercelRequestCount | Should -Be 2
        @($global:vercelSecondRequest.messages | Where-Object { $_.role -eq 'tool' }).Count | Should -Be 1
        ($global:vercelSecondRequest.messages | Where-Object { $_.role -eq 'tool' }).tool_call_id | Should -Be 'call-1'
    }

    It 'stops after the configured number of tool-calling rounds' {
        Mock -ModuleName PSAISuite Invoke-RestMethod {
            [PSCustomObject]@{
                choices = @(
                    [PSCustomObject]@{
                        message = [PSCustomObject]@{
                            content    = $null
                            tool_calls = @(
                                [PSCustomObject]@{
                                    id       = 'call-loop'
                                    function = [PSCustomObject]@{ name = 'Get-Date'; arguments = '{}' }
                                }
                            )
                        }
                    }
                )
            }
        }

        InModuleScope PSAISuite {
            $global:vercelResult = Invoke-VercelProvider -ModelName 'openai/gpt-5.6' -Messages @(@{ role = 'user'; content = 'Use a tool' }) -MaxIterations 2
        }

        $global:vercelResult | Should -Be 'Maximum iterations reached without completing the response after 2 iterations.'
    }

    It 'reports a clear error when no credential is configured' {
        Remove-Item Env:AI_GATEWAY_API_KEY -ErrorAction SilentlyContinue
        Remove-Item Env:VERCEL_OIDC_TOKEN -ErrorAction SilentlyContinue
        $global:vercelError = $null
        Mock -ModuleName PSAISuite Write-Error {
            param($Message)
            $global:vercelError = $Message
        }

        InModuleScope PSAISuite {
            Invoke-VercelProvider -ModelName 'openai/gpt-5.6' -Messages @(@{ role = 'user'; content = 'Hello' }) | Out-Null
        }

        $global:vercelError | Should -Match 'AI_GATEWAY_API_KEY or VERCEL_OIDC_TOKEN'
    }
}

Describe 'Vercel provider dispatch' {
    It 'accepts Vercel models and forwards MaxIterations' {
        $global:vercelDispatch = $null
        Mock -ModuleName PSAISuite Invoke-VercelProvider {
            param($ModelName, $Messages, $MaxIterations)
            [void]($global:vercelDispatch = @{
                ModelName     = $ModelName
                MaxIterations = $MaxIterations
            })
            'dispatch response'
        }

        $result = Invoke-ChatCompletion -Messages 'Test prompt' -Model 'vercel:openai/gpt-5.6' -MaxIterations 3

        $result | Should -Be 'dispatch response'
        $global:vercelDispatch.ModelName | Should -Be 'openai/gpt-5.6'
        $global:vercelDispatch.MaxIterations | Should -Be 3
    }
}
