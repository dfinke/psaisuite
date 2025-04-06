function Invoke-LLM {
    [Alias("LLM")]
    param(
        [string]$targetPrompt,
        [Parameter(ValueFromPipeline = $true)]
        [object]$pipelineInput,
        [object[]]$Models,
        [switch]$OutputOnly   
    )

    Begin {
        $additionalInstructions = @()
    }

    Process {
        $additionalInstructions += $pipelineInput
    }

    End {
        $fullPrompt = "{0}`n{1}" -f $targetPrompt , ($additionalInstructions -join "`n")
        
        if(!$Models) {
            $Models = @("openai:gpt-4o-mini")
        }
        
        Write-Host "Prompting $($Models.Count) models" -ForegroundColor Green
        foreach ($model in $Models) {
            Write-Host "Prompting model: $model" -ForegroundColor Green
            Invoke-ChatCompletion $fullPrompt $model.Trim()
        }
    }
}