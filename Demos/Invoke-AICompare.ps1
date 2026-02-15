#requires -Version 7.0
#requires -Module PSAI

<#
.SYNOPSIS
    A script to compare responses from multiple AI providers in parallel.
.DESCRIPTION
    This script takes a prompt and an array of provider:model strings, sends the prompt to each
.EXAMPLE
    $models = @(
        'openai:gpt-4.1',
        'xAI:grok-4-1-fast-non-reasoning',
        'anthropic:claude-sonnet-4-5-20250929',
        'google:gemini-flash-latest'
    )
    .\Invoke-AICompare.ps1 -Prompt "Date: $(Get-Date) - latest PowerShell news" -Models $models
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The query or instruction for the models.")]
    [string]$Prompt,

    [Parameter(Mandatory = $true, HelpMessage = "Array of 'provider:model' strings.")]
    [string[]]$Models,

    [Parameter(Mandatory = $false)]
    [object[]]$Tools
)

Write-Host "`n🚀 Parallel Bake-off: Sending prompt to $($Models.Count) models..." -ForegroundColor Cyan
Write-Host "Prompt: $Prompt`n" -ForegroundColor Yellow

# Create Windows Form for displaying results
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "AI Model Comparison Results"
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = 'CenterScreen'

# Top label with details
$label = New-Object System.Windows.Forms.Label
$label.Text = "🚀 Parallel Bake-off: Sending prompt to $($Models.Count) models...$([Environment]::NewLine)Prompt: $Prompt"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(10, 10)
$label.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($label)

# TabControl
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 60)
$tabControl.Size = New-Object System.Drawing.Size(760, 490)
$tabControl.DrawMode = 'OwnerDrawFixed'
$tabControl.Add_DrawItem({
        param($sender, $e)
        $tabPage = $tabControl.TabPages[$e.Index]
        $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($tabPage.BackColor)), $e.Bounds)
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
        $e.Graphics.DrawString($tabPage.Text, $tabControl.Font, $brush, $e.Bounds.X + 3, $e.Bounds.Y + 3)
        $brush.Dispose()
    })
$form.Controls.Add($tabControl)

# Create tabPages array with empty textboxes
$tabPages = @()
foreach ($model in $Models) {
    $tabPage = New-Object System.Windows.Forms.TabPage
    $tabPage.Text = $model
    $tabPage.BackColor = [System.Drawing.Color]::Yellow
    $tabPage.ForeColor = [System.Drawing.Color]::Black

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Multiline = $true
    $textBox.ReadOnly = $true
    $textBox.ScrollBars = 'Vertical'
    $textBox.WordWrap = $true
    $textBox.Text = "Processing..."
    $textBox.Dock = 'Fill'
    $textBox.Font = New-Object System.Drawing.Font("Consolas", 9)

    $tabPage.Controls.Add($textBox)
    $tabControl.TabPages.Add($tabPage)
    $tabPages += @{Model = $model; TextBox = $textBox; TabPage = $tabPage }
}

# Start background jobs for each model
$jobs = foreach ($model in $Models) {
    Start-Job -ScriptBlock {
        param($Prompt, $Tools, $Model)

        # Define the web search function in the job
        function Global:Invoke-WebSearch {
            param([Parameter(Mandatory)][string]$query)
            if (!$env:TAVILY_API_KEY) {
                return "Error: TAVILY_API_KEY environment variable is not set. Please set it to use the web search tool."
            }
            $tavilyParams = @{ api_key = $env:TAVILY_API_KEY; query = $query }
            $body = $tavilyParams | ConvertTo-Json -Depth 10
            Invoke-RestMethod -Method Post -Uri "https://api.tavily.com/search" -ContentType 'application/json' -Body $body
        }

        # Register tool
        $Tools += @(Register-Tool Invoke-WebSearch)

        $Timer = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $IccParams = @{ Prompt = $Prompt; Model = $Model }
            if ($Tools) { $IccParams.Tools = $Tools }
            $Response = Invoke-ChatCompletion @IccParams
            $Timer.Stop()
            [PSCustomObject]@{ Model = $Model; Status = "✅ Success"; Time = "$([math]::Round($Timer.Elapsed.TotalSeconds, 2))s"; Response = $Response }
        }
        catch {
            [PSCustomObject]@{ Model = $Model; Status = "❌ Failed"; Time = "$([math]::Round($Timer.Elapsed.TotalSeconds, 2))s"; Response = $_.Exception.Message }
        }
    } -ArgumentList $Prompt, $Tools, $model
}

# Timer to check for completed jobs and update textboxes
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500  # Check every 500ms
$timer.Add_Tick({
        $completedJobs = $jobs | Where-Object { $_.State -eq 'Completed' }
        foreach ($job in $completedJobs) {
            $result = Receive-Job $job
            $tab = $tabPages | Where-Object { $_.Model -eq $result.Model }
            if ($tab) {
                $responseText = $result.Response -replace "`n", [Environment]::NewLine
                $tab.TextBox.Text = "Status: $($result.Status)$([Environment]::NewLine)Time: $($result.Time)$([Environment]::NewLine)$([Environment]::NewLine)Response:$([Environment]::NewLine)$responseText"
                $tab.TabPage.BackColor = [System.Drawing.Color]::Lime
                $tabControl.Invalidate()
            }
            $jobs = $jobs | Where-Object { $_ -ne $job }
        }
        if ($jobs.Count -eq 0) {
            $timer.Stop()
        }
    })
$timer.Start()

# Show the form (modal)
$null = $form.ShowDialog()