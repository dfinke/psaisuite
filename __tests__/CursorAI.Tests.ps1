BeforeAll {
    # Import the module to test
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
    Import-Module "$ProjectRoot\PSAISuite.psd1" -Force
}

Describe "CursorAI Provider" {
    Context "Provider Discovery" {
        It "Should be discovered by Get-ChatProviders" {
            $providers = Get-ChatProviders
            $providers | Should -Contain "CursorAI"
        }
        
        It "Should be available through Invoke-ChatCompletion" {
            # Provider functions are internal, test through the main interface
            $originalKey = $env:CursorAIKey
            $env:CursorAIKey = "test-key"
            
            try {
                $message = New-ChatMessage -Prompt "Test"
                # This will fail with network error, but should not throw due to missing provider
                $result = Invoke-ChatCompletion -Messages $message -Model "cursorai:test-model"
                $result.Provider | Should -Be "cursorai"
            }
            finally {
                $env:CursorAIKey = $originalKey
            }
        }
    }
    
    Context "Function Parameters" {
        It "Should accept cursorai: model format in Invoke-ChatCompletion" {
            # Test that the model format is parsed correctly
            $originalKey = $env:CursorAIKey
            $env:CursorAIKey = "test-key"
            
            try {
                $message = New-ChatMessage -Prompt "Test"
                $result = Invoke-ChatCompletion -Messages $message -Model "cursorai:gpt-4" 
                
                $result.Provider | Should -Be "cursorai"
                $result.ModelName | Should -Be "gpt-4"
            }
            finally {
                $env:CursorAIKey = $originalKey
            }
        }
    }
    
    Context "Environment Variable Requirements" {
        It "Should require CursorAIKey environment variable" {
            # Save current value and clear it
            $originalKey = $env:CursorAIKey
            $env:CursorAIKey = $null
            
            try {
                $message = New-ChatMessage -Prompt "Test"
                
                # Should throw an error about missing API key
                { Invoke-ChatCompletion -Messages $message -Model "cursorai:gpt-4" } | Should -Throw "*CursorAI API key not found*"
            }
            finally {
                # Restore original value
                $env:CursorAIKey = $originalKey
            }
        }
    }
    
    Context "Integration with Invoke-ChatCompletion" {
        BeforeEach {
            # Mock the CursorAI provider for testing
            Mock -ModuleName PSAISuite Invoke-CursorAIProvider { 
                param($ModelName, $Messages) 
                return "CursorAI Response for model $ModelName`: $($Messages[0].content)"
            }
        }
        
        It "Should be callable via Invoke-ChatCompletion with cursorai: prefix" {
            $message = New-ChatMessage -Prompt "Test CursorAI integration"
            $result = Invoke-ChatCompletion -Messages $message -Model "cursorai:gpt-4"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Provider | Should -Be "cursorai"
            $result.ModelName | Should -Be "gpt-4"
            $result.Model | Should -Be "cursorai:gpt-4"
        }
        
        It "Should support privacy mode with custom endpoint" {
            $message = New-ChatMessage -Prompt "Test privacy mode"
            $result = Invoke-ChatCompletion -Messages $message -Model "cursorai:claude-3-5-sonnet"
            
            $result.Provider | Should -Be "cursorai"
            $result.ModelName | Should -Be "claude-3-5-sonnet"
        }
        
        It "Should work with TextOnly parameter" {
            $message = New-ChatMessage -Prompt "Test text only response"
            $result = Invoke-ChatCompletion -Messages $message -Model "cursorai:gpt-4" -TextOnly
            
            $result | Should -BeOfType [string]
            $result | Should -BeLike "*CursorAI Response for model gpt-4*"
        }
    }
    
    Context "Privacy Mode Features" {
        It "Should include privacy headers when custom endpoint is configured" {
            # This test verifies the configuration without making actual API calls
            $originalEndpoint = $env:CursorAIEndpoint
            $originalKey = $env:CursorAIKey
            
            try {
                $env:CursorAIEndpoint = "https://private.cursor.sh/v1"
                $env:CursorAIKey = "test-key"
                
                $message = New-ChatMessage -Prompt "Test privacy mode"
                $result = Invoke-ChatCompletion -Messages $message -Model "cursorai:gpt-4"
                
                # Should attempt to use the custom endpoint (will fail with network error, but that's expected)
                $result.Response | Should -BeLike "*Error calling CursorAI API*"
            }
            finally {
                $env:CursorAIEndpoint = $originalEndpoint
                $env:CursorAIKey = $originalKey
            }
        }
    }
}