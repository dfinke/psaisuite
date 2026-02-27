@(
    @{
        Id             = 'instruction-following-001'
        Category       = 'InstructionFollowing'
        Prompt         = 'Respond with exactly three words. Do not use punctuation.'
        ExpectedAnswer = '^(\S+)\s+(\S+)\s+(\S+)$'
        ScoringType    = 'regex'
        Notes          = 'Checks if the model can restrict its output length exactly without conversational filler. Punctuation is explicitly excluded to simplify regex matching. Regex requires .Trim() on response before matching. Some models prepend acknowledgment on a separate line.'
    },
    @{
        Id             = 'instruction-following-002'
        Category       = 'InstructionFollowing'
        Prompt         = 'Return a valid JSON object with keys name and capital for France. No markdown, no explanation, no code fences.'
        ExpectedAnswer = 'name,capital'
        ScoringType    = 'json-valid'
        Notes          = 'Checks if the model can output raw JSON without markdown wrappers or conversational text.'
    },
    @{
        Id             = 'instruction-following-003'
        Category       = 'InstructionFollowing'
        Prompt         = 'List exactly 5 items numbered 1-5. Use a period after each number. No other formatting.'
        ExpectedAnswer = '(?s)^1\..*?2\..*?3\..*?4\..*?5\..*$'
        ScoringType    = 'regex'
        Notes          = 'Checks strict list formatting and adherence to numbering constraints. Regex requires .Trim() on response before matching. Some models prepend acknowledgment on a separate line.'
    },
    @{
        Id             = 'instruction-following-004'
        Category       = 'InstructionFollowing'
        Prompt         = 'What is the square root of 144? Answer only with a single integer, no other characters.'
        ExpectedAnswer = '^\d+$'
        ScoringType    = 'regex'
        Notes          = 'Checks if the model can suppress all conversational filler and return only a numerical value. Regex requires .Trim() on response before matching. Some models prepend acknowledgment on a separate line.'
    }
)