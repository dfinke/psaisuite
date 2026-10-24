BeforeAll {
    # Import the module to test
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
    Import-Module "$ProjectRoot\PSAISuite.psd1" -Force
}

Describe "Invoke-LMStudioProvider" {
    BeforeEach {
        # Save original environment variables
        $script:OriginalApiUrl = $env:LMSTUDIO_API_URL
        $script:OriginalApiKey = $env:LMSTUDIO_API_KEY
    }
    
    AfterEach {
        # Restore original environment variables
        $env:LMSTUDIO_API_URL = $script:OriginalApiUrl
        $env:LMSTUDIO_API_KEY = $script:OriginalApiKey
    }

    It "Should be callable through Invoke-ChatCompletion" {
        # Test that the provider function is available when called through the main interface
        $messages = @(@{ role = "user"; content = "test" })
        
        # This should not throw an "unsupported provider" error
        { Invoke-ChatCompletion -Messages $messages -Model "lmstudio:test-model" } | Should -Not -Throw -ExpectedMessage "*Unsupported provider*"
    }

    It "Should use default URL when LMSTUDIO_API_URL is not set" {
        # Clear environment variable
        $env:LMSTUDIO_API_URL = $null
        
        $messages = @(@{ role = "user"; content = "test" })
        $result = Invoke-ChatCompletion -Messages $messages -Model "lmstudio:test-model"
        
        # Should get a connection error mentioning localhost:1234 (default URL)
        $result | Should -BeLike "*localhost:1234*"
    }

    It "Should use LMSTUDIO_API_URL when set" {
        # Set custom URL
        $env:LMSTUDIO_API_URL = "http://custom-host:5678"
        
        $messages = @(@{ role = "user"; content = "test" })
        $result = Invoke-ChatCompletion -Messages $messages -Model "lmstudio:test-model"
        
        # Should get a connection error mentioning the custom URL
        $result | Should -BeLike "*custom-host:5678*"
    }

    It "Should handle connection errors gracefully" {
        $env:LMSTUDIO_API_URL = $null
        
        $messages = @(@{ role = "user"; content = "test" })
        $result = Invoke-ChatCompletion -Messages $messages -Model "lmstudio:test-model"
        
        $result | Should -BeLike "*Error connecting to LM Studio API*"
    }

    It "Should be included in Get-ChatProviders output" {
        $providers = Get-ChatProviders
        $providers | Should -Contain 'LMStudio'
    }
}