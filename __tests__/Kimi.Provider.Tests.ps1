BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
    Import-Module "$ProjectRoot\PSAISuite.psd1" -Force
    $script:PSAISuiteModule = Get-Module PSAISuite
    $script:OriginalKimiApiKey = $env:KIMI_API_KEY
}

AfterAll {
    if ($null -eq $script:OriginalKimiApiKey) {
        Remove-Item Env:\KIMI_API_KEY -ErrorAction SilentlyContinue
    }
    else {
        $env:KIMI_API_KEY = $script:OriginalKimiApiKey
    }
}

Describe 'Kimi provider' {
    BeforeEach {
        $env:KIMI_API_KEY = 'test-kimi-key'
    }

    It 'is available through Get-ChatProviders' {
        Get-ChatProviders | Should -Contain 'Kimi'
    }

    It 'sends OpenAI-compatible chat completion requests' {
        Mock -ModuleName PSAISuite Invoke-RestMethod {
            [pscustomobject]@{
                choices = @(
                    [pscustomobject]@{
                        message = [pscustomobject]@{ content = 'Kimi response' }
                    }
                )
            }
        }

        $result = & $script:PSAISuiteModule {
            Invoke-KimiProvider -ModelName 'k3' -Messages @(@{ role = 'user'; content = 'Hello Kimi' })
        }

        $result | Should -Be 'Kimi response'
        Assert-MockCalled -ModuleName PSAISuite Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://api.kimi.com/coding/v1/chat/completions' -and
            $Method -eq 'POST' -and
            $Headers.Authorization -eq 'Bearer test-kimi-key' -and
            $Headers.'Content-Type' -eq 'application/json' -and
            $Headers.'User-Agent' -match '^PSAISuite/' -and
            ($Body | ConvertFrom-Json).model -eq 'k3'
        }
    }

    It 'requires KIMI_API_KEY' {
        Remove-Item Env:\KIMI_API_KEY -ErrorAction SilentlyContinue

        {
            & $script:PSAISuiteModule {
                Invoke-KimiProvider -ModelName 'k3' -Messages @(@{ role = 'user'; content = 'Hello Kimi' })
            }
        } | Should -Throw 'Kimi Code API key not found. Please set the KIMI_API_KEY environment variable.'
    }

    It 'preserves reasoning content when continuing after a tool call' {
        Mock -ModuleName PSAISuite Invoke-RestMethod {
            param($Body)

            if ($Body -match 'reasoning_content') {
                return [pscustomobject]@{
                    choices = @(
                        [pscustomobject]@{
                            message = [pscustomobject]@{ content = 'Tool result received' }
                        }
                    )
                }
            }

            [pscustomobject]@{
                choices = @(
                    [pscustomobject]@{
                        message = [pscustomobject]@{
                            content = $null
                            reasoning_content = 'I need to call a tool before answering.'
                            tool_calls = @(
                                [pscustomobject]@{
                                    id = 'call_kimi_1'
                                    type = 'function'
                                    function = [pscustomobject]@{
                                        name = 'Get-MissingKimiTestTool'
                                        arguments = '{}'
                                    }
                                }
                            )
                        }
                    }
                )
            }
        }

        $tool = @{
            Name = 'Get-MissingKimiTestTool'
            Description = 'Test-only tool schema.'
            Parameters = @{ type = 'object'; properties = @{} }
        }

        $result = & $script:PSAISuiteModule {
            param($toolDefinition)
            Invoke-KimiProvider -ModelName 'kimi-for-coding' -Messages @(@{ role = 'user'; content = 'Use a tool.' }) -Tools $toolDefinition
        } $tool

        $result | Should -Be 'Tool result received'
        Assert-MockCalled -ModuleName PSAISuite Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Body -match 'reasoning_content' -and
            $Body -match 'call_kimi_1' -and
            $Body -match 'tool_call_id'
        }
    }

    It 'returns no choices when the API response is empty' {
        Mock -ModuleName PSAISuite Invoke-RestMethod { [pscustomobject]@{ choices = @() } }

        $result = & $script:PSAISuiteModule {
            Invoke-KimiProvider -ModelName 'kimi-for-coding' -Messages @(@{ role = 'user'; content = 'Hello Kimi' })
        }

        $result | Should -Be 'No choices in response from API.'
    }
}

Describe 'Kimi model completion' {
    BeforeEach {
        $env:KIMI_API_KEY = 'test-kimi-key'
        Mock -ModuleName PSAISuite Invoke-RestMethod {
            [pscustomobject]@{
                data = @(
                    [pscustomobject]@{ id = 'k3'; owned_by = 'kimi' },
                    [pscustomobject]@{ id = 'kimi-for-coding'; owned_by = 'kimi' }
                )
            }
        }
    }

    It 'retrieves Kimi models from the authenticated models endpoint' {
        $inputScript = 'Invoke-ChatCompletion -Model kimi:'
        $result = TabExpansion2 -InputScript $inputScript -CursorColumn $inputScript.Length

        $result.CompletionMatches.CompletionText | Should -Contain 'kimi:k3'
        $result.CompletionMatches.CompletionText | Should -Contain 'kimi:kimi-for-coding'
        Assert-MockCalled -ModuleName PSAISuite Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://api.kimi.com/coding/v1/models' -and
            $Headers.Authorization -eq 'Bearer test-kimi-key'
        }
    }
}
