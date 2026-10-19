#requires -Version 5.1
######################################################################
## Name          : Github-CodeDL.ps1
## Purpose       : Downloads clean source-code snapshots of all GitHub branches.
## Output        : <OutputRoot><project>\main\
##               : <OutputRoot><project>\branches\<branch-name>
## Compatibility : PowerShell 5.x - 7.x
## Requirements  : PowerShell 5.1+
##               : Git
## Example       : "powershell.exe" -ExecutionPolicy Unrestricted -NoLogo -NonInteractive -File C:\Apps\Github-CodeDL.ps1
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
$ErrorActionPreference = "Stop"
$GitHubRoot = "https://github.com/YOURID"
$OutputRoot = "C:\Code\github"
$Projects = @('YOURPROJ1', 'YOURPROJ2', 'YOURPROJ3')
$LogFile = Join-Path $OutputRoot 'Github-CodeDL.log'

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

function f_Get_SafeFolderName {
  param([string]$Name)
  # Branch names may contain slashes, colons and other invalid
  # Windows filename characters.
  $Safe = $Name -replace '[<>:"/\\|?*]', '_'
  $Safe = $Safe.TrimEnd('.', ' ')
  if ([string]::IsNullOrWhiteSpace($Safe)) {
    throw "Branch name '$Name' cannot be converted to a folder name."
  }
  return $Safe
} ## f_Get_SafeFolderName()

function f_ExportBranchCode {
  param(
    [string]$RepositoryPath,
    [string]$BranchRef,
    [string]$Destination
  )
  $Parent = Split-Path -Parent $Destination
  New-Item -ItemType Directory -Path $Parent -Force | Out-Null
  # Export into a temporary directory first so a failed export
  # does not leave a partially written branch snapshot.
  $TempDirectory = Join-Path $Parent ('.export-' + [guid]::NewGuid().ToString('N'))
  $ZipPath = Join-Path $env:TEMP ('Github-CodeDL-' + [guid]::NewGuid().ToString('N') + '.zip')
  try {
    # Git archive exports tracked files at the selected commit.
    f_Git -GitArgs @('-C', $RepositoryPath, 'archive', '--format=zip', '--output', $ZipPath, $BranchRef)
    New-Item -ItemType Directory -Path $TempDirectory | Out-Null
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $TempDirectory -Force
    if (Test-Path -LiteralPath $Destination) {
      Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    Move-Item -LiteralPath $TempDirectory -Destination $Destination
  }
  finally {
    if (Test-Path -LiteralPath $ZipPath) {
      Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $TempDirectory) {
      Remove-Item -LiteralPath $TempDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
} ## f_ExportBranchCode()

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
  $ProjectPath = Join-Path $OutputRoot $Project
  $TempRepo = Join-Path $env:TEMP ('Github-CodeDL-' + [guid]::NewGuid().ToString('N'))
  f_Log "[INFO] Processing $Project from ${RepoUrl}"
  try {
    # A temporary bare clone downloads all branches and history.
    f_Git -GitArgs @('clone', '--bare', $RepoUrl, $TempRepo)
    $BranchOutput = @(& git -C $TempRepo for-each-ref '--format=%(refname:short)' refs/heads)
    if ($LASTEXITCODE -ne 0) {
      throw "Could not enumerate branches for ${Project}"
    }
    $Branches = @(
      $BranchOutput |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' } |
        Sort-Object -Unique
    )
    if ($Branches.Count -eq 0) {
      throw "No branches were found for ${Project}"
    }
    $MainBranch = $null

    if ($Branches -contains 'main') {
      $MainBranch = 'main'
    }
    elseif ($Branches -contains 'master') {
      # Support older repositories whose default branch is master.
      $MainBranch = 'master'
    }
    else {
      # Fall back to the remote's advertised default branch.
      $HeadOutput = @(& git -C $TempRepo symbolic-ref HEAD)
      if ($LASTEXITCODE -eq 0 -and $HeadOutput.Count -gt 0) {
        $Candidate = ($HeadOutput[0] -replace '^refs/heads/', '')
        if ($Branches -contains $Candidate) {
          $MainBranch = $Candidate
        }
      }
      if (-not $MainBranch) {
        $MainBranch = $Branches[0]
      }
    }
    $MainPath = Join-Path $ProjectPath 'main'
    # Export the selected primary branch to the main folder.
    f_ExportBranchCode -RepositoryPath $TempRepo -BranchRef "refs/heads/$MainBranch" -Destination $MainPath
    f_Log "[INFO] Exported $Project primary branch ${MainBranch}"
    $OtherBranches = @($Branches | Where-Object { $_ -ne $MainBranch })
    if ($OtherBranches.Count -gt 0) {
      $BranchesPath = Join-Path $ProjectPath 'branches'
      New-Item -ItemType Directory -Path $BranchesPath -Force | Out-Null
      $UsedNames = @{}
      foreach ($Branch in $OtherBranches) {
        $FolderName = f_Get_SafeFolderName -Name $Branch
        # Prevent collisions after replacing invalid filename characters.
        if ($UsedNames.ContainsKey($FolderName)) {
          $Hash = [System.BitConverter]::ToString(
            [System.Security.Cryptography.SHA256]::Create().ComputeHash(
              [System.Text.Encoding]::UTF8.GetBytes($Branch)
            )
          ).Replace('-', '').Substring(0, 8)
          $FolderName = "${FolderName}-${Hash}"
        }
        $UsedNames[$FolderName] = $true
        $BranchPath = Join-Path $BranchesPath $FolderName
        f_ExportBranchCode -RepositoryPath $TempRepo -BranchRef "refs/heads/$Branch" -Destination $BranchPath
        f_Log "[INFO] Exported branch ${Branch} to ${BranchPath}"
      }
    }
    f_Log "[SUCCESS] ${Project} source snapshots exported."
  }
  catch {
    f_Log "[ERROR] ${Project} - $($_.Exception.Message)"
  }
  finally {
    if (Test-Path -LiteralPath $TempRepo) {
      Remove-Item -LiteralPath $TempRepo -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
f_Log '[INFO] Script completed.'
