#############################################################
## Name         : Convert-From-HEIC-Format.ps1
## Version      : 1.0
## Author       : LHammonds
## Purpose      : Convert HEIC image to a different format and preserve original timestamps.
## Compatibility: PowerShell 5.x - 7.x
## Requirements : ImageMagick (for convert.txt)
## Example       : "pwsh.exe" -File C:\Pictures\Convert-From-HEIC-Format.ps1 -ExecutionPolicy Unrestricted -NoLogo -NonInteractive
## Exit Codes    : 0 = Normal termination.
## Run Frequency: Schedule as needed.
######################## CHANGE LOG #########################
## DATE       VER WHO          WHAT WAS CHANGED
## ---------- --- ------------ ---------------------------------------
## 2024-04-21 1.0 LHammonds    Created script.
#############################################################
## Set path to ImageMagick
$ImageMagickPath = "C:\Program Files\ImageMagick-7.1.0-Q16-HDRI\convert.exe"

## Set path to directory containing .heic files (this assumes the current folder)
$SourceDir = $PWD.Path
## Or hard-code the target path:
#$SourceDir = "C:\Pictures"
$BackupDir = "${SourceDir}\converted"
$LogFile = "${SourceDir}\Convert-From-HEIC-Format.log"

$SourceExt = "heic"
$TargetExt = "jpg"

if (-not (Test-Path $BackupDir -PathType Container)) {
  New-Item -Path $BackupDir -ItemType Directory -Force
}
## Loop through each .heic file in the source directory
Get-ChildItem -Path $SourceDir -Filter *.${SourceExt} | ForEach-Object {
  $InputFile = $_.FullName
  $OutputFile = Join-Path -Path $SourceDir -ChildPath "$($_.BaseName).${TargetExt}"
    
  ## Preserve original creation and modification dates
  $CreationDate = $_.CreationTime
  $ModificationDate = $_.LastWriteTime
    
  ## Check if the output file already exists
  if (Test-Path $OutputFile) {
    ## Append date to filename
    $OutputFile = Join-Path -Path $SourceDir -ChildPath "$($_.BaseName)-$($CreationDate.ToString('yyyy-MM-dd')).${TargetExt}"
  }
  
  ## Use ImageMagick to convert image format.
  $OutputText = & $ImageMagickPath $InputFile -quality 85 $OutputFile 2>&1
  if (-not $OutputText) {
    ## ImageMagick: If no output from command, it probably worked without errors/warnings.
    if (Test-Path $OutputFile) {
      ## Conversion at least generated a file.
      ## Set new file creation and modification dates to match the original.
      (Get-Item $OutputFile).CreationTime = $CreationDate
      (Get-Item $OutputFile).LastWriteTime = $ModificationDate
      ## Move original to a backup folder.
      Move-Item -Path $InputFile -Destination $BackupDir -Force
      Write-Output "Converted to $OutputFile" | Out-File $LogFile -Append
    }
  } else {
    Write-Output "ImageMagick encountered a problem with ${OutputFile}" | Out-File $LogFile -Append
  }
}
if (Test-Path $LogFile) {
  notepad $LogFile
}
exit 0
