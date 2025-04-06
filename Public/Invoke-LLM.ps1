function Invoke-LLM {
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
        $fullPrompt = "{0}`n{1}" -f $targetPrompt , $additionalInstructions 
        
        if(!$Models) {
            $Models = @("openai:gpt-4o-mini")
        }
        
        foreach ($model in $Models) {
            Write-Host "Prompting model: $model" -ForegroundColor Green
            Invoke-ChatCompletion $fullPrompt $model.Trim()
        }
    }
}