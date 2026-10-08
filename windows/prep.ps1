# One-time prep of a Windows test machine over SSH (see README "Windows over SSH"):
#   keep Tailscale up, ffmpeg for recording, optional "no Chrome", desktop helper (agent.ps1) on the visible desktop.
# Usage from the Mac: ./winprep.sh <address> [--no-chrome]
param([switch]$NoChrome)
$ProgressPreference = 'SilentlyContinue'
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (Test-Path $ts) { & $ts set --unattended=true 2>&1; & $ts set --auto-update=false 2>&1 }
Get-Process tailscale-ipn -ErrorAction SilentlyContinue | Stop-Process -Force   # its "Connect to your tailnet" window and tray
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) { choco install ffmpeg -y --no-progress | Select-Object -Last 1 }
if ($NoChrome) {
  Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force
  Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object DisplayName -like 'Google Chrome*' | ForEach-Object {
      if ($_.UninstallString -like 'MsiExec*') { Start-Process msiexec.exe -ArgumentList "/x $($_.PSChildName) /qn /norestart" -Wait }
      else { $exe, $rest = $_.UninstallString -split ' --', 2; Start-Process ($exe.Trim('"')) -ArgumentList "--$rest --force-uninstall" -Wait } }
  "chrome present: " + (Test-Path 'C:\Program Files\Google\Chrome\Application\chrome.exe')
}
New-Item -ItemType Directory -Force C:\ctl | Out-Null
# A program started over SSH runs in a hidden session: an Interactive scheduled task puts it on the visible desktop (no password).
$a = New-ScheduledTaskAction -Execute powershell.exe -Argument '-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\ctl\agent.ps1'
$p = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName ctlagent -Action $a -Principal $p -Force | Out-Null
Start-ScheduledTask ctlagent
"prep done"
