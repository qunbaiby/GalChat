param(
    [Parameter(Mandatory = $true)]
    [int]$GameProcessId,
    [Parameter(Mandatory = $true)]
    [long]$DesktopHost,
    [Parameter(Mandatory = $true)]
    [string]$LogPath
)

$ErrorActionPreference = "SilentlyContinue"
"$(Get-Date -Format o) watcher_ready pid=$PID game_pid=$GameProcessId host=$DesktopHost" | Add-Content -LiteralPath $LogPath
"$(Get-Date -Format o) waiting game_pid=$GameProcessId host=$DesktopHost" | Add-Content -LiteralPath $LogPath
if ($GameProcessId -gt 0) {
    Wait-Process -Id $GameProcessId
}
"$(Get-Date -Format o) game_exited game_pid=$GameProcessId host=$DesktopHost" | Add-Content -LiteralPath $LogPath

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class GalChatDesktopRefresh
{
    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(IntPtr hWnd, StringBuilder className, int maxCount);

    [DllImport("user32.dll")]
    private static extern bool RedrawWindow(IntPtr hWnd, IntPtr updateRect, IntPtr updateRegion, uint flags);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int command);

    [DllImport("user32.dll")]
    private static extern bool InvalidateRect(IntPtr hWnd, IntPtr rect, bool erase);

    [DllImport("user32.dll")]
    private static extern bool UpdateWindow(IntPtr hWnd);

    private const uint RedrawFlags = 0x0001 | 0x0004 | 0x0080 | 0x0100 | 0x0400;

    public static void Refresh(long desktopHost)
    {
        IntPtr host = new IntPtr(desktopHost);
        if (host != IntPtr.Zero)
        {
            ShowWindow(host, 0);
            InvalidateRect(host, IntPtr.Zero, true);
            RedrawWindow(host, IntPtr.Zero, IntPtr.Zero, RedrawFlags);
            UpdateWindow(host);
            ShowWindow(host, 8);
        }

        EnumWindows((hWnd, _) =>
        {
            StringBuilder className = new StringBuilder(256);
            GetClassName(hWnd, className, className.Capacity);
            string value = className.ToString();
            if (value == "Progman" || value == "WorkerW")
                RedrawWindow(hWnd, IntPtr.Zero, IntPtr.Zero, RedrawFlags);
            return true;
        }, IntPtr.Zero);
    }
}
"@

[GalChatDesktopRefresh]::Refresh($DesktopHost)
& "$env:WINDIR\System32\ie4uinit.exe" -show
$markerPath = Join-Path (Split-Path -Parent $LogPath) "desktop_wallpaper_host.txt"
Remove-Item -LiteralPath $markerPath -Force -ErrorAction SilentlyContinue
"$(Get-Date -Format o) refresh_completed game_pid=$GameProcessId host=$DesktopHost" | Add-Content -LiteralPath $LogPath
