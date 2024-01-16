#############################################################
## Name         : Create-Test-Files.ps1
## Version      : 1.0
## Author       : Lon Hammonds
## Purpose      : Create test files, one per day with timestamp set to that day.
## Compatibility: PowerShell 5.x - 7.x
## Requirements : None
## Example       : "pwsh.exe" -File C:\Apps\Create-Test-Files.ps1 -ExecutionPolicy Unrestricted -NoLogo -NonInteractive
## Exit Codes    : 0 = Normal termination.
## Run Frequency: Schedule as needed.
######################## CHANGE LOG #########################
## DATE       VER WHO WHAT WAS CHANGED
## ---------- --- --- ---------------------------------------
## 2024-01-16 1.0 LTH Created script.
#############################################################

##########################################################
##                 F U N C T I O N S                    ##
##########################################################

function f_create_test_files {
  param(
    [string]$FolderPath,
    [string]$FileExt,
    [string]$StartDate,
    [string]$EndDate
  )

  ## Convert start and end dates to DateTime objects.
  $LocalStartDate = Get-Date $StartDate
  $LocalEndDate = Get-Date $EndDate

  ## Loop through each day and create an empty file with the specified format.
  while ($LocalStartDate -le $LocalEndDate) {
    $FileName = $LocalStartDate.ToString("yyyy-MM-dd") + "-TestFile${FileExt}"
    $FilePath = Join-Path -Path $FolderPath -ChildPath $FileName

    ## Create an empty file.
    New-Item -Path $FilePath -ItemType File -Force

    ## Set DateCreated and DateModified to match the specified date.
    $file = Get-Item $FilePath
    $file.CreationTime = $LocalStartDate
    $file.LastWriteTime = $LocalStartDate

    ## Increment the date for the next iteration.
    $LocalStartDate = $LocalStartDate.AddDays(1)
  }
}

##########################################################
##              M A I N   P R O G R A M                 ##
##########################################################

f_create_test_files "C:\TestFolder\SYSLOG"  ".log"    "2023-01-01" "2024-01-16"
f_create_test_files "C:\TestFolder\TRANLOG" ".failed" "2023-01-01" "2024-01-16"
f_create_test_files "C:\TestFolder\LINE"    ".log"    "2023-01-01" "2024-01-16"
f_create_test_files "C:\TestFolder\LINE"    ".txt"    "2023-01-01" "2024-01-16"
f_create_test_files "C:\TestFolder\DEBUG"   ".log"    "2023-01-01" "2024-01-16"

exit 0
