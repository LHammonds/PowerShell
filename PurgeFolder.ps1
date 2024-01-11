#############################################################
## Name          : PurgeFolder.ps1
## Version       : 1.1
## Author        : LHammonds
## Purpose       : Purge all files/sub-folders in a specific folder.
## Requirements  : None.
## Compatibility : PowerShell 5.1 or 7.x
## Example       : "pwsh.exe" -File C:\Apps\PurgeFolder.ps1 -ExecutionPolicy Unrestricted -NoLogo -NonInteractive
## Exit Codes    : 0 = Normal termination.
##               : 1 = Folder does not exist.
###################### CHANGE LOG ###########################
## DATE       VER WHO WHAT WAS CHANGED
## ---------- --- --- ------------------------------------------
## 2020-07-22 1.0 LTH Created script as MS-DOS Batch.
## 2024-01-09 1.1 LTH Converted MS-DOS Batch to PowerShell.
#############################################################

$SourceDir = "C:\TestFolder"
$RootPath = ${PSScriptRoot}
$LogFile = "${RootPath}\Logs\$((Get-Item ${MyInvocation}.MyCommand.Path).BaseName).log"
$FileCount = 0
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

f_log "[INFO] Script started. Purging ${SourceDir}" ${LogFile}

if (-not (Test-Path $SourceDir)) {
  # Folder not found
  f_log "[ERROR] Folder not found - ${SourceDir}" ${LogFile}
  exit 1
}

$FileCount = (Get-ChildItem -File ${SourceDir} -Recurse).Count
$DirCount = (Get-ChildItem -Directory ${SourceDir} -Recurse).Count

f_log "[INFO] Deleting ${FileCount} files..." ${LogFile}
Remove-Item -Path "${SourceDir}\*" -Force -Recurse

f_log "[INFO] Deleting ${DirCount} sub-folders..." ${LogFile}
Get-ChildItem -Path $SourceDir -Directory | ForEach-Object {
  f_log " -- RD $($_.FullName)" ${LogFile}
  Remove-Item -Path $($_.FullName) -Force -Recurse
}
f_log "[INFO] Script completed." ${LogFile}
exit 0
