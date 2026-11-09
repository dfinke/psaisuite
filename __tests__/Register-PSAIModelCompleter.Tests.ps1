BeforeAll {
    Import-Module "$PSScriptRoot\..\PSAISuite.psd1" -Force
    function global:Test-PSAICompletionOne { param([string]$Model) }
    function global:Test-PSAICompletionTwo { param([string]$Model) }
}

Describe 'Register-PSAIModelCompleter' {
    It 'registers provider suggestions for multiple commands and preserves built-in registrations' {
        Register-PSAIModelCompleter -CommandName Test-PSAICompletionOne, Test-PSAICompletionTwo
        foreach ($name in @('Test-PSAICompletionOne', 'Test-PSAICompletionTwo', 'New-AgentHarness', 'Invoke-ChatCompletion')) {
            $line = "$name -Model ant"
            $result = [System.Management.Automation.CommandCompletion]::CompleteInput($line, $line.Length, $null)
            @($result.CompletionMatches.CompletionText) | Should -Contain 'anthropic:'
        }
    }

    It 'uses the shared provider catalog for registered commands' {
        if ([string]::IsNullOrWhiteSpace($env:OpenAIKey)) {
            Set-ItResult -Skipped -Because 'OpenAIKey is required for the live model-catalog check.'
            return
        }

        Register-PSAIModelCompleter -CommandName Test-PSAICompletionOne
        $line = 'Test-PSAICompletionOne -Model openai:'
        $result = [System.Management.Automation.CommandCompletion]::CompleteInput($line, $line.Length, $null)
        @($result.CompletionMatches.CompletionText | Where-Object { $_ -like 'openai:*' }) | Should -Not -BeNullOrEmpty
    }
}

AfterAll {
    Remove-Item Function:\Test-PSAICompletionOne, Function:\Test-PSAICompletionTwo -ErrorAction SilentlyContinue
}

