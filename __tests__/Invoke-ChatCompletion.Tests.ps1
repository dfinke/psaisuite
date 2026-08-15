BeforeAll {
    # Import the module to test
    Import-Module "$PSScriptRoot\..\PSAISuite.psd1" -Force
}

Describe "New-ChatMessage" {
    It "Basic functionality" {
        $message = New-ChatMessage -Prompt "Test prompt"
        $message | Should -BeOfType [Hashtable]
        $message.role | Should -Be "user"
        $message.content | Should -Be "Test prompt"
    }

    It "With SystemRole functionality" {
        $message = New-ChatMessage -Prompt "Test prompt" -SystemRole system -SystemContent "you are a helpful powershell assistant, reply only with commands"
        $message | Should -BeOfType [Hashtable]
        $message[0].role | Should -Be "system"
        $message[0].content | Should -Be "you are a helpful powershell assistant, reply only with commands"
        $message[1].role | Should -Be "user"
        $message[1].content | Should -Be "Test prompt"
    }
}

Describe "Invoke-ChatCompletion" {
    BeforeEach {
        # Set up mocks for the provider functions in the PSAISuite module scope
        Mock -ModuleName PSAISuite Invoke-OpenAIProvider { param($model, $prompt) return "OpenAI Response: $prompt" }
        Mock -ModuleName PSAISuite Invoke-AnthropicProvider { param($model, $prompt) return "Anthropic Response: $prompt" }
    }

    Context "Invoke-ChatCompletion Parameters" {
        It "Should have these parameters, in order" {
            $parameters = (Get-Command Invoke-ChatCompletion).Parameters.Values |
            Where-Object { $_.Attributes.TypeId.Name -ne "AliasAttribute" } |
            Where-Object { $_.Attributes.TypeId.Name -ne "CommonParameters" }

            # Exclude the Common Parameters
            $commonParameters = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
            $filteredParameters = $parameters | Where-Object { $commonParameters -notcontains $_.Name }

            $filteredParameters.Count | Should -Be 8
            $filteredParameters.Name | Should -Be @("Messages", "Model", "Context", "Tools", "EffortLevel", "SpeedLevel", "IncludeElapsedTime", "Raw")
        }

        It "Should test Context parameter is valueFromPipeline" {
            $actual = (Get-Command Invoke-ChatCompletion)
            $actual.Parameters.Context | Should -Not -BeNullOrEmpty
            $actual.Parameters.Context.Attributes.ValueFromPipeline | Should -Be $true
        }

        It "Should accept Tools parameter" {
            $actual = (Get-Command Invoke-ChatCompletion)
            $actual.Parameters.Tools | Should -Not -BeNullOrEmpty
        }
    }

    Context "Basic functionality" {
        It "Returns object by default" {
            $message = New-ChatMessage -Prompt "Test prompt"
            $result = Invoke-ChatCompletion -Messages $message -Raw
            $result | Should -BeOfType [PSCustomObject]
            $result.Messages | Should -Be ($message | ConvertTo-Json -Compress)
            $result.Response | Should -Not -BeNullOrEmpty
            $result.Timestamp | Should -BeOfType [DateTime]
        }

        It "Returns raw object when Raw switch is used" {
            $message = New-ChatMessage -Prompt "Test prompt"
            $result = Invoke-ChatCompletion -Messages $message -Raw
            $result | Should -BeOfType [PSCustomObject]
            $result.Messages | Should -Be ($message | ConvertTo-Json -Compress)
            $result.Response | Should -Not -BeNullOrEmpty
            $result.Timestamp | Should -BeOfType [DateTime]
        }

        It "Returns text with elapsed time when IncludeElapsedTime is used" {
            $message = New-ChatMessage -Prompt "Test prompt"
            $result = Invoke-ChatCompletion -Messages $message -IncludeElapsedTime
            $result | Should -BeOfType [string]
            $result | Should -Match "Elapsed Time: \d{2}:\d{2}:\d{2}\.\d{3}"
        }

        It "Uses default model when not specified" {
            $message = New-ChatMessage -Prompt "Test prompt"
            $result = Invoke-ChatCompletion -Messages $message -Raw
            $result.Model | Should -Be "openai:gpt-4o-mini"
        }

        It "Uses specified model when provided" {
            $message = New-ChatMessage -Prompt "Test prompt"
            $result = Invoke-ChatCompletion -Messages $message -Model "anthropic:claude-3-sonnet-20240229" -Raw
            $result.Model | Should -Be "anthropic:claude-3-sonnet-20240229"
            $result.Provider | Should -Be "anthropic"
            $result.ModelName | Should -Be "claude-3-sonnet-20240229"
        }

        It "Uses specified model when provided via PSAISUITE_DEFAULT_MODEL environment variable" {
            $env:PSAISUITE_DEFAULT_MODEL = "openai:gpt-4o"
            $message = New-ChatMessage -Prompt "Test prompt"
            $result = Invoke-ChatCompletion -Messages $message -Raw
            $env:PSAISUITE_DEFAULT_MODEL = $null
            $result | Should -BeOfType [PSCustomObject]
            $result.Messages | Should -Be ($message | ConvertTo-Json -Compress)
            $result.Response | Should -Not -BeNullOrEmpty
            $result.Model | Should -Be "openai:gpt-4o"
        }

        It "Surfaces OpenAI effort and service tier metadata in raw output" {
            Mock -ModuleName PSAISuite Invoke-OpenAIProvider {
                [PSCustomObject]@{
                    Text                 = "OpenAI response"
                    RequestedEffortLevel = "low"
                    RequestedSpeedLevel  = "fast"
                    ReasoningEffort      = "low"
                    ServiceTier          = "priority"
                }
            }

            $result = Invoke-ChatCompletion -Messages "Test prompt" -Model "openai:gpt-5.6" -EffortLevel low -SpeedLevel fast -Raw

            $result.Response | Should -Be "OpenAI response"
            $result.EffortLevel | Should -Be "low"
            $result.SpeedLevel | Should -Be "fast"
            $result.ReasoningEffort | Should -Be "low"
            $result.ServiceTier | Should -Be "priority"
        }
    }

    Context "String input handling" {
        It "Accepts a string and converts it to a user message" {
            $result = Invoke-ChatCompletion -Messages "Test string prompt" -Raw
            $result | Should -BeOfType [PSCustomObject]
            # Convert the JSON string back to an object to verify structure
            $messagesObj = $result.Messages | ConvertFrom-Json
            $messagesObj[0].role | Should -Be "user"
            $messagesObj[0].content | Should -Be "Test string prompt"
        }

        It "Returns raw object with string input when Raw switch is used" {
            $result = Invoke-ChatCompletion -Messages "Test string prompt" -Raw
            $result | Should -BeOfType [PSCustomObject]
        }

        It "Works with string input and specified model" {
            $result = Invoke-ChatCompletion -Messages "Test string prompt" -Model "anthropic:claude-3-sonnet-20240229" -Raw
            $result.Model | Should -Be "anthropic:claude-3-sonnet-20240229" 
            $result.Provider | Should -Be "anthropic"
            $result.ModelName | Should -Be "claude-3-sonnet-20240229"
        }

        It "Returns text with elapsed time when IncludeElapsedTime is used" {
            $result = Invoke-ChatCompletion -Messages "Test string prompt" -IncludeElapsedTime
            $result | Should -BeOfType [string]
            $result | Should -Match "Elapsed Time: \d{2}:\d{2}:\d{2}\.\d{3}"
        }
    }

    Context "Elapsed time tracking" {
        It "Includes elapsed time in text when IncludeElapsedTime is used" {
            $message = New-ChatMessage -Prompt "Test prompt"
            $result = Invoke-ChatCompletion -Messages $message -IncludeElapsedTime
            $result | Should -BeOfType [string]
            $result | Should -Match "Elapsed Time: \d{2}:\d{2}:\d{2}\.\d{3}"
        }
    }

    Context "Error handling" {
        It "Throws error for invalid model format" {
            $message = New-ChatMessage -Prompt "Test"
            { Invoke-ChatCompletion -Messages $message -Model "invalid-model-format" } | 
            Should -Throw "Model must be specified in 'provider:model' format."
        }

        It "Throws error for nonexistent provider" {
            $message = New-ChatMessage -Prompt "Test"
            { Invoke-ChatCompletion -Messages $message -Model "nonexistent:model" } | 
            Should -Throw "Unsupported provider: nonexistent. No function named Invoke-nonexistentProvider found."
        }

        It "Rejects OpenAI effort and speed options for other providers" {
            $message = New-ChatMessage -Prompt "Test"
            { Invoke-ChatCompletion -Messages $message -Model "anthropic:claude-3-sonnet-20240229" -EffortLevel low } |
            Should -Throw "EffortLevel and SpeedLevel are currently supported only for the OpenAI provider."
        }
    }

    Context "Tool calling functionality" {
        BeforeEach {
            Mock -ModuleName PSAISuite ConvertTo-ProviderToolSchema { 
                param($Tools, $Provider)
                return $Tools | ForEach-Object {
                    if ($_.Name) {
                        @{
                            type     = "function"
                            function = @{
                                name        = $_.Name
                                description = $_.Description
                                parameters  = $_.Parameters
                            }
                        }
                    }
                    else {
                        $_
                    }
                }
            }
        }

        It "Accepts string tools and processes them" -Skip:(!(Get-Command Register-Tool -ErrorAction SilentlyContinue)) {
            $message = New-ChatMessage -Prompt "List files"
            $result = Invoke-ChatCompletion -Messages $message -Model "openai:gpt-4o-mini" -Tools "Get-ChildItem" -Raw
            $result | Should -BeOfType [PSCustomObject]
        }

        It "Accepts hashtable tools" {
            $customTool = @{
                Name        = "Test-Tool"
                Description = "A test tool"
                Parameters  = @{
                    type       = "object"
                    properties = @{
                        input = @{ type = "string"; description = "Input parameter" }
                    }
                    required   = @("input")
                }
            }
            $message = New-ChatMessage -Prompt "Use test tool"
            $result = Invoke-ChatCompletion -Messages $message -Model "openai:gpt-4o-mini" -Tools $customTool -Raw
            $result | Should -BeOfType [PSCustomObject]
        }

        It "Handles multiple tools" -Skip:(!(Get-Command Register-Tool -ErrorAction SilentlyContinue)) {
            $message = New-ChatMessage -Prompt "Use multiple tools"
            $result = Invoke-ChatCompletion -Messages $message -Model "openai:gpt-4o-mini" -Tools @("Get-ChildItem", "Get-Process") -Raw
            $result | Should -BeOfType [PSCustomObject]
        }
    }
}

