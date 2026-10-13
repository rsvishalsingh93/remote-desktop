# One-time prep of a Windows test machine over SSH (see README "Windows over SSH"):
#   keep Tailscale up, ffmpeg for recording, optional "no Chrome", desktop helper (agent.ps1) on the visible desktop.
# Usage from the Mac: ./winprep.sh <address> [--no-chrome] [--buyer]
param([switch]$NoChrome, [switch]$Buyer)
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
$who = $env:USERNAME
if ($Buyer) {
  # A buyer's laptop, as far as a GitHub runner allows (see README "Buyer mode" for what it cannot copy).
  # 1. PowerShell scripts blocked, the default of home Windows 10/11 (uv's installer refused it, 13 Oct 2026).
  # (this script runs with -ExecutionPolicy Bypass, so PowerShell says the new setting is overridden: true for this process only)
  try { Set-ExecutionPolicy Restricted -Scope LocalMachine -Force; Set-ExecutionPolicy Undefined -Scope CurrentUser -Force } catch { }
  "policy: " + ((Get-ExecutionPolicy -List | ForEach-Object { "$($_.Scope)=$($_.ExecutionPolicy)" }) -join ' ')
  # 2. No Python, Git, Node or uv: take their folders off PATH (the image has all of them).
  $tools = 'python.exe', 'git.exe', 'node.exe', 'uv.exe'
  foreach ($scope in 'Machine', 'User') {
    $dirs = @([Environment]::GetEnvironmentVariable('Path', $scope) -split ';' | Where-Object { $_ })
    # WindowsApps stays: every Windows 10/11 has it, with a python.exe that only opens the Microsoft Store.
    $hide = @($dirs | Where-Object { $d = [Environment]::ExpandEnvironmentVariables($_)
      $d -notlike '*\Microsoft\WindowsApps*' -and @($tools | Where-Object { Test-Path (Join-Path $d $_) }).Count })
    [Environment]::SetEnvironmentVariable('Path', (@($dirs | Where-Object { $_ -notin $hide }) -join ';'), $scope)
    "off the $scope PATH: " + ($hide -join '; ')
  }
  # 3. A normal user (no administrator rights) whose name has a space and a non-English letter.
  $who = 'Test B' + [char]0xF9 + 'yer'   # not typed as a literal: PowerShell 5.1 reads this file as ANSI
  $pw = 'Kit-' + [guid]::NewGuid().ToString('N').Substring(0, 12) + '!a1'
  if (Get-LocalUser -Name $who -ErrorAction SilentlyContinue) { Set-LocalUser -Name $who -Password (ConvertTo-SecureString $pw -AsPlainText -Force) }
  else { New-LocalUser -Name $who -Password (ConvertTo-SecureString $pw -AsPlainText -Force) -PasswordNeverExpires | Out-Null }
  foreach ($sid in 'S-1-5-32-545', 'S-1-5-32-555') { Add-LocalGroupMember -SID $sid -Member $who -ErrorAction SilentlyContinue }   # Users, Remote Desktop Users
  Add-LocalGroupMember -Group 'OpenSSH Users' -Member $who -ErrorAction SilentlyContinue   # sshd_config: AllowGroups administrators "openssh users"
  icacls C:\ctl /grant '*S-1-5-32-545:(OI)(CI)M' | Out-Null   # the helper runs as that user now
  [IO.File]::WriteAllText('C:\ctl\buyer.txt', "$who`r`n$pw`r`n", (New-Object Text.UTF8Encoding($false)))
  "buyer user: $who  password: $pw  (also in C:\ctl\buyer.txt)"
}
# A program started over SSH runs in a hidden session: an Interactive scheduled task puts it on the visible desktop (no password).
# Buyer mode: it runs as the buyer user, without administrator rights, from that user's sign-in (Windows App).
$a = New-ScheduledTaskAction -Execute powershell.exe -Argument '-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\ctl\agent.ps1'
$p = New-ScheduledTaskPrincipal -UserId $who -LogonType Interactive -RunLevel $(if ($Buyer) { 'Limited' } else { 'Highest' })
$task = @{ TaskName = 'ctlagent'; Action = $a; Principal = $p; Force = $true }
if ($Buyer) { $task.Trigger = New-ScheduledTaskTrigger -AtLogOn -User $who }
Stop-ScheduledTask ctlagent -ErrorAction SilentlyContinue   # a helper already running as the other user
Register-ScheduledTask @task | Out-Null
if (-not $Buyer) { Start-ScheduledTask ctlagent }
"prep done"
