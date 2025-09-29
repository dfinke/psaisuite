<#
.SYNOPSIS
    Generates a new Chat Provider file which can be used to interact with custom, third-party LLM providers.

.DESCRIPTION
    The Register-ChatProvider function creates and stores a new file in $PSScriptRoot/Providers/ProviderName.ps1.
    This provider can then be used for interacting with custom, third-party LLM providers.
    It requires an API key to be set in the environment variable 'PROVIDER_NAMEKey' (e.g. for OpenAICustom it would be $env:OpenAICustomKey).

.Parameter ProviderName
    The name of the Provider to use, should be one word, TitleCase (e.g. OpenAICustom, PerplexityBeta, LMStudio)

.PARAMETER ModelName
    The name of the Model to use for (e.g., 'gpt-5', 'llama-3-sonar-small-32k', 'sonar-medium-online', 'mistral-7b-instruct').

.PARAMETER ExtraHeaders
    Any additional headers that need to be submitted to the application (e.g. @{'X-Api-Key' = $MySecretKey; 'X-Client-Id' = $MyClientId })

.PARAMETER ExtraBody
    Any additional body that needs to be submitted to the application (e.g. additional context, tool calls etc).
    These will all be added to the root of the default body, overwriting any duplicate keys.

.PARAMETER ContentType
    The Content-Type header to be sent. By default this is 'application/json', but some endpoints may provide XML data, or require a specific Content-Type be set.

.PARAMETER Method
    The Method that should be used when sending the request. By default this is 'POST', but some endpoints may require GET/PUT/PATCH.

.PARAMETER APIReference
    A link to the API reference for the Provider. (optional)

.EXAMPLE
    Register-ChatProvider LMStudio http://localhost:1234/v1 gpt-oss
    Register-ChatProvider OllamaCustom https://api.doma.in/llm/openai-compat/v1 gemma3 -ExtraHeaders @{'X-Api-Key' = $MySecretKey}
    Register-ChatProvider Perplexity2 https://api.perplexity.ai sonar

.NOTES
    Requires that an Environment Variable to be set with a valid API key, with the given name of "$PROVIDERNAMEKey" (e.g. $env:LMStudioKey, $env:OllamaCustomKey, $env:Perplexity2Key).
#>

function Register-ChatProvider {
    param(
        [Parameter(Mandatory, Position=0)]
        [ValidatePattern('[A-Za-z0-9]+')]
        [String]
        $ProviderName,

        [Parameter(Mandatory, Position=1)]
        [URI]
        $BaseUri,

        [Parameter(Mandatory, Position=2)]
        [String]
        $ModelName,

        [Parameter()]
        [HashTable]
        $ExtraHeaders,

        [Parameter()]
        [HashTable]
        $ExtraBody,

        [Parameter()]
        [ValidatePattern('/')]
        [String]
        $ContentType = 'application/json',

        [Parameter()]
        [Net.HTTP.HTTPMethod]
        $Method = 'POST',

        [Parameter()]
        [String]
        $APIReference = 'https://docs.example.ai',

        [Parameter()]
        [Switch]
        $Force
    )

    begin {
        $FilePath = Join-Path $PSScriptRoot "../Providers/$ProviderName.ps1"
        $FileExists = Test-Path $FilePath
        if ($FileExists -and -NOT $Force.IsPresent) {
            throw "'$FilePath' already exists... If you would like to overwrite it, run this command again with -Force"
        }

        $Template = @'
<#
.SYNOPSIS
    Invokes the #PROVIDER_NAME# API to generate responses using specified models.

.DESCRIPTION
    The Invoke-#PROVIDER_NAME#Provider function sends requests to the #PROVIDER_NAME# API and returns the generated content.
    It requires an API key to be set in the environment variable '#PROVIDER_NAME#Key'.

.PARAMETER ModelName
    The name of the #PROVIDER_NAME# model to use (e.g., '#MODEL_NAME#').

.PARAMETER Messages
    An array of hashtables containing the messages to send to the model.

.EXAMPLE
    $Message = New-ChatMessage -Prompt 'Write a PowerShell function to calculate factorial'
    $response = Invoke-#PROVIDER_NAME#Provider -ModelName '#MODEL_NAME#' -Message $Message

.NOTES
    Requires the #PROVIDER_NAME#Key environment variable to be set with a valid API key.
    API Reference: #API_REFERENCE#
#>
function Invoke-#PROVIDER_NAME#Provider {
    param(
        [Parameter(Mandatory)]
        [String]$ModelName,

        [Parameter(Mandatory)]
        [HashTable[]]$Messages
    )

    $Headers = @{
        'Authorization' = "Bearer $env:#PROVIDER_NAME#Key"
        'Content-Type'  = $ContentType
    }
    #EXTRA_HEADERS#

    $Body = @{
        'model'    = $ModelName
        'messages' = $Messages
    }
    #EXTRA_BODY#

    $Request = @{
        Uri     = '#BASE_URI#chat/completions'
        Method  = '#METHOD#'
        Headers = $Headers
        Body    = $Body | ConvertTo-Json -Depth 10
    }

    try {
        $Response = Invoke-RestMethod @Request
        return $Response.choices[0].message.content
    } catch {
        Write-Error "#PROVIDER_NAME# API Error (HTTP $($_.Exception.Response.StatusCode.value__)): $($_.ErrorDetails.Message)"
        return "Error calling #PROVIDER_NAME# API: $($_.Exception.Message)"
    }
}
'@
    }

    process {
        $ExtraHeadersReplacement = [String]::Empty
        if ($PSBoundParameters.ContainsKey('ExtraHeaders')) {
            foreach ($Part in $ExtraHeaders.GetEnumerator()) {
                $ExtraHeadersReplacement += "`$Headers['$($Part.Key)'] = '$($Part.Value | ConvertTo-Json)' | ConvertFrom-Json"
            }
        }

        $ExtraBodyReplacement = [String]::Empty
        if ($PSBoundParameters.ContainsKey('ExtraBody')) {
            foreach ($Part in $ExtraBody.GetEnumerator()) {
                $ExtraBodyReplacement += "`$Body['$($Part.Key)'] = '$($Part.Value | ConvertTo-Json)' | ConvertFrom-Json"
            }
        }


        $Template = $Template.Replace('#PROVIDER_NAME#', $ProviderName)
        $Template = $Template.Replace('#MODEL_NAME#', $ModelName)
        $Template = $Template.Replace('#BASE_URI#', $BaseUri)
        $Template = $Template.Replace('#API_REFERENCE#', $APIReference)
        $Template = $Template.Replace('#EXTRA_HEADERS#', $ExtraHeadersReplacement)
        $Template = $Template.Replace('#EXTRA_BODY#', $ExtraBodyReplacement)
        $Template = $Template.Replace('#CONTENT_TYPE#', $ContentType)
        $Template = $Template.Replace('#METHOD#', $Method)

        $Template | Out-File $FilePath
    }

    end {
        if (-NOT $FileExists) {
            $ShouldAutoReloadModule = $Host.UI.PromptForChoice(
                "New Provider Warning",
                "As you are registering this Provider for the first time, please note that you will need to execute the following commands:`n - Remove-Module PSAISuite`n - Import-Module PSAISuite`n`nWould you like to perform this task automatically?",
                @('&No','&Yes'),
                1
            )
            if ($ShouldAutoReloadModule) {
                Remove-Module PSAISuite
                Import-Module PSAISuite
            }
        }
    }
}