#############################################################
## Name         : FileMaster.ps1
## Version      : 1.0
## Author       : Lon Hammonds
## Purpose      : File compression, deletion, move and purge.
##              : NOTE: Archive timestamp is set to match timestamp of original file.
## Compatibility: PowerShell 5.x - 7.x
## Requirements : PowerShell Modules: 7Zip4PowerShell (e.g. Compress-7Zip, Expand-7Zip)
##              :                     Install-Module 7Zip4PowerShell -Scope AllUsers -Verbose
## Example       : "pwsh.exe" -File C:\Apps\FileMaster.ps1 -ExecutionPolicy Unrestricted -NoLogo -NonInteractive
## Exit Codes    : 0 = Normal termination.
##               : 1 = Folder does not exist.
## Run Frequency: Schedule as needed.
######################## CHANGE LOG #########################
## DATE       VER WHO WHAT WAS CHANGED
## ---------- --- --- ---------------------------------------
## 2024-01-15 1.0 LTH Created script.
#############################################################

#Requires -Modules 7Zip4PowerShell
Import-Module -Name 7Zip4PowerShell

$LogFile = "${PSScriptRoot}\Logs\$((Get-Item ${MyInvocation}.MyCommand.Path).BaseName).log"

##########################################################
##                 F U N C T I O N S                    ##
##########################################################

Function f_log()
{
  ## Need cmdlet binding for the verbose and debug options. ##
  [CmdletBinding(PositionalBinding=$True)]
  Param(
    [string]$Txt,
    [string]$File,
    [parameter(ValueFromRemainingArguments=$true)]
    [String[]] $args
  )
  $ltimestamp = (Get-Date).toString("yyyy-MM-dd_HH-mm-ss")
  Write-Output "${ltimestamp} ${Txt}" | Out-File "${File}" -Append

} ## f_log() ##

Function f_secure_delete {
  param (
    [string]$FileName,
    [int]$Pass = 1
  )
  # Check if the file exists
  if (-Not (Test-Path -Path $FileName -PathType Leaf)) {
    Write-Host "The file does not exist: $FileName"
    return
  }
  $FileSize = (Get-Item -Path $FileName).Length
  # Generate random data to overwrite the file
  $randomData = New-Object byte[] 1024
  $randomNumberGenerator = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
  # Overwrite the file with random data multiple times
  for ($MyCount = 1; $MyCount -le $Pass; $MyCount++) {
    $fileStream = New-Object System.IO.FileStream($FileName, 'Open', 'ReadWrite')
    $BytesWritten = 0
    while ($BytesWritten -lt $FileSize) {
      $RemainingBytes = [Math]::Min($randomData.Length, ($FileSize - $BytesWritten))
      $randomNumberGenerator.GetBytes($randomData)
      $fileStream.Write($randomData, 0, $randomData.Length)
      $BytesWritten += $RemainingBytes
    }
    $fileStream.Dispose()
  }
  Remove-Item -Path $FileName -Force
  return "[SECURE-DELETE-${Pass}] $FileName"
} ## f_secure_delete() ##

Function f_Archive {
  ## Need cmdlet binding for the verbose and debug options. ##
  [CmdletBinding(PositionalBinding=$True)]
  Param(
    [string]$SourceDir,
    [string]$FileExtensions,
    [string]$Days,
    [parameter(ValueFromRemainingArguments=$true)]
    [String[]] $args
  )
  if (-not (Test-Path $SourceDir)) {
    # Folder not found
    f_log "[ERROR] Archive source folder not found - ${SourceDir}" $LogFile
    return 1
  }
  if ($Days -eq $null -or $Days -eq "") {
    # Assign a default value of -365
    $Days = -365
  }
  $FileCounter = 0
  $arrFileExt = $FileExtensions.Split(",")
  f_log "[INFO] Archiving files ${FileExtensions} older than ${Days} days in ${SourceDir}" $LogFile
  foreach ($FileExt in $arrFileExt) {
    $TargetDate = (Get-Date).AddDays(${Days})
    Get-ChildItem -Path $SourceDir -Filter $FileExt | Where-Object {$_.LastWriteTime -lt $TargetDate} |
    ForEach-Object {
      $DateModified = $_.LastWriteTime
      $DateCreated = $_.CreationTime
      $SourceBaseName = $_.BaseName+$_.Extension
      $ArchiveFile = "${SourceDir}\${SourceBaseName}.7z"
      Compress-7Zip -ArchiveFileName ${ArchiveFile} -Path $_.FullName -Format SevenZip -CompressionLevel Ultra -CompressionMethod Default
      If (Test-Path ${ArchiveFile}) {
        ## Set timestamps of archive to match the original file.
        $ArchiveObject = Get-Item -Path $ArchiveFile
        $ArchiveObject.CreationTime = $DateCreated
        $ArchiveObject.LastWriteTime = $DateModified
        if ($PSBoundParameters['Verbose']) {
          f_log "[ARCHIVE] Created: ${SourceBaseName}.7z" $LogFile
        }
        $ReturnValue = f_secure_delete -FileName $_.FullName -Pass 3
        if ($PSBoundParameters['Verbose']) {
          f_log $ReturnValue ${LogFile}
        }
        $FileCounter++
      } else {
        f_log "[WARNING] Failed to create archive: ${ArchiveFile}" $LogFile
      }
    }
  }
  f_log "[INFO] Total files archived: ${FileCounter}" $LogFile
} ## f_Archive() ##

