BeforeAll {
    # Import the module to test
    Import-Module "$PSScriptRoot\..\PSAISuite.psd1" -Force
}

Describe "ConvertTo-ProviderToolSchema" {

    Context "Agnostic tool with all fields" {
        It "Converts agnostic tool to OpenAI format" {
            $tool = @{
                Name        = "Test-Tool"
                Description = "A test tool"
                Parameters  = @{ type = "object"; properties = @{ input = @{ type = "string"; description = "Input" } }; required = @("input") }
            }
            $result = @(ConvertTo-ProviderToolSchema -Tools $tool -Provider openai)
            $result.Count | Should -Be 1
            $result[0].type | Should -Be "function"
            $result[0].function.name | Should -Be "Test-Tool"
            $result[0].function.description | Should -Be "A test tool"
        }

        It "Converts agnostic tool to Google format" {
            $tool = @{
                Name        = "Test-Tool"
                Description = "A test tool"
                Parameters  = @{ type = "object"; properties = @{ input = @{ type = "string"; description = "Input" } }; required = @("input") }
            }
            $result = @(ConvertTo-ProviderToolSchema -Tools $tool -Provider google)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be "Test-Tool"
            $result[0].description | Should -Be "A test tool"
            $result[0].parameters | Should -Not -BeNullOrEmpty
        }

        It "Converts agnostic tool to Anthropic format" {
            $tool = @{
                Name        = "Test-Tool"
                Description = "A test tool"
                Parameters  = @{ type = "object"; properties = @{ input = @{ type = "string"; description = "Input" } }; required = @("input") }
            }
            $result = @(ConvertTo-ProviderToolSchema -Tools $tool -Provider anthropic)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be "Test-Tool"
            $result[0].description | Should -Be "A test tool"
            $result[0].input_schema | Should -Not -BeNullOrEmpty
        }
    }

    Context "OpenAI-formatted tools converted to other providers" {
        It "Converts OpenAI-formatted tool to Google format" {
            $tool = @{
                type     = "function"
                function = @{
                    name        = "Get-SystemHealth"
                    description = "Gets system health"
                    parameters  = @{ type = "object"; properties = @{}; required = @() }
                }
            }
            $result = @(ConvertTo-ProviderToolSchema -Tools $tool -Provider google)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be "Get-SystemHealth"
            $result[0].description | Should -Be "Gets system health"
        }

        It "Converts OpenAI-formatted tool to Anthropic format" {
            $tool = @{
                type     = "function"
                function = @{
                    name        = "Get-SystemHealth"
                    description = "Gets system health"
                    parameters  = @{ type = "object"; properties = @{}; required = @() }
                }
            }
            $result = @(ConvertTo-ProviderToolSchema -Tools $tool -Provider anthropic)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be "Get-SystemHealth"
            $result[0].description | Should -Be "Gets system health"
        }
    }

    Context "Tools with missing description or parameters" {
        It "Provides default description for Google when description is missing" {
            $tool = @{
                type     = "function"
                function = @{
                    name       = "Get-DiskUsage"
                    parameters = @{ type = "object"; properties = @{}; required = @() }
                }
            }
            $result = @(ConvertTo-ProviderToolSchema -Tools $tool -Provider google)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be "Get-DiskUsage"
            $result[0].description | Should -Be "Get-DiskUsage"
        }

        It "Provides default parameters for Google when parameters is missing" {
            $tool = @{
                type     = "function"
                function = @{
                    name        = "Get-DiskUsage"
                    description = "Gets disk usage"
                }
            }
            $result = @(ConvertTo-ProviderToolSchema -Tools $tool -Provider google)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be "Get-DiskUsage"
            $result[0].parameters.type | Should -Be "object"
        }

        It "Provides defaults for Google when both description and parameters are missing" {
            $tool = @{
                type     = "function"
                function = @{
                    name = "Get-DiskUsage"
                }
            }
            $result = @(ConvertTo-ProviderToolSchema -Tools $tool -Provider google)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be "Get-DiskUsage"
            $result[0].description | Should -Be "Get-DiskUsage"
            $result[0].parameters.type | Should -Be "object"
        }

        It "Provides default description for Anthropic when description is missing" {
            $tool = @{
                type     = "function"
                function = @{
                    name       = "Get-DiskUsage"
                    parameters = @{ type = "object"; properties = @{}; required = @() }
                }
            }
            $result = @(ConvertTo-ProviderToolSchema -Tools $tool -Provider anthropic)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be "Get-DiskUsage"
            $result[0].description | Should -Be "Get-DiskUsage"
        }

        It "Provides default description for agnostic tool when description is missing" {
            $tool = @{
                Name       = "Get-DiskUsage"
                Parameters = @{ type = "object"; properties = @{}; required = @() }
            }
            $result = @(ConvertTo-ProviderToolSchema -Tools $tool -Provider google)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be "Get-DiskUsage"
            $result[0].description | Should -Be "Get-DiskUsage"
        }

        It "Provides default parameters for agnostic tool when parameters is missing" {
            $tool = @{
                Name        = "Get-DiskUsage"
                Description = "Gets disk usage"
            }
            $result = @(ConvertTo-ProviderToolSchema -Tools $tool -Provider google)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be "Get-DiskUsage"
            $result[0].parameters.type | Should -Be "object"
        }

        It "Skips tool when name is missing" {
            $tool = @{
                type     = "function"
                function = @{
                    description = "Gets disk usage"
                    parameters  = @{ type = "object"; properties = @{}; required = @() }
                }
            }
            $result = @(ConvertTo-ProviderToolSchema -Tools $tool -Provider google 3>&1)
            # Should produce a warning
            $warnings = $result | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
            $warnings.Count | Should -BeGreaterThan 0
        }

        It "Does not produce warnings when description is missing" {
            $tool = @{
                type     = "function"
                function = @{
                    name       = "Get-DiskUsage"
                    parameters = @{ type = "object"; properties = @{}; required = @() }
                }
            }
            $result = @(ConvertTo-ProviderToolSchema -Tools $tool -Provider google -WarningVariable warnings 3>$null)
            $result.Count | Should -Be 1
            $warnings.Count | Should -Be 0
        }

        It "Handles multiple tools with missing fields for Google" {
            $tools = @(
                @{
                    type     = "function"
                    function = @{
                        name = "Get-SystemHealth"
                    }
                },
                @{
                    type     = "function"
                    function = @{
                        name = "Get-DiskUsage"
                    }
                },
                @{
                    type     = "function"
                    function = @{
                        name = "Render-HTML"
                    }
                }
            )
            $result = @(ConvertTo-ProviderToolSchema -Tools $tools -Provider google)
            $result.Count | Should -Be 3
            $result[0].name | Should -Be "Get-SystemHealth"
            $result[1].name | Should -Be "Get-DiskUsage"
            $result[2].name | Should -Be "Render-HTML"
        }
    }
}
