BeforeAll {
    Import-Module "$PSScriptRoot\..\PSAISuite.psd1" -Force
}

Describe 'New-AgentHarness' {
    BeforeEach {
        Mock -ModuleName PSAISuite Invoke-ChatCompletion {
            param($Messages, $Model, $Tools, $MaxIterations)
            [pscustomobject]@{
                Messages = $Messages
                Model = $Model
                Tools = $Tools
                MaxIterations = $MaxIterations
            }
        }
    }

    It 'exports a constructor that does no model work' {
        (Get-Command New-AgentHarness).ModuleName | Should -Be 'PSAISuite'
        $harness = New-AgentHarness
        $harness.Model | Should -Be 'openai:gpt-5.6-luna'
        @($harness.Tools).Count | Should -Be 0
        $harness.MaxIterations | Should -Be 5
        Should -Invoke -ModuleName PSAISuite Invoke-ChatCompletion -Times 0 -Exactly
    }

    It 'forwards instructions, command names, model, and round limit' {
        $harness = New-AgentHarness -Model 'anthropic:test' -Tools Get-ChildItem, Get-Date -SystemPrompt 'Inspect files.' -MaxIterations 3
        $result = $harness.GetResponse('List files.')
        $result.Model | Should -Be 'anthropic:test'
        $result.Tools | Should -Be @('Get-ChildItem', 'Get-Date')
        $result.MaxIterations | Should -Be 3
        $result.Messages.Count | Should -Be 2
        $result.Messages[0].role | Should -Be 'system'
        $result.Messages[0].content | Should -Be 'Inspect files.'
        $result.Messages[1].role | Should -Be 'user'
        $result.Messages[1].content | Should -Be 'List files.'
    }

    It 'uses current properties without retaining previous requests or changing other harnesses' {
        $first = New-AgentHarness -Tools Get-Date
        $second = New-AgentHarness
        $null = $first.GetResponse('First request')
        $first.Model = 'anthropic:test'
        $first.Tools = @('Get-ChildItem')
        $first.SystemPrompt = 'Updated instructions'
        $first.MaxIterations = 2
        $result = $first.GetResponse('Second request')
        $result.Model | Should -Be 'anthropic:test'
        $result.Tools | Should -Be @('Get-ChildItem')
        $result.MaxIterations | Should -Be 2
        $result.Messages.Count | Should -Be 2
        $result.Messages[0].content | Should -Be 'Updated instructions'
        $result.Messages[1].content | Should -Be 'Second request'
        $second.Model | Should -Be 'openai:gpt-5.6-luna'
        @($second.Tools).Count | Should -Be 0
    }

    It 'preserves schema tools and completion output' {
        $schema = @{ Name = 'Get-Weather'; Description = 'Weather'; Parameters = @{ type = 'object' } }
        $harness = New-AgentHarness -Tools $schema
        $result = $harness.GetResponse('Weather?')
        $result.Tools[0] | Should -Be $schema
        Mock -ModuleName PSAISuite Invoke-ChatCompletion { 'The answer' }
        $harness.GetResponse('Answer?') | Should -Be 'The answer'
    }

    It 'propagates completion errors' {
        Mock -ModuleName PSAISuite Invoke-ChatCompletion { throw 'Provider unavailable' }
        $harness = New-AgentHarness
        { $harness.GetResponse('Hello') } | Should -Throw '*Provider unavailable*'
    }

    It 'rejects invalid construction limits and empty prompts' {
        { New-AgentHarness -MaxIterations 0 } | Should -Throw
        { New-AgentHarness -MaxIterations 101 } | Should -Throw
        { New-AgentHarness -Model '' } | Should -Throw
        $harness = New-AgentHarness
        { $harness.GetResponse('') } | Should -Throw
    }
}
