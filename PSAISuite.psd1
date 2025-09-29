@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'PSAISuite.psm1'
    
    # Version number of this module.
    ModuleVersion     = '0.5.2'
    
    # ID used to uniquely identify this module
    GUID              = 'f5a37b81-6a5a-4b5c-a6e1-2b8a5f9c2fd8'
    
    # Author of this module
    Author            = 'Doug Finke'
    
    Copyright         = '© 2025 All rights reserved.'
    
    # Description of the functionality provided by this module
    Description       = 'PowerShell module for simple, unified interface to multiple Generative AI providers'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Get-ChatProviders'
        'Register-ChatProvider'
        'Invoke-ChatCompletion'
        'New-ChatMessage'
        'Get-OpenRouterModel'
        'Get-GitHubModel'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport   = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport   = @(
        'icc'
        'generateText'
    )
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module
            Tags       = @('AI', 'OpenAI', 'Anthropic', 'GPT', 'Claude', 'PowerShell')
            
            # Project URI
            ProjectUri = 'https://github.com/dfinke/PSAISuite'

            # License URI
            LicenseUri = 'https://github.com/dfinke/PSAISuite/blob/master/LICENSE'
        }
    }
}

# PrivateData        = @{
#     # PSData is module packaging and gallery metadata embedded in PrivateData
#     # It's for rebuilding PowerShellGet (and PoshCode) NuGet-style packages
#     # We had to do this because it's the only place we're allowed to extend the manifest
#     # https://connect.microsoft.com/PowerShell/feedback/details/421837
#     PSData = @{
#         # The primary categorization of this module (from the TechNet Gallery tech tree).
#         Category     = "Scripting Excel"

#         # Keyword tags to help users find this module via navigations and search.
#         Tags         = @("Excel", "EPPlus", "Export", "Import")

#         # The web address of an icon which can be used in galleries to represent this module
#         #IconUri = 

#         # The web address of this module's project or support homepage.
#         ProjectUri   = "https://github.com/dfinke/ImportExcel"

#         # The web address of this module's license. Points to a page that's embeddable and linkable.
#         LicenseUri   = "https://github.com/dfinke/ImportExcel/blob/master/LICENSE.txt"

#         # Release notes for this particular version of the module
#         #ReleaseNotes = $True

#         # If true, the LicenseUrl points to an end-user license (not just a source license) which requires the user agreement before use.
#         # RequireLicenseAcceptance = ""

#         # Indicates this is a pre-release/testing version of the module.
#         IsPrerelease = 'False'
#     }
# }