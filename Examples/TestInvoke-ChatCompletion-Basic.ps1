Import-Module $PSScriptRoot\..\PSAISuite.psd1 -Force

# $env:GeminiKey = $null
# $env:DeepSeekKey = $null
# $env:AnthropicKey = $null
# $env:xAIKey = $null
# $env:OpenAIKey = $null

$models = $(
    'openai:gpt-4o-mini'
    'xai:grok-2-1212'
    'anthropic:claude-3-7-sonnet-20250219'
    'gemini:gemini-2.0-flash-exp'
    # 'deepseek:deepseek-chat'
)

$message = New-ChatMessage -Prompt "What is the capital of France?"

foreach ($model in $models) {
    Write-Host "Testing $model"
    
    Invoke-ChatCompletion -Messages $message -Model $model
}
