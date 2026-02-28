@(
    @{
        Id             = 'codegen-001'
        Category       = 'CodeGen'
        Prompt         = 'Write a PowerShell function called Get-StringReverse that takes a string parameter and returns it reversed. Return only the function, no explanation, no markdown, no code fences.'
        ExpectedAnswer = 'Get-StringReverse'
        ScoringType    = 'contains'
        Notes          = 'Tests basic function generation and instruction following (no markdown). Manual review needed to verify it actually reverses strings correctly.'
    },
    @{
        Id             = 'codegen-002'
        Category       = 'CodeGen'
        Prompt         = 'Write a PowerShell function called Invoke-Retry that takes a ScriptBlock and an integer MaxRetries parameter. It should retry the scriptblock up to MaxRetries times with exponential backoff starting at 1 second. Return only the function, no explanation, no markdown, no code fences.'
        ExpectedAnswer = 'Invoke-Retry'
        ScoringType    = 'contains'
        Notes          = 'Tests practical PS patterns: scriptblock handling, exponential backoff, error handling. Manual review required — verify backoff logic and that it actually retries on terminating errors.'
    },
    @{
        Id             = 'codegen-003'
        Category       = 'CodeGen'
        Prompt         = 'Write a PowerShell function called ConvertTo-FlatHashtable that takes a nested hashtable and returns a flat hashtable with dot-notation keys. Example: @{a=@{b=1}} becomes @{"a.b"=1}. Return only the function, no explanation, no markdown, no code fences.'
        ExpectedAnswer = 'ConvertTo-FlatHashtable'
        ScoringType    = 'contains'
        Notes          = 'Tests recursive thinking and PS-specific idioms. Manual review required — run the example case to verify output.'
    },
    @{
        Id             = 'codegen-004'
        Category       = 'CodeGen'
        Prompt         = 'Write a PowerShell function called Get-WordFrequency that takes a string and returns a hashtable of word frequencies, case-insensitive, excluding punctuation. Return only the function, no explanation, no markdown, no code fences.'
        ExpectedAnswer = 'Get-WordFrequency'
        ScoringType    = 'contains'
        Notes          = 'Tests string manipulation and hashtable usage. Manual review required — verify case-insensitivity and punctuation stripping work correctly.'
    },
    @{
        Id             = 'codegen-005'
        Category       = 'CodeGen'
        Prompt         = 'Write a PowerShell function called Test-PalindromeString that takes a string and returns $true if it is a palindrome, $false if not. Ignore spaces and punctuation, case-insensitive. Return only the function, no explanation, no markdown, no code fences.'
        ExpectedAnswer = 'Test-PalindromeString'
        ScoringType    = 'contains'
        Notes          = 'Tests string normalization and comparison logic. Manual review required — test with: racecar, A man a plan a canal Panama, hello.'
    }
)
