#############################################################
## Name         : Compress-Files.ps1
## Version      : 1.0
## Author       : Lon Hammonds
## Purpose      : Compress files in a folder matching specific file extensions and is older than x days.
##              : NOTE: Archive timestamp is set to match timestamp of original file.
## Compatibility: PowerShell 5.x - 7.x
## Requirements : PowerShell Modules: 7Zip4PowerShell (e.g. Compress-7Zip, Expand-7Zip)
##              :                     Install-Module 7Zip4PowerShell -Scope AllUsers -Verbose
## Example       : "pwsh.exe" -File C:\Apps\Compress-Files.ps1 -ExecutionPolicy Unrestricted -NoLogo -NonInteractive
## Exit Codes    : 0 = Normal termination.
##               : 1 = Folder does not exist.
## Run Frequency: Schedule as needed.
######################## CHANGE LOG #########################
## DATE       VER WHO WHAT WAS CHANGED
## ---------- --- --- ---------------------------------------
## 2024-01-11 1.0 LTH Created script.
#############################################################

#Requires -Modules 7Zip4PowerShell
Import-Module -Name 7Zip4PowerShell

$FilePath = "C:\TestFolder"
$FileExtensions = @(".doc", ".jpg", ".xls", ".pptx")
$TargetDate = (Get-Date).AddDays(-60)
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

function f_secure_delete {
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

##########################################################
##              M A I N   P R O G R A M                 ##
##########################################################

f_log "[INFO] Script started. Path = ${FilePath}, File Extensions = ${FileExtensions}, Target Date = ${TargetDate}" ${LogFile}
Write-Host "Log File = ${LogFile}"

if (-not (Test-Path $FilePath)) {
  # Folder not found
  f_log "[ERROR] Folder not found - ${FilePath}" ${LogFile}
  exit 1
}

Get-ChildItem -Path $FilePath | Where-Object {$_.LastWriteTime -lt $TargetDate -and $_.Extension -in $FileExtensions} |
ForEach-Object {
  $DateModified = $_.LastWriteTime
  $DateCreated = $_.CreationTime
  $SourceBaseName = $_.BaseName+$_.Extension
  $ArchiveFile = "${FilePath}\${SourceBaseName}.7z"
  Compress-7Zip -ArchiveFileName ${ArchiveFile} -Path $_.FullName -Format SevenZip -CompressionLevel Ultra -CompressionMethod Default
  If (Test-Path ${ArchiveFile}) {
    ## Set timestamps of archive to match the original file.
	$ArchiveObject = Get-Item -Path $ArchiveFile
	$ArchiveObject.CreationTime = $DateCreated
	$ArchiveObject.LastWriteTime = $DateModified
    f_log "[INFO] Archive created: ${ArchiveFile}" ${LogFile}
    $ReturnValue = f_secure_delete -FileName $_.FullName -Pass 3
    f_log $ReturnValue ${LogFile}
  } else {
    f_log "[WARNING] Failed to create archive: ${ArchiveFile}" ${LogFile}
  }
}

f_log "[INFO] Script finished." ${LogFile}
exit 0