Function f_Move {
  ## Need cmdlet binding for the verbose and debug options. ##
  [CmdletBinding(PositionalBinding=$True)]
  Param(
    [string]$SourceDir,
    [string]$TargetDir,
    [string]$FileExtensions,
    [string]$Days,
    [parameter(ValueFromRemainingArguments=$true)]
    [String[]] $args
  )
  if (-not (Test-Path $SourceDir)) {
    f_log "[ERROR] Move source folder not found - ${SourceDir}" $LogFile
    return 1
  }
  if (-not (Test-Path $TargetDir)) {
    f_log "[ERROR] Move target folder not found - ${TargetDir}" $LogFile
    return 1
  }
  if ($Days -eq $null -or $Days -eq "") {
    # Assign a default value of -365
    $Days = -365
  }
  $FileCounter = 0
  $arrFileExt = $FileExtensions.Split(",")
  f_log "[INFO] Moving files ${FileExtensions} older than ${Days} days from ${SourceDir} to ${TargetDir}" $LogFile
  foreach ($FileExt in $arrFileExt) {
    $FilesToMove = Get-ChildItem -Path $SourceDir -Filter $FileExt | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays($Days) }
    foreach ($File in $FilesToMove) {
      $TargetPath = Join-Path -Path $TargetDir -ChildPath $File.Name
      if (-not (Test-Path $TargetPath)) {
        ## File does not exist in target.  Allowed to move.
        Move-Item -Path $File.FullName -Destination $TargetDir
        $FileCounter++
        if ($PSBoundParameters['Verbose']) {
          f_log "[MOVED] $($File.Name)" $LogFile
        }
      } else {
        f_log "[WARNING] File already exists in target: $($File.FullName)" $LogFile
      }
      if (-not (Test-Path $TargetPath)) {
        ## File still does not exist after the move above.
        f_log "[ERROR] File did not get moved to target: $($File.FullName)" $LogFile
      }
    }
  }
  f_log "[INFO] Total files moved: ${FileCounter}" $LogFile
} ## f_Move() ##

Function f_Purge {
  ## Need cmdlet binding for the verbose and debug options. ##
  [CmdletBinding(PositionalBinding=$True)]
  Param(
    [string]$SourceDir,
    [string]$FileExtensions,
    [string]$Days,
    [parameter(ValueFromRemainingArguments=$true)]
    [String[]] $args
  )
  if (-not (Test-Path $SourceDir)) {
    f_log "[ERROR] Purge source folder not found - ${SourceDir}" $LogFile
    return 1
  }
  if ($Days -eq $null -or $Days -eq "") {
    # Assign a default value of -365
    $Days = -365
  }
  $FileCounter = 0
  $ReturnValue = ""
  $arrFileExt = $FileExtensions.Split(",")
  f_log "[INFO] Purging files ${FileExtensions} older than ${Days} days from ${SourceDir}" $LogFile
  foreach ($FileExt in $arrFileExt) {
    Get-ChildItem -Path $SourceDir -Filter $FileExt | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays($Days) } |
    ForEach-Object {
      ## Securely delete file (3 passes). ##
      $ReturnValue = f_secure_delete -FileName $_.FullName -Pass 3
      $FileCounter++
      if ($PSBoundParameters['Verbose']) {
        f_log $ReturnValue $LogFile
      }
    }
  }
  f_log "[INFO] Total files purged: ${FileCounter}" $LogFile
} ## f_Purge() ##

##########################################################
##              M A I N   P R O G R A M                 ##
##########################################################

$RemoteShare = "\\192.168.1.7\logs\"
$SourceRoot  = "C:\TestFolder"

# Capture the start time.
$StartTime = Get-Date

f_log "[INFO] Script started." ${LogFile}
Write-Host "Log File = ${LogFile}"

f_Archive "${SourceRoot}\DEBUG"   "*.log" -14                         -Verbose:$true
f_Move    "${SourceRoot}\DEBUG"   "${RemoteShare}\DEBUG"   "*.7z" -30 -Verbose:$true
f_Purge   "${RemoteShare}\DEBUG"   "*.7z" -90                         -Verbose:$true

f_Archive "${SourceRoot}\SYSLOG"  "*.log" -30                         -Verbose:$true
f_Move    "${SourceRoot}\SYSLOG"  "${RemoteShare}\SYSLOG"  "*.7z" -30 -Verbose:$true
f_Purge   "${RemoteShare}\SYSLOG"  "*.7z" -730                        -Verbose:$true

f_Archive "${SourceRoot}\TRANLOG" "*.failed" -3                       -Verbose:$true
f_Purge   "${SourceRoot}\TRANLOG" "*.7z"     -14                      -Verbose:$true

f_Archive "${SourceRoot}\LINE"    "*.txt,*.log" -3                    -Verbose:$true
f_Purge   "${SourceRoot}\LINE"    "*.7z"        -14                   -Verbose:$true

f_Archive "C:\APP\LOGS"          "*.log" -2                           -Verbose:$true
f_Move    "C:\APP\LOGS"          "${RemoteShare}\APP" "*.7z" -14      -Verbose:$true
f_Purge   "${RemoteShare}\APP"   "*.7z" -180                          -Verbose:$true

# Capture the completion time.
$FinishTime = Get-Date
$TotalRuntime = $FinishTime - $StartTime
$Hrs = $TotalRuntime.Hours
$Min = $TotalRuntime.Minutes
$Sec = $TotalRuntime.Seconds

f_log "[SUMMARY] Total runtime: ${Hrs} hour(s) ${Min} minute(s) ${Sec} second(s)" ${LogFile}

f_log "[INFO] Script finished." ${LogFile}
exit 0
