@(
    @{
        Id             = 'latency-001'
        Category       = 'Latency'
        Prompt         = 'Reply with one word: Yes'
        ExpectedAnswer = 'yes'
        ScoringType    = 'contains'
        Notes          = 'Minimal instruction compliance test. Baseline latency floor — simplest possible prompt. Any model taking over 2s here has overhead issues.'
    },
    @{
        Id             = 'latency-002'
        Category       = 'Latency'
        Prompt         = 'What is 12 times 12? Reply with the number only.'
        ExpectedAnswer = '144'
        ScoringType    = 'contains'
        Notes          = 'Simple arithmetic. Tests whether fast models cut corners on trivial math. Expected answer 144.'
    },
    @{
        Id             = 'latency-003'
        Category       = 'Latency'
        Prompt         = 'Name the capital of Japan. One word only.'
        ExpectedAnswer = 'Tokyo'
        ScoringType    = 'contains'
        Notes          = 'Simple factual recall. Should be near-instant for all models.'
    },
    @{
        Id             = 'latency-004'
        Category       = 'Latency'
        Prompt         = 'Continue this sequence with the next number only: 2, 4, 8, 16, ?'
        ExpectedAnswer = '32'
        ScoringType    = 'contains'
        Notes          = 'Simple pattern recognition. Tests whether model follows single-value output constraint under speed conditions.'
    },
    @{
        Id             = 'latency-005'
        Category       = 'Latency'
        Prompt         = 'Reply with the current day of the week. One word only.'
        ExpectedAnswer = ''
        ScoringType    = 'manual'
        Notes          = 'Models may not know current date — tests whether they admit uncertainty or hallucinate confidently. Manual review required. Correct answer depends on when benchmark is run.'
    }
)
