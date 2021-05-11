
[CmdletBinding()]
param (
    [Parameter(Mandatory, HelpMessage = 'Path to executable to run')]
    [System.IO.FileInfo]
    $ToolPath,

    [Parameter(HelpMessage = 'Parameters to pass into the application')]
    [string[]]
    $ArgumentList,

    [Parameter(HelpMessage = 'Path to log file for tool output')]
    [System.IO.FileInfo]
    $LogPath,

    [Parameter(HelpMessage = 'Credentials for the user account to impersonate')]
    [pscredential]
    $Credential,

    [Parameter(HelpMessage = 'Wait for database tool to complete and write output')]
    [switch]
    $Wait
)

$ErrorActionPreference = 'Stop'

# Determine log path + name if not set
if (-not $PSBoundParameters.ContainsKey('LogPath')) {
    $toolName = [io.path]::GetFileNameWithoutExtension($ToolPath)

    # Fallback
    if ([string]::IsNullOrEmpty($toolName)) {
        $toolName = 'InvokeDatabaseTool'
    }

    # E.g. file name: 2021-05-11_12-45_MyDatabaseTool.txt
    $LogPath = "$env:TEMP\$(Get-Date -Format yyyy-MM-dd_HH-mm)_$toolName.txt"

    if (Test-Path $LogPath) {
        Write-Error "Log file $LogPath already exists"
    }
}

$scriptBlock = {
    $ErrorActionPreference = 'Stop'

    Write-Output @"
--------------------------
Username: $(($env:USERNAME).ToLower())
PowerShell version: $($PSVersionTable.PSVersion.ToString())
Application: $($using:ToolPath)
Arguments: $($using:ArgumentList)
--------------------------
"@ | Tee-Object -FilePath $using:LogPath
    
    & $using:ToolPath $using:ArgumentList | Tee-Object -FilePath $using:LogPath -Append

    if ($LASTEXITCODE -ne 0) {
        exit 1
    }
}

$jobParams = @{
    Name        = ([guid]::NewGuid().Guid -split '-')[0]
    ScriptBlock = $scriptBlock
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