Describe "Invoke-OpenAIProvider effort and speed options" {
    BeforeEach {
        $global:capturedOpenAIRequest = $null

        Mock -ModuleName PSAISuite Invoke-RestMethod {
            param($Uri, $Method, $Headers, $Body)
            $global:capturedOpenAIRequest = $Body | ConvertFrom-Json

            [PSCustomObject]@{
                output = @(
                    [PSCustomObject]@{
                        type = 'message'
                        content = @(
                            [PSCustomObject]@{
                                type = 'output_text'
                                text = 'OpenAI response'
                            }
                        )
                    }
                )
                reasoning = [PSCustomObject]@{ effort = 'low' }
                service_tier = 'priority'
            }
        }
    }

    It "Sends effort and speed levels and returns effective metadata" {
        InModuleScope PSAISuite {
            $result = Invoke-OpenAIProvider -ModelName 'gpt-5.6' -Messages @(@{ role = 'user'; content = 'Test prompt' }) -EffortLevel low -SpeedLevel fast

            $global:capturedOpenAIRequest.reasoning.effort | Should -Be 'low'
            $global:capturedOpenAIRequest.service_tier | Should -Be 'fast'
            $result.Text | Should -Be 'OpenAI response'
            $result.RequestedEffortLevel | Should -Be 'low'
            $result.RequestedSpeedLevel | Should -Be 'fast'
            $result.ReasoningEffort | Should -Be 'low'
            $result.ServiceTier | Should -Be 'priority'
        }
    }

    Describe "Invoke-AzureAIProvider endpoint selection" {
        BeforeEach {
            $script:originalAzureAIKey = $env:AzureAIKey
            $script:originalAzureAIEndpoint = $env:AzureAIEndpoint
            $env:AzureAIKey = 'test-key'
            $global:capturedAzureAIRequest = $null
        }

        AfterEach {
            $env:AzureAIKey = $script:originalAzureAIKey
            $env:AzureAIEndpoint = $script:originalAzureAIEndpoint
        }

        It "Uses the Azure OpenAI deployments endpoint for legacy Azure OpenAI resources" {
            Mock -ModuleName PSAISuite Invoke-RestMethod {
                param($Uri, $Method, $Headers, $Body)
                $global:capturedAzureAIRequest = @{
                    Uri     = $Uri
                    Headers = $Headers
                    Body    = $Body | ConvertFrom-Json -AsHashtable
                }

                [PSCustomObject]@{
                    choices = @(
                        [PSCustomObject]@{
                            message = [PSCustomObject]@{
                                content = 'Azure OpenAI response'
                            }
                        }
                    )
                }
            }

            InModuleScope PSAISuite {
                $env:AzureAIEndpoint = 'https://contoso.openai.azure.com'

                $result = Invoke-AzureAIProvider -ModelName 'gpt-4o' -Messages @(@{ role = 'user'; content = 'Hello' })

                $global:capturedAzureAIRequest.Uri | Should -Be 'https://contoso.openai.azure.com/openai/deployments/gpt-4o/chat/completions?api-version=2023-05-15'
                $global:capturedAzureAIRequest.Headers['api-key'] | Should -Be 'test-key'
                $global:capturedAzureAIRequest.Body.ContainsKey('model') | Should -BeFalse
                $result | Should -Be 'Azure OpenAI response'
            }
        }

        It "Uses the Azure AI Foundry models endpoint for MAI deployments" {
            Mock -ModuleName PSAISuite Invoke-RestMethod {
                param($Uri, $Method, $Headers, $Body)
                $global:capturedAzureAIRequest = @{
                    Uri     = $Uri
                    Headers = $Headers
                    Body    = $Body | ConvertFrom-Json -AsHashtable
                }

                [PSCustomObject]@{
                    choices = @(
                        [PSCustomObject]@{
                            message = [PSCustomObject]@{
                                content = 'MAI response'
                            }
                        }
                    )
                }
            }

            InModuleScope PSAISuite {
                $env:AzureAIEndpoint = 'https://contoso.services.ai.azure.com'

                $result = Invoke-AzureAIProvider -ModelName 'MAI-DS-R1' -Messages @(@{ role = 'user'; content = 'Hello' })

                $global:capturedAzureAIRequest.Uri | Should -Be 'https://contoso.services.ai.azure.com/models/chat/completions?api-version=2024-05-01-preview'
                $global:capturedAzureAIRequest.Headers['api-key'] | Should -Be 'test-key'
                $global:capturedAzureAIRequest.Body.model | Should -Be 'MAI-DS-R1'
                $result | Should -Be 'MAI response'
            }
        }

        It "Uses the OpenAI-compatible Foundry endpoint when /openai/v1 is configured" {
            Mock -ModuleName PSAISuite Invoke-RestMethod {
                param($Uri, $Method, $Headers, $Body)
                $global:capturedAzureAIRequest = @{
                    Uri     = $Uri
                    Headers = $Headers
                    Body    = $Body | ConvertFrom-Json -AsHashtable
                }

                [PSCustomObject]@{
                    choices = @(
                        [PSCustomObject]@{
                            message = [PSCustomObject]@{
                                content = 'Foundry OpenAI response'
                            }
                        }
                    )
                }
            }

            InModuleScope PSAISuite {
                $env:AzureAIEndpoint = 'https://contoso.services.ai.azure.com/openai/v1'

                $result = Invoke-AzureAIProvider -ModelName 'MAI-DS-R1' -Messages @(@{ role = 'user'; content = 'Hello' })

                $global:capturedAzureAIRequest.Uri | Should -Be 'https://contoso.services.ai.azure.com/openai/v1/chat/completions'
                $global:capturedAzureAIRequest.Headers['api-key'] | Should -Be 'test-key'
                $global:capturedAzureAIRequest.Body.model | Should -Be 'MAI-DS-R1'
                $result | Should -Be 'Foundry OpenAI response'
            }
        }
    }
}
