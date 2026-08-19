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

            $filteredParameters.Count | Should -Be 9
            $filteredParameters.Name | Should -Be @("Messages", "Model", "Context", "Tools", "MaxIterations", "EffortLevel", "SpeedLevel", "IncludeElapsedTime", "Raw")
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

        It "Exposes the supported OpenAI reasoning effort levels" {
            $effortParameter = (Get-Command Invoke-ChatCompletion).Parameters['EffortLevel']
            $validateSet = $effortParameter.Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }

            @($validateSet.ValidValues) | Should -Be @('none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max')
        }

        It "Rejects effort levels that are not supported by OpenAI" {
            { Invoke-ChatCompletion -Messages "Test prompt" -EffortLevel ultrafast } | Should -Throw
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

        It "Passes OpenAI max iterations to the provider" {
            $global:capturedMaxIterations = $null
            Mock -ModuleName PSAISuite Invoke-OpenAIProvider {
                param($ModelName, $Messages, $MaxIterations)
                $global:capturedMaxIterations = $MaxIterations
                [PSCustomObject]@{ Text = "OpenAI response" }
            }

            Invoke-ChatCompletion -Messages "Test prompt" -Model "openai:gpt-5.6" -MaxIterations 12 | Out-Null

            $global:capturedMaxIterations | Should -Be 12
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

        It "Rejects OpenAI max iterations for other providers" {
            $message = New-ChatMessage -Prompt "Test"
            { Invoke-ChatCompletion -Messages $message -Model "anthropic:claude-3-sonnet-20240229" -MaxIterations 12 } |
            Should -Throw "MaxIterations is currently supported only for the OpenAI provider."
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
}

Describe "Invoke-OpenAIProvider max iterations" {
    BeforeEach {
        Mock -ModuleName PSAISuite Invoke-RestMethod {
            [PSCustomObject]@{
                output = @(
                    [PSCustomObject]@{
                        type      = 'function_call'
                        name      = 'Missing-Test-Tool'
                        arguments = '{}'
                        call_id   = 'call-1'
                    }
                )
            }
        }
    }

    It "stops after the configured number of tool-calling rounds" {
        InModuleScope PSAISuite {
            $result = Invoke-OpenAIProvider -ModelName 'gpt-5.6' -Messages @(@{ role = 'user'; content = 'Use a tool' }) -MaxIterations 2

            $result | Should -Be 'Maximum iterations reached without completing the response after 2 iterations.'
        }
    }
}

Describe "Invoke-OpenAIProvider tool feedback and project instructions" {
    BeforeEach {
        Mock -ModuleName PSAISuite Write-Progress {}
    }

    It "returns non-terminating PowerShell tool errors to the model" {
        $global:openAIRequestCount = 0
        $global:capturedToolOutput = $null
        $global:missingToolPath = Join-Path $TestDrive 'missing-file.md'
        $global:toolFeedbackTestTool = @{
            Name        = 'Get-Content'
            Description = 'Reads a file.'
            Parameters  = @{
                type       = 'object'
                properties = @{ Path = @{ type = 'string' } }
                required   = @('Path')
            }
        }

        Mock -ModuleName PSAISuite Invoke-RestMethod {
            $global:openAIRequestCount++
            $request = $Body | ConvertFrom-Json

            if ($global:openAIRequestCount -eq 1) {
                return [PSCustomObject]@{
                    output = @(
                        [PSCustomObject]@{
                            type      = 'function_call'
                            name      = 'Get-Content'
                            arguments = (@{ Path = $global:missingToolPath } | ConvertTo-Json -Compress)
                            call_id   = 'call-error-1'
                        }
                    )
                }
            }

            $global:capturedToolOutput = @($request.input | Where-Object { $_.type -eq 'function_call_output' } | Select-Object -Last 1).output
            [PSCustomObject]@{
                output = @(
                    [PSCustomObject]@{
                        type    = 'message'
                        content = @([PSCustomObject]@{ type = 'output_text'; text = 'I received the tool error.' })
                    }
                )
            }
        }

        InModuleScope PSAISuite {
            $global:toolFeedbackTestResult = Invoke-OpenAIProvider -ModelName 'gpt-5.6' -Messages @(@{ role = 'user'; content = 'Read the file' }) -Tools $global:toolFeedbackTestTool
        }

        $global:toolFeedbackTestResult.Text | Should -Be 'I received the tool error.'
        $global:capturedToolOutput | Should -Match 'Error executing Get-Content'
        $global:capturedToolOutput | Should -Match 'missing-file.md'
    }

    It "loads an AGENTS.md file created during a tool round" {
        $global:openAIRequestCount = 0
        $global:secondRequestInput = $null
        $global:secondRequestInstructions = $null
        $global:agentsTestPath = Join-Path $TestDrive 'AGENTS.md'

        function global:New-PSAISuiteTestAgentsFile {
            param([string]$Path)
            Set-Content -LiteralPath $Path -Value '# Test project instructions`nUse the project instructions.'
            return 'AGENTS.md created'
        }

        $global:agentsTestTool = @{
            Name        = 'New-PSAISuiteTestAgentsFile'
            Description = 'Creates the project instruction file.'
            Parameters  = @{
                type       = 'object'
                properties = @{ Path = @{ type = 'string' } }
                required   = @('Path')
            }
        }

        Mock -ModuleName PSAISuite Invoke-RestMethod {
            $global:openAIRequestCount++
            $request = $Body | ConvertFrom-Json

            if ($global:openAIRequestCount -eq 1) {
                return [PSCustomObject]@{
                    output = @(
                        [PSCustomObject]@{
                            type      = 'function_call'
                            name      = 'New-PSAISuiteTestAgentsFile'
                            arguments = (@{ Path = $global:agentsTestPath } | ConvertTo-Json -Compress)
                            call_id   = 'call-agents-1'
                        }
                    )
                }
            }

            $global:secondRequestInput = @($request.input)
            $global:secondRequestInstructions = $request.instructions
            [PSCustomObject]@{
                output = @(
                    [PSCustomObject]@{
                        type    = 'message'
                        content = @([PSCustomObject]@{ type = 'output_text'; text = 'I loaded the project instructions.' })
                    }
                )
            }
        }

        Push-Location $TestDrive
        try {
            InModuleScope PSAISuite {
                $global:agentsTestResult = Invoke-OpenAIProvider -ModelName 'gpt-5.6' -Messages @(@{ role = 'user'; content = 'Create and use project instructions' }) -Tools $global:agentsTestTool
            }
        }
        finally {
            Pop-Location
            Remove-Item -LiteralPath Function:\New-PSAISuiteTestAgentsFile -ErrorAction SilentlyContinue
        }

        $global:agentsTestResult.Text | Should -Be 'I loaded the project instructions.'
        $global:secondRequestInstructions | Should -Match 'Use the project instructions.'
    }

    It "sends system and developer messages through the Responses instructions field" {
        $global:capturedInstructions = $null
        $global:capturedInput = $null

        Mock -ModuleName PSAISuite Invoke-RestMethod {
            $request = $Body | ConvertFrom-Json
            $global:capturedInstructions = $request.instructions
            $global:capturedInput = @($request.input)
            [PSCustomObject]@{
                output = @(
                    [PSCustomObject]@{
                        type    = 'message'
                        content = @([PSCustomObject]@{ type = 'output_text'; text = 'done' })
                    }
                )
            }
        }

        InModuleScope PSAISuite {
            $result = Invoke-OpenAIProvider -ModelName 'gpt-5.6' -Messages @(
                @{ role = 'system'; content = @(@{ type = 'input_text'; text = 'Use standard Markdown links.' }) }
                @{ role = 'developer'; content = 'Do not include a title.' }
                @{ role = 'user'; content = 'Write an index.' }
            )
        }

        $global:capturedInstructions | Should -BeLike '*Use standard Markdown links.*'
        $global:capturedInstructions | Should -BeLike '*Do not include a title.*'
        @($global:capturedInput).Count | Should -Be 1
        $global:capturedInput[0].role | Should -Be 'user'
    }

    It "removes instructions from the next request when AGENTS.md is deleted" {
        $global:openAIRequestCount = 0
        $global:capturedInstructionsAfterRemoval = 'not-captured'
        $global:agentsRemovalTestPath = Join-Path $TestDrive 'AGENTS.md'
        Set-Content -LiteralPath $global:agentsRemovalTestPath -Value 'Remove these instructions after the first round.'

        function global:Remove-PSAISuiteTestAgentsFile {
            param([string]$Path)
            Remove-Item -LiteralPath $Path -ErrorAction Stop
            return 'AGENTS.md removed'
        }

        $global:agentsRemovalTestTool = @{
            Name        = 'Remove-PSAISuiteTestAgentsFile'
            Description = 'Removes the project instruction file.'
            Parameters  = @{
                type       = 'object'
                properties = @{ Path = @{ type = 'string' } }
                required   = @('Path')
            }
        }

        Mock -ModuleName PSAISuite Invoke-RestMethod {
            $global:openAIRequestCount++
            $request = $Body | ConvertFrom-Json

            if ($global:openAIRequestCount -eq 1) {
                return [PSCustomObject]@{
                    output = @(
                        [PSCustomObject]@{
                            type      = 'function_call'
                            name      = 'Remove-PSAISuiteTestAgentsFile'
                            arguments = (@{ Path = $global:agentsRemovalTestPath } | ConvertTo-Json -Compress)
                            call_id   = 'call-agents-removal-1'
                        }
                    )
                }
            }

            $global:capturedInstructionsAfterRemoval = $request.PSObject.Properties.Name -contains 'instructions'
            [PSCustomObject]@{
                output = @(
                    [PSCustomObject]@{
                        type    = 'message'
                        content = @([PSCustomObject]@{ type = 'output_text'; text = 'Instructions were removed.' })
                    }
                )
            }
        }

        Push-Location $TestDrive
        try {
            InModuleScope PSAISuite {
                $global:agentsRemovalTestResult = Invoke-OpenAIProvider -ModelName 'gpt-5.6' -Messages @(@{ role = 'user'; content = 'Remove the project instructions' }) -Tools $global:agentsRemovalTestTool
            }
        }
        finally {
            Pop-Location
            Remove-Item -LiteralPath Function:\Remove-PSAISuiteTestAgentsFile -ErrorAction SilentlyContinue
        }

        $global:agentsRemovalTestResult.Text | Should -Be 'Instructions were removed.'
        $global:capturedInstructionsAfterRemoval | Should -BeFalse
    }
}
