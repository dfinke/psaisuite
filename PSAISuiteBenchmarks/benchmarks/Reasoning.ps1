@(
    @{
        Id             = 'reasoning-001'
        Category       = 'Reasoning'
        Prompt         = 'A bat and ball cost $1.10 total. The bat costs $1.00 more than the ball. How much does the ball cost? Answer with just the amount, example format: $0.05'
        ExpectedAnswer = '$0.05'
        ScoringType    = 'contains'
        Notes          = 'Classic CRT question. Intuitive wrong answer is $0.10. Correct answer is $0.05. Tests whether model reasons vs pattern-matches.'
    },
    @{
        Id             = 'reasoning-002'
        Category       = 'Reasoning'
        Prompt         = 'You have 3 boxes. One has apples, one has oranges, one has both. All three labels are wrong. You may pick one fruit from one box without looking. How do you correctly label all three boxes? Answer in 3 sentences or less.'
        ExpectedAnswer = ''
        ScoringType    = 'manual'
        Notes          = 'Tests logical deduction under constraints. Correct answer: pick from the box labeled Both — since all labels are wrong, it must be either apples or oranges. That tells you its true label, and the other two follow by elimination. Manual review required.'
    },
    @{
        Id             = 'reasoning-003'
        Category       = 'Reasoning'
        Prompt         = 'What breaks when you say it? Answer in one word only.'
        ExpectedAnswer = 'silence'
        ScoringType    = 'contains'
        Notes          = 'Lateral thinking question. Tests whether model gets trick questions or over-explains. Single word answer required.'
    },
    @{
        Id             = 'reasoning-004'
        Category       = 'Reasoning'
        Prompt         = 'A farmer has 17 sheep. All but 9 die. How many sheep are left? Answer with a single integer only.'
        ExpectedAnswer = '^\d+$'
        ScoringType    = 'regex'
        Notes          = 'Trick question — correct answer is 9. Common wrong answer is 8. Also tests instruction following: single integer only. Manual check needed to verify the integer is 9.'
    },
    @{
        Id             = 'reasoning-005'
        Category       = 'Reasoning'
        Prompt         = 'If you overtake the person in second place in a race, what place are you in? Answer with a single word: the place name only, example: First'
        ExpectedAnswer = 'second'
        ScoringType    = 'contains'
        Notes          = 'Counterintuitive answer. You are now in second place, not first. Tests whether model reasons through the scenario vs gives the intuitive wrong answer of First.'
    },
    @{
        Id             = 'reasoning-006'
        Category       = 'Reasoning'
        Prompt         = 'I have two coins that total 30 cents. One is not a nickel. What are the two coins? Answer in this exact format: coin1, coin2'
        ExpectedAnswer = 'quarter, nickel'
        ScoringType    = 'contains'
        Notes          = 'Classic trick — one coin is not a nickel, but the other is. Tests careful reading vs assumption.'
    },
    @{
        Id             = 'reasoning-007'
        Category       = 'Reasoning'
        Prompt         = 'A doctor says "I cannot operate on this patient, he is my son." The doctor is not the patient is father. Who is the doctor? One word only.'
        ExpectedAnswer = 'mother'
        ScoringType    = 'contains'
        Notes          = 'Tests implicit bias in reasoning. Answer is mother.'
    },
    @{
        Id             = 'reasoning-008'
        Category       = 'Reasoning'
        Prompt         = 'You are in a race and pass the person in last place. What place are you now in? Single word answer only.'
        ExpectedAnswer = 'last'
        ScoringType    = 'contains'
        Notes          = 'Companion to reasoning-005. You cannot pass last place without being last. Many models get this wrong.'
    }
)
