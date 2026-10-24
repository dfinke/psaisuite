# Offline integration checks using real PowerShell hosts and Write-Progress.
# Run explicitly: pwsh -NoProfile -File ./__tests__/Test-AgentActivityHost.ps1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
if (-not ('AgentActivityHost' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.Management.Automation;
using System.Management.Automation.Host;
using System.Security;

public sealed class AgentActivityHost : PSHost
{
    private readonly Guid id = Guid.NewGuid();
    public readonly AgentActivityUI Display;
    public AgentActivityHost(string mode) { Display = new AgentActivityUI(mode); }
    public override Guid InstanceId { get { return id; } }
    public override string Name { get { return "Agent activity integration host"; } }
    public override Version Version { get { return new Version(1, 0); } }
    public override CultureInfo CurrentCulture { get { return CultureInfo.InvariantCulture; } }
    public override CultureInfo CurrentUICulture { get { return CultureInfo.InvariantCulture; } }
    public override PSHostUserInterface UI { get { return Display; } }
    public override void SetShouldExit(int exitCode) { }
    public override void EnterNestedPrompt() { throw new NotSupportedException(); }
    public override void ExitNestedPrompt() { throw new NotSupportedException(); }
    public override void NotifyBeginApplication() { }
    public override void NotifyEndApplication() { }
}

public sealed class AgentActivityUI : PSHostUserInterface
{
    private readonly string mode;
    public readonly ConcurrentQueue<ProgressRecord> Progress = new ConcurrentQueue<ProgressRecord>();
    public readonly ConcurrentQueue<string> Verbose = new ConcurrentQueue<string>();
    public AgentActivityUI(string mode) { this.mode = mode; }
    public override PSHostRawUserInterface RawUI { get { return null; } }
    public override void WriteProgress(long sourceId, ProgressRecord record)
    {
        if (mode == "Unsupported") throw new NotSupportedException("This host cannot display progress.");
        if (mode == "Cancelled") throw new PipelineStoppedException();
        Progress.Enqueue(record);
    }
    public override void WriteVerboseLine(string message) { Verbose.Enqueue(message); }
    public override void Write(string value) { }
    public override void Write(ConsoleColor foreground, ConsoleColor background, string value) { }
    public override void WriteLine(string value) { }
    public override void WriteErrorLine(string value) { }
    public override void WriteDebugLine(string value) { }
    public override void WriteWarningLine(string value) { }
    public override string ReadLine() { throw new NotSupportedException(); }
    public override SecureString ReadLineAsSecureString() { throw new NotSupportedException(); }
    public override Dictionary<string, PSObject> Prompt(string caption, string message, Collection<FieldDescription> descriptions) { throw new NotSupportedException(); }
    public override int PromptForChoice(string caption, string message, Collection<ChoiceDescription> choices, int defaultChoice) { throw new NotSupportedException(); }
    public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName) { throw new NotSupportedException(); }
    public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName, PSCredentialTypes types, PSCredentialUIOptions options) { throw new NotSupportedException(); }
}
'@
}

$activitySource = (Resolve-Path "$PSScriptRoot/../Public/AgentActivity.ps1").Path
$scenario = {
    param($Source, $Wait)
    . $Source
    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'
    $ProgressPreference = 'Continue'
    $activity = New-AgentActivity -Provider 'Integration' -Model 'offline' -MaxIterations 3
    try {
        Write-AgentActivity -Activity $activity -Message 'Waiting for response' -Round 1
        if ($Wait) { while ($true) { Start-Sleep -Milliseconds 20 } }
        'answer'
    }
    finally {
        Write-AgentActivity -Activity $activity -Message 'Request stopped' -Completed
    }
}

foreach ($mode in @('Normal', 'Unsupported', 'Cancelled', 'StopPipeline')) {
    $displayMode = if ($mode -eq 'StopPipeline') { 'Normal' } else { $mode }
    $testHost = [AgentActivityHost]::new($displayMode)
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($testHost)
    $pipeline = [powershell]::Create()
    try {
        $runspace.Open()
        $pipeline.Runspace = $runspace
        $null = $pipeline.AddScript($scenario.ToString()).AddArgument($activitySource).AddArgument($mode -eq 'StopPipeline')
        $results = @()
        if ($mode -eq 'StopPipeline') {
            $pending = $pipeline.BeginInvoke()
            $deadline = [System.Diagnostics.Stopwatch]::StartNew()
            while ($testHost.Display.Progress.Count -eq 0 -and -not $pending.IsCompleted) {
                if ($deadline.Elapsed.TotalSeconds -gt 5) { throw 'Pipeline did not start reporting progress.' }
                Start-Sleep -Milliseconds 20
            }
            $pipeline.Stop()
            try { $null = $pipeline.EndInvoke($pending) }
            catch {
                if ($_.Exception -isnot [System.Management.Automation.PipelineStoppedException] -and
                    $_.Exception.InnerException -isnot [System.Management.Automation.PipelineStoppedException]) { throw }
            }
        }
        else {
            try { $results = @($pipeline.Invoke()) }
            catch {
                if ($mode -ne 'Cancelled') { throw }
            }
        }

        $events = $testHost.Display.Progress.ToArray()
        $logs = $testHost.Display.Verbose.ToArray()
        switch ($mode) {
            'Normal' {
                if ($results.Count -ne 1 -or [string]$results[0] -ne 'answer' -or
                    $events.Count -ne 2 -or $events[-1].RecordType -ne 'Completed') {
                    throw 'Normal progress altered the answer or failed to clear the display.'
                }
            }
            'Unsupported' {
                if ($results.Count -ne 1 -or [string]$results[0] -ne 'answer' -or
                    -not ($logs -match 'Progress display unavailable')) {
                    throw 'An unsupported progress display prevented the answer or hid the diagnostic.'
                }
            }
            'Cancelled' {
                if ($results.Count -gt 0 -or $pipeline.InvocationStateInfo.State -eq 'Completed' -or
                    ($logs -match 'Progress display unavailable')) {
                    throw 'A progress cancellation was swallowed as a display failure.'
                }
            }
            'StopPipeline' {
                if ($pipeline.InvocationStateInfo.State -ne 'Stopped' -or $events.Count -lt 2 -or
                    $events[-1].RecordType -ne 'Completed') {
                    throw 'Stopping the running pipeline did not cancel execution and clear progress.'
                }
            }
        }
        Write-Output "PASS: $mode"
    }
    finally {
        $pipeline.Dispose()
        $runspace.Dispose()
    }
}
