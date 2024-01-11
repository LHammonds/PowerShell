#############################################################
## Name          : PurgeOldFolders.ps1
## Version       : 1.1
## Author        : LHammonds
## Purpose       : Purge all sub-folders older than or equal to X days old.
## Requirements  : None.
## Compatibility : PowerShell 5.1 or 7.x
## Example       : "pwsh.exe" -File C:\Apps\PurgeFolder.ps1 -ExecutionPolicy Unrestricted -NoLogo -NonInteractive
## Exit Codes    : 0 = Normal termination.
##               : 1 = Folder does not exist.
###################### CHANGE LOG ###########################
## DATE       VER WHO WHAT WAS CHANGED
## ---------- --- --- ------------------------------------------
## 2020-08-31 1.0 LTH Created script as MS-DOS Batch.
## 2024-01-11 1.1 LTH Converted MS-DOS Batch to PowerShell.
#############################################################

$DaysEqualTo = 4
$PurgeDate = (Get-Date).AddDays(-$DaysEqualTo)
$SourceDir = "C:\TestFolder"
$RootPath = ${PSScriptRoot}
$LogFile = "${RootPath}\Logs\$((Get-Item ${MyInvocation}.MyCommand.Path).BaseName).log"
$DirCount = 0

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

##########################################################
##              M A I N   P R O G R A M                 ##
##########################################################

f_log "[INFO] Script started. Purging sub-folders in ${SourceDir} older than ${PurgeDate}" ${LogFile}
Write-Host "Log File = ${LogFile}"

if (-not (Test-Path $SourceDir)) {
  # Folder not found
  f_log "[ERROR] Folder not found - ${SourceDir}" ${LogFile}
  exit 1
}

$DirCount = (Get-ChildItem -Directory ${SourceDir} -Recurse | Where-Object { $_.PSIsContainer -and $_.CreationTime -lt $PurgeDate }).Count

f_log "[INFO] Deleting ${DirCount} sub-folders..." ${LogFile}
Get-ChildItem -Path $SourceDir | Where-Object { $_.PSIsContainer -and $_.CreationTime -lt $PurgeDate } | Remove-Item -Recurse -Force

f_log "[INFO] Script completed." ${LogFile}
exit 0
