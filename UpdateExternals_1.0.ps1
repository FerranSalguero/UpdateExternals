Param(
    [string]$Directory = "trunk",
    [int]$NewRevision = -1,
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

$REVISION_REGEX_FORMAT = "(?mi)(?<beforeNumber>.+)@(?<number>[0-9]+)(?<afterNumber>.*)"

function Invoke-Svn([string]$arguments)
{
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "svn.exe"
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $arguments
    $pinfo.WorkingDirectory = $PWD
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()

    if($p.ExitCode -ne 0)
    {
        throw $stderr
    }

    return $stdout
}

function Get-SvnRevisions([string]$dir)
{
    return $(Invoke-Svn "propget svn:externals $dir -R") -split '\n'
}

function Get-YesNoAnswer([string]$question)
{
    return ("y", "yes", "true") -icontains (Read-Host $question)
}

# Assemble revisions hashtable per directory
$externals = @(Get-SvnRevisions $Directory)

# Print a list of currently defined externals on each folder
Write-Host "The following externals are currently defined" -ForegroundColor Yellow
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host $Directory
$externals | % { Write-Host "`t$_" }

$newRevisions = @{}
$tmpFile = "tmpExternals.txt"
$regexToUse = $REVISION_REGEX_FORMAT


$newRevisions = $externals | % { 
    $folder = [regex]::Replace($_, $regexToUse, '${afterNumber}').Trim() 
    $newrev = Invoke-Svn("info -r HEAD --show-item last-changed-revision $Directory/$folder")
    [regex]::Replace($_, $regexToUse, '${beforeNumber}@'+($newrev  -replace "`n|`r")+'${afterNumber}').Trim()
}

# Print a list of currently defined externals on each folder
Write-Host "New externals for ($Directory):" -ForegroundColor Green
$newRevisions -split "`n" | % { Write-Host "`t$_" -ForegroundColor Green }

if(Get-YesNoAnswer("Write changes?") -eq $true)
{
   #Easiest way to set multiple externals is to use a file...
   Set-Content -Path $tmpFile -Value $newRevisions # -NoNewline #NewLine is already present
   Invoke-Svn "propset svn:externals -F $tmpFile $Directory"
   Remove-Item $tmpFile

   Invoke-Svn "up $Directory"
}
else
{
   Write-Host "Not modifiying directory $Directory." -ForegroundColor Red
}


Exit 0;