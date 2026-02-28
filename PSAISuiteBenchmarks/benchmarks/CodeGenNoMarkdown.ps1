@(
    @{
        Id             = 'codegen-nomarkdown-001'
        Category       = 'CodeGen'
        Prompt         = 'Write a PowerShell function called Get-StringReverse that takes a string parameter and returns it reversed. Return only the function, no explanation, no markdown, no code fences.'
        ExpectedAnswer = '```'
        ScoringType    = 'not-contains'
        Notes          = 'Second-pass formatting check for codegen-001. Fails if markdown code fences are present.'
    },
    @{
        Id             = 'codegen-nomarkdown-002'
        Category       = 'CodeGen'
        Prompt         = 'Write a PowerShell function called Invoke-Retry that takes a ScriptBlock and an integer MaxRetries parameter. It should retry the scriptblock up to MaxRetries times with exponential backoff starting at 1 second. Return only the function, no explanation, no markdown, no code fences.'
        ExpectedAnswer = '```'
        ScoringType    = 'not-contains'
        Notes          = 'Second-pass formatting check for codegen-002. Fails if markdown code fences are present.'
    },
    @{
        Id             = 'codegen-nomarkdown-003'
        Category       = 'CodeGen'
        Prompt         = 'Write a PowerShell function called ConvertTo-FlatHashtable that takes a nested hashtable and returns a flat hashtable with dot-notation keys. Example: @{a=@{b=1}} becomes @{"a.b"=1}. Return only the function, no explanation, no markdown, no code fences.'
        ExpectedAnswer = '```'
        ScoringType    = 'not-contains'
        Notes          = 'Second-pass formatting check for codegen-003. Fails if markdown code fences are present.'
    },
    @{
        Id             = 'codegen-nomarkdown-004'
        Category       = 'CodeGen'
        Prompt         = 'Write a PowerShell function called Get-WordFrequency that takes a string and returns a hashtable of word frequencies, case-insensitive, excluding punctuation. Return only the function, no explanation, no markdown, no code fences.'
        ExpectedAnswer = '```'
        ScoringType    = 'not-contains'
        Notes          = 'Second-pass formatting check for codegen-004. Fails if markdown code fences are present.'
    },
    @{
        Id             = 'codegen-nomarkdown-005'
        Category       = 'CodeGen'
        Prompt         = 'Write a PowerShell function called Test-PalindromeString that takes a string and returns $true if it is a palindrome, $false if not. Ignore spaces and punctuation, case-insensitive. Return only the function, no explanation, no markdown, no code fences.'
        ExpectedAnswer = '```'
        ScoringType    = 'not-contains'
        Notes          = 'Second-pass formatting check for codegen-005. Fails if markdown code fences are present.'
    }
)
