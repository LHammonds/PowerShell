<#
#############################################################
## Name         : Compress-Large-Files.ps1
## Version      : 1.0
## Date         : 2023-06-08
## Author       : LHammonds
## Purpose      : Compress large files to save space.
## Compatibility: PowerShell 5.x - 7.x
## Requirements : 7-Zip - https://7-zip.com
## Run Frequency: Schedule as needed.
######################## CHANGE LOG #########################
## DATE       VER WHO WHAT WAS CHANGED
## ---------- --- --- ---------------------------------------
## 2023-06-08 1.0 LTH Created script.
#############################################################
#>
$7Zip = "C:\Program Files\7-Zip\7z.exe"
$FilePath = "C:\Reports"

Get-ChildItem -Path $FilePath -Filter *.rpt |
ForEach-Object {
  #$FileDate = Get-Date -Date $_.LastWriteTime -UFormat "%Y-%m-%d_%H-%M-%S"
  $FileDate = Get-Date -Date $_.LastWriteTime -UFormat "%Y-%m-%d"
  $SourceFile = $_.FullName
  $SourceBaseName = $_.BaseName+$_.Extension
  $ArchiveFile = "${FilePath}\${FileDate}-${SourceBaseName}.7z"
  Start-Process -FilePath ${7Zip} -NoNewWindow -Wait -WorkingDirectory "${FilePath}" -ArgumentList "a -t7z -mx9 ${ArchiveFile} ${SourceFile}"
  If (Test-Path ${ArchiveFile}) {
    Remove-Item ${SourceFile}
  }
}
