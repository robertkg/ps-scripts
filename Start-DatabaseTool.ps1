<#
.SYNOPSIS
    Starts a job that runs a given database tool and writes the output to a log file.
.DESCRIPTION
    This script spawns a new PowerShell job on the local machine that runs a given database tool executable.
    The output streams (stdout, stderr) is written to the output stream and to a log file on the system.
    Arguments should be provided as an array.
    To run in a different security context, e.g. a service account with elevated DB permissions, provide
    the Credential parameter.
.EXAMPLE
    PS C:\> .\Start-DatabaseTool.ps1 -FilePath C:\DatabaseTool.exe -ArgumentList '--database=mydb', '--dryrun' -Credential $cred

    This command runs a database tool against database mydb without making any changes. The job spawned by the command
    will be run in the security context stored in the $cred variable.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory, HelpMessage = 'Path to executable to run')]
    [System.IO.FileInfo]
    $FilePath,

    [Parameter(HelpMessage = 'Additional parameters to pass into the application')]
    [string[]]
    $ArgumentList,

    [Parameter(HelpMessage = 'Credentials for the user account to impersonate')]
    [pscredential]
    $Credential,

    [Parameter(HelpMessage = 'Wait for database tool to complete and write output')]
    [switch]
    $Wait,

    [Parameter(HelpMessage = 'Path to log file for tool output')]
    [System.IO.FileInfo]
    $LogPath

)

$ErrorActionPreference = 'Continue'

$guid = ([guid]::NewGuid().Guid -split '-')[0]

# Determine log path + name if not set
if (-not $PSBoundParameters.ContainsKey('LogPath')) {
    $toolName = [io.path]::GetFileNameWithoutExtension($FilePath)

    # Fallback
    if ([string]::IsNullOrEmpty($toolName)) {
        $toolName = "DatabaseTool-$guid"
    }

    # E.g. file name: 2021-05-11_12-45_MyDatabaseTool.txt
    $LogPath = "$env:TEMP\$(Get-Date -Format yyyy-MM-dd_HH-mm)_$toolName.txt"

    if (Test-Path $LogPath) {
        Write-Error "Log file $LogPath already exists"
    }
}

$scriptBlock = {
    $ErrorActionPreference = 'Continue' # Catch all output from the database tool and throw on last exit code check

    Write-Output @"
--------------------------
Application: $using:FilePath
Arguments: $using:ArgumentList
RunAs: $(($env:USERNAME).ToLower())
PowerShell version: $($PSVersionTable.PSVersion.ToString())
Start time: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')
--------------------------
"@ | Tee-Object -FilePath $using:LogPath

    $stopwatch = [System.Diagnostics.Stopwatch]::new()
    $stopwatch.Start()

    & $using:FilePath $using:ArgumentList *>&1 | Tee-Object -FilePath $using:LogPath -Append
    $capturedExitCode = $LASTEXITCODE #

    $stopwatch.Stop()
    Write-Output '------------------------------------------'
    Write-Output "Completion time: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss') ($($stopwatch.Elapsed.ToString('hh\:mm\:ss')))"

    if ($capturedExitCode -ne 0) {
        throw 'Database tool failed'
    }
}

$jobParams = @{
    Name        = $guid
    ScriptBlock = $scriptBlock
    ErrorAction = 'Continue'
}
    
if ($PSBoundParameters.ContainsKey('Credential')) {
    $jobParams.Add('Credential', $Credential)
}

$job = Start-Job @jobParams 

if ($PSBoundParameters.ContainsKey('Wait')) {
    Receive-Job -Job $job -Wait
    Get-Content -Path $LogPath -Raw -Encoding utf8 | Set-Clipboard
    Write-Host "`nJob completed. Contents of $LogPath copied to clipboard" -ForegroundColor Green
}
else {
    Write-Output $job
    Write-Host "`nJob started. See log file for output: $LogPath" -ForegroundColor Green
}