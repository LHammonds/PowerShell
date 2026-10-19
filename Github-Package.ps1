#requires -Version 5.1
######################################################################
## Name          : Github-Packages.ps1
## Purpose       : Creates full Git mirror backups and portable bundles.
##               : Existing mirror repositories are refreshed. Bundle files
##               : are recreated only after a successful mirror update.
## Output        : <OutputRoot>Packages\<project>.git
##               : <OutputRoot>Packages\<project>.bundle
## Restore       : Restore to Local Github Example.
##               :   git clone --mirror C:\Code\Packages\app1.bundle app1.git
##               :   git -C app1.git push --mirror ssh://git@my-git-server/app1.git
## Compatibility : PowerShell 5.x - 7.x
## Requirements  : PowerShell 5.1+
##               : Git
## Example       : "powershell.exe" -ExecutionPolicy Unrestricted -NoLogo -NonInteractive -File C:\Apps\Github-Packages.ps1
## Exit Codes    : 0 = Normal termination.
##               : 1 = Various throw exceptions.
##               : 2 = Git not installed.
## Run Frequency: Schedule as needed.
##################### CHANGE LOG #####################################
## DATE       VER WHO           WHAT WAS CHANGED
## ---------- --- ------------ ---------------------------------------
## 2026-10-19 1.0 LHammonds    Created script.
######################################################################

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$GitHubRoot = "https://github.com/YOURID"
$OutputRoot = "C:\Code\github\Packages"
$Projects = @('YOURPROJ1', 'YOURPROJ2', 'YOURPROJ3')
$LogFile = Join-Path $OutputRoot "Github-Package.log"

##########################################################
##                 F U N C T I O N S                    ##
##########################################################

function f_Log {
  param([string]$Txt)
  $ltimestamp = (Get-Date).toString("yyyy-MM-dd_HH-mm-ss")
  Write-Host "${ltimestamp} ${Txt}"
  Write-Output "${ltimestamp} ${Txt}" | Out-File "${LogFile}" -Append -Encoding UTF8
} ## f_Log()

function f_Git {
  param([string[]]$GitArgs)
  & git @GitArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Git failed with exit code ${LASTEXITCODE}: git $($GitArgs -join ' ')"
  }
} ## f_Git()

##########################################################
##              M A I N   P R O G R A M                 ##
##########################################################

## Git requirement check.
try {
  git --version | Out-Null
} catch [System.Management.Automation.CommandNotFoundException] {
  Write-Error "Git was not found. Install Git for Windows and add git.exe to PATH."
  exit 2
}
## Create main folder if needed.
if (-not (Test-Path -Path $OutputRoot -PathType Container)) {
  New-Item -Path $OutputRoot -ItemType Directory | Out-Null
}
f_Log '[INFO] Script started.'
foreach ($Project in $Projects) {
  $RepoUrl = '{0}/{1}.git' -f $GitHubRoot.TrimEnd('/'), $Project
  $MirrorPath = Join-Path $OutputRoot "$Project.git"
  $BundlePath = Join-Path $OutputRoot "$Project.bundle"
  $TempBundle = "$BundlePath.tmp"
  f_Log "[INFO] Processing ${Project} from ${RepoUrl}"
  try {
    if (Test-Path -LiteralPath $MirrorPath) {
      if (-not (Test-Path -LiteralPath (Join-Path $MirrorPath 'HEAD'))) {
        throw "Existing path is not a valid bare Git repository: ${MirrorPath}"
      }
      f_Git -GitArgs @('-C', $MirrorPath, 'remote', 'update', '--prune')
    }
    else {
      f_Git -GitArgs @('clone', '--mirror', $RepoUrl, $MirrorPath)
    }
    # A mirror contains refs from the remote, including branch refs
    # and tags. Bundle --all packages all refs Git can enumerate.
    if (Test-Path -LiteralPath $TempBundle) {
      Remove-Item -LiteralPath $TempBundle -Force
    }
    f_Git -GitArgs @('-C', $MirrorPath, 'bundle', 'create', $TempBundle, '--all')
    f_Git -GitArgs @('-C', $MirrorPath, 'bundle', 'verify', $TempBundle)
    Move-Item -LiteralPath $TempBundle -Destination $BundlePath -Force
    f_Log "[SUCCESS] ${Project} mirror and bundle created."
  } catch {
    if (Test-Path -LiteralPath $TempBundle) {
      Remove-Item -LiteralPath $TempBundle -Force -ErrorAction SilentlyContinue
    }
    f_Log "[ERROR] ${Project} - $($_.Exception.Message)"
  }
}
f_Log '[INFO] Script completed.'
