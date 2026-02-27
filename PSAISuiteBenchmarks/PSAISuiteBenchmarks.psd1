@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'PSAISuiteBenchmarks.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.0'

    # ID used to uniquely identify this module
    GUID              = '0e9f2e38-9d9a-42a0-acc0-14d25982a03c'

    # Author of this module
    Author            = 'Doug Finke'

    # Company or vendor of this module
    CompanyName       = 'Doug Finke'

    # Copyright statement for this module
    Copyright         = '(c) 2026 Doug Finke. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'A benchmark suite for evaluating AI models using PSAISuite.'

    # Functions to export from this module
    FunctionsToExport = @('Invoke-Benchmark', 'Invoke-BenchmarkScore')

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport   = @()
}
