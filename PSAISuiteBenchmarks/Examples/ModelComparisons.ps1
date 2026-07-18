# Path to the JSON file where model comparison results are stored.
$modelStorePath = '.\model-comparisons.json'

# First comparison set: run the same prompt across these models.
$models = @(
    'openai:gpt-4o-mini'
    'anthropic:claude-sonnet-4-6'
    'xAI:grok-4-1-fast-non-reasoning'
)

# Execute comparison and append/store results in the configured store file.
Invoke-ModelComparison -Prompt 'Return valid JSON with name and capital for France.' -Models $models -StorePath $modelStorePath

# Second comparison set: additional providers/models for the same prompt.
$models = @(
    'mistral:devstral-latest'
    'google:gemini-3.1-flash-lite'
    'deepseek:deepseek-v4-flash'
)

# Execute second comparison run using the same result store.
Invoke-ModelComparison -Prompt 'Return valid JSON with name and capital for France.' -Models $models -StorePath $modelStorePath

# Open the comparison report/viewer for the stored results.
Show-ModelComparison -Open -StorePath $modelStorePath