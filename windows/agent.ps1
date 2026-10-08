# Runs on the visible desktop (started by prep.ps1 as an Interactive scheduled task). Reads C:\ctl\cmd.txt
# (one command per line), so an agent can click, type and record over SSH. Helper on the Mac: ../wc.
Add-Type @"
using System; using System.Runtime.InteropServices;
public class M { [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(int f,int x,int y,int d,int e);
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[M]::SetProcessDPIAware() | Out-Null
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
while ($true) {
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; "$($b.Width)x$($b.Height)" | Set-Content C:\ctl\screen.txt
  if (Test-Path C:\ctl\cmd.txt) {
    $lines = Get-Content C:\ctl\cmd.txt; Remove-Item C:\ctl\cmd.txt
    foreach ($l in $lines) { $p = $l -split ' '
      switch ($p[0]) {
        'click'  { [M]::SetCursorPos([int]$p[1],[int]$p[2]); Start-Sleep -m 80; [M]::mouse_event(2,0,0,0,0); [M]::mouse_event(4,0,0,0,0) }
        'dbl'    { [M]::SetCursorPos([int]$p[1],[int]$p[2]); 1..2 | % { [M]::mouse_event(2,0,0,0,0); [M]::mouse_event(4,0,0,0,0); Start-Sleep -m 60 } }
        'rclick' { [M]::SetCursorPos([int]$p[1],[int]$p[2]); [M]::mouse_event(8,0,0,0,0); [M]::mouse_event(16,0,0,0,0) }
        'move'   { [M]::SetCursorPos([int]$p[1],[int]$p[2]) }
        'scroll' { [M]::SetCursorPos([int]$p[1],[int]$p[2]); [M]::mouse_event(0x800,0,0,[int]$p[3],0) }
        'keys'   { [System.Windows.Forms.SendKeys]::SendWait($l.Substring(5)) }
        'paste'  { Get-Content C:\ctl\clip.txt -Raw | Set-Clipboard; [System.Windows.Forms.SendKeys]::SendWait('^v') }
        'run'    { Start-Process -FilePath $p[1] -ArgumentList ($p[2..($p.Count)] -join ' ') }
        'shot'   { $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height; $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen(0,0,0,0,$bmp.Size); $bmp.Save('C:\ctl\shot.png'); $g.Dispose(); $bmp.Dispose() }
        'recstart' { New-Item -ItemType Directory -Force C:\ctl\rec | Out-Null; $r = Start-Process ffmpeg -WindowStyle Hidden -PassThru -RedirectStandardError C:\ctl\ffmpeg.log -ArgumentList "-y -f gdigrab -framerate 30 -draw_mouse 1 -i desktop -c:v libx264 -preset ultrafast -crf 22 -pix_fmt yuv420p -f segment -segment_time 60 -reset_timestamps 1 C:\ctl\rec\$($p[1])-%03d.mkv"; $r.Id | Set-Content C:\ctl\rec.pid }
        'recstop'  { if (Test-Path C:\ctl\rec.pid) { Stop-Process -Id (Get-Content C:\ctl\rec.pid) -Force; Remove-Item C:\ctl\rec.pid } }
      }
      "$(Get-Date -f HH:mm:ss) $l" | Add-Content C:\ctl\done.log }
  }
  Start-Sleep -m 150
}
