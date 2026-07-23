using Godot;
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Collections.Generic;

namespace GalChat.Scripts.CSharp
{
    public partial class WindowDetector : Node
    {
        // P/Invoke 声明
    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr GetParent(IntPtr hWnd);

    [DllImport("dwmapi.dll")]
    private static extern int DwmGetWindowAttribute(IntPtr hWnd, int attribute, out int value, int valueSize);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr FindWindowEx(IntPtr parentHandle, IntPtr childAfter, string className, string windowTitle);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetParent(IntPtr childHandle, IntPtr newParentHandle);

    [DllImport("user32.dll")]
    private static extern IntPtr GetWindow(IntPtr hWnd, uint command);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint message, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr insertAfter, int x, int y, int width, int height, uint flags);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int command);

    [DllImport("user32.dll")]
    private static extern bool RedrawWindow(IntPtr hWnd, IntPtr updateRect, IntPtr updateRegion, uint flags);

    [DllImport("kernel32.dll")]
    private static extern void SetLastError(uint errorCode);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int index);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongW", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr32(IntPtr hWnd, int index);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int index, IntPtr newValue);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongW", SetLastError = true)]
    private static extern IntPtr SetWindowLongPtr32(IntPtr hWnd, int index, IntPtr newValue);

    // 定义委托
    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    private static int _currentGodotProcessId;
    private IntPtr _mainHwnd = IntPtr.Zero;
    private IntPtr _desktopOriginalParent = IntPtr.Zero;
    private IntPtr _desktopOriginalStyle = IntPtr.Zero;
    private IntPtr _desktopOriginalExStyle = IntPtr.Zero;
    private bool _desktopEmbedded;
    private bool _desktopParented;
    private IntPtr _desktopHost = IntPtr.Zero;
    private bool _desktopExitWatcherStarted;

    private const int GWL_STYLE = -16;
    private const long WS_CHILD = 0x40000000L;
    private const long WS_POPUP = unchecked((long)0x80000000L);
    private const long WS_EX_NOACTIVATE = 0x08000000L;
    private const long WS_EX_TOPMOST = 0x00000008L;
    private const uint WM_SPAWN_WORKER = 0x052C;
    private const uint SMTO_NORMAL = 0x0000;
    private const uint SWP_NOSIZE = 0x0001;
    private const uint SWP_NOMOVE = 0x0002;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const uint SWP_FRAMECHANGED = 0x0020;
    private const uint SWP_SHOWWINDOW = 0x0040;
    private const uint GW_HWNDPREV = 3;
    private const int SW_HIDE = 0;
    private const uint RDW_INVALIDATE = 0x0001;
    private const uint RDW_ERASE = 0x0004;
    private const uint RDW_ALLCHILDREN = 0x0080;
    private const uint RDW_UPDATENOW = 0x0100;
    private const uint RDW_FRAME = 0x0400;
    private static readonly IntPtr HWND_BOTTOM = new IntPtr(1);
    private const int DWMWA_CLOAKED = 14;

    public override void _EnterTree()
    {
        // 缓存当前 Godot 进程 ID 以便过滤
        _currentGodotProcessId = Process.GetCurrentProcess().Id;
    }

    public void SetMainHwnd(long hwnd)
    {
        _mainHwnd = new IntPtr(hwnd);
    }

    public bool IsMainWindowForeground()
    {
        return _mainHwnd != IntPtr.Zero && GetForegroundWindow() == _mainHwnd;
    }

    public bool KeepWindowBehindApplications(long hwnd)
    {
        if (!OperatingSystem.IsWindows() || hwnd == 0)
            return false;

        IntPtr windowHandle = new IntPtr(hwnd);
        long extendedStyle = GetWindowLongPointer(windowHandle, GWL_EXSTYLE).ToInt64();
        extendedStyle = (extendedStyle | WS_EX_NOACTIVATE) & ~WS_EX_TOPMOST;
        SetLastError(0);
        SetWindowLongPointer(windowHandle, GWL_EXSTYLE, new IntPtr(extendedStyle));
        if (Marshal.GetLastWin32Error() != 0)
            return false;

        return SetWindowPos(
            windowHandle,
            HWND_BOTTOM,
            0,
            0,
            0,
            0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED
        );
    }

    private static IntPtr GetWindowLongPointer(IntPtr hWnd, int index)
    {
        return IntPtr.Size == 8 ? GetWindowLongPtr64(hWnd, index) : GetWindowLongPtr32(hWnd, index);
    }

    private static IntPtr SetWindowLongPointer(IntPtr hWnd, int index, IntPtr value)
    {
        return IntPtr.Size == 8 ? SetWindowLongPtr64(hWnd, index, value) : SetWindowLongPtr32(hWnd, index, value);
    }

    private static string GetWindowClass(IntPtr hWnd)
    {
        StringBuilder className = new StringBuilder(256);
        GetClassName(hWnd, className, className.Capacity);
        return className.ToString();
    }

    private static string DescribeWindow(IntPtr hWnd)
    {
        if (hWnd == IntPtr.Zero)
            return "HWND=0";
        GetWindowRect(hWnd, out RECT rect);
        int cloaked = 0;
        DwmGetWindowAttribute(hWnd, DWMWA_CLOAKED, out cloaked, sizeof(int));
        return $"HWND=0x{hWnd.ToInt64():X} class={GetWindowClass(hWnd)} parent=0x{GetParent(hWnd).ToInt64():X} visible={IsWindowVisible(hWnd)} cloaked={cloaked} rect=({rect.Left},{rect.Top})-({rect.Right},{rect.Bottom}) style=0x{GetWindowLongPointer(hWnd, GWL_STYLE).ToInt64():X} ex=0x{GetWindowLongPointer(hWnd, GWL_EXSTYLE).ToInt64():X}";
    }

    private static void WriteDesktopDebugLog(IEnumerable<string> lines)
    {
        try
        {
            string path = ProjectSettings.GlobalizePath("user://desktop_mode_debug.log");
            File.AppendAllLines(path, lines);
            GD.Print($"[DesktopMode] Diagnostic log: {path}");
        }
        catch (Exception error)
        {
            GD.PrintErr($"[DesktopMode] Failed to write diagnostics: {error.Message}");
        }
    }

    public string GetDesktopModeDebugLogPath()
    {
        return ProjectSettings.GlobalizePath("user://desktop_mode_debug.log");
    }

    public void CaptureDesktopModeState(string stage)
    {
        (IntPtr desktopHost, IntPtr desktopIconView) = FindDesktopHostWindow();
        WriteDesktopDebugLog(new[]
        {
            $"--- {stage} {DateTime.Now:O} ---",
            $"main {DescribeWindow(_mainHwnd)}",
            $"host {DescribeWindow(desktopHost)}",
            $"icons {DescribeWindow(desktopIconView)}"
        });
    }

    private static bool RectContains(RECT container, int x, int y, int width, int height)
    {
        return x >= container.Left && y >= container.Top && x + width <= container.Right && y + height <= container.Bottom;
    }

    private static List<(IntPtr Host, IntPtr IconView)> GetDesktopHostCandidates()
    {
        List<(IntPtr Host, IntPtr IconView)> candidates = new List<(IntPtr Host, IntPtr IconView)>();
        EnumWindows((topWindow, _) =>
        {
            string className = GetWindowClass(topWindow);
            if (className != "Progman" && className != "WorkerW")
                return true;
            candidates.Add((topWindow, FindWindowEx(topWindow, IntPtr.Zero, "SHELLDLL_DefView", null)));
            return true;
        }, IntPtr.Zero);
        return candidates;
    }

    private static (IntPtr Host, IntPtr IconView) FindDesktopHostWindow(int screenX = int.MinValue, int screenY = int.MinValue, int width = 0, int height = 0)
    {
        IntPtr progman = FindWindow("Progman", null);
        if (progman == IntPtr.Zero)
            return (IntPtr.Zero, IntPtr.Zero);

        SendMessageTimeout(progman, WM_SPAWN_WORKER, new IntPtr(0xD), IntPtr.Zero, SMTO_NORMAL, 1000, out _);
        SendMessageTimeout(progman, WM_SPAWN_WORKER, new IntPtr(0xD), new IntPtr(1), SMTO_NORMAL, 1000, out _);

        IntPtr desktopHost = IntPtr.Zero;
        IntPtr desktopIconView = IntPtr.Zero;
        foreach ((IntPtr host, IntPtr iconView) in GetDesktopHostCandidates())
        {
            if (screenX != int.MinValue && (!GetWindowRect(host, out RECT hostRect) || !RectContains(hostRect, screenX, screenY, width, height)))
                continue;
            if (desktopHost == IntPtr.Zero || iconView != IntPtr.Zero)
            {
                desktopHost = host;
                desktopIconView = iconView;
            }
            if (iconView != IntPtr.Zero)
                break;
        }

        if (desktopHost == IntPtr.Zero && screenX == int.MinValue)
            return (progman, FindWindowEx(progman, IntPtr.Zero, "SHELLDLL_DefView", null));
        return (desktopHost, desktopIconView);
    }

    private static IntPtr FindWallpaperHostWindow(int screenX, int screenY, int width, int height, IntPtr iconHost)
    {
        foreach ((IntPtr host, IntPtr iconView) in GetDesktopHostCandidates())
        {
            if (host == iconHost || iconView != IntPtr.Zero || !IsWindowVisible(host))
                continue;
            if (GetWindowClass(host) != "WorkerW" || !GetWindowRect(host, out RECT hostRect))
                continue;
            if (RectContains(hostRect, screenX, screenY, width, height))
                return host;
        }
        return IntPtr.Zero;
    }

    public bool EmbedMainWindowInDesktop(int screenX, int screenY, int width, int height)
    {
        if (OS.GetName() != "Windows" || _mainHwnd == IntPtr.Zero)
            return false;
        if (_desktopEmbedded)
            return true;

        if (!GetWindowRect(_mainHwnd, out RECT mainRect))
            return false;
        int nativeScreenX = mainRect.Left;
        int nativeScreenY = mainRect.Top;

        (IntPtr iconHost, IntPtr desktopIconView) = FindDesktopHostWindow(nativeScreenX, nativeScreenY, width, height);
        IntPtr desktopHost = FindWallpaperHostWindow(nativeScreenX, nativeScreenY, width, height, iconHost);
        List<string> diagnostics = new List<string>
        {
            $"=== Desktop mode attempt {DateTime.Now:O} ===",
            $"godot_target=({screenX},{screenY}) native_target=({nativeScreenX},{nativeScreenY}) size=({width},{height})",
            $"main.before {DescribeWindow(_mainHwnd)}",
            $"wallpaper_host {DescribeWindow(desktopHost)}",
            $"icon_host {DescribeWindow(iconHost)}",
            $"icons {DescribeWindow(desktopIconView)}"
        };
        foreach ((IntPtr candidateHost, IntPtr candidateIcons) in GetDesktopHostCandidates())
            diagnostics.Add($"candidate host={DescribeWindow(candidateHost)} icons={DescribeWindow(candidateIcons)}");
        if (desktopHost == IntPtr.Zero || !GetWindowRect(desktopHost, out RECT hostRect))
        {
            diagnostics.Add("No safe wallpaper host contains the native target rectangle; refusing top-level fallback.");
            WriteDesktopDebugLog(diagnostics);
            return false;
        }

        _desktopOriginalStyle = GetWindowLongPointer(_mainHwnd, GWL_STYLE);
        _desktopOriginalExStyle = GetWindowLongPointer(_mainHwnd, GWL_EXSTYLE);
        SetLastError(0);
        _desktopOriginalParent = SetParent(_mainHwnd, desktopHost);
        if (_desktopOriginalParent == IntPtr.Zero && Marshal.GetLastWin32Error() != 0)
        {
            diagnostics.Add($"SetParent failed error={Marshal.GetLastWin32Error()}");
            WriteDesktopDebugLog(diagnostics);
            GD.PrintErr($"[DesktopMode] SetParent failed: {Marshal.GetLastWin32Error()}");
            return false;
        }
        long embeddedStyle = (_desktopOriginalStyle.ToInt64() & ~WS_POPUP) | WS_CHILD;
        long embeddedExStyle = _desktopOriginalExStyle.ToInt64() & ~WS_EX_TOPMOST;
        SetWindowLongPointer(_mainHwnd, GWL_STYLE, new IntPtr(embeddedStyle));
        SetWindowLongPointer(_mainHwnd, GWL_EXSTYLE, new IntPtr(embeddedExStyle));
        bool positioned = SetWindowPos(
            _mainHwnd,
            HWND_BOTTOM,
            nativeScreenX - hostRect.Left,
            nativeScreenY - hostRect.Top,
            width,
            height,
            SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW
        );
        if (!positioned)
        {
            diagnostics.Add($"SetWindowPos failed error={Marshal.GetLastWin32Error()}");
            WriteDesktopDebugLog(diagnostics);
            RestoreMainWindowFromDesktop();
            GD.PrintErr($"[DesktopMode] SetWindowPos failed: {Marshal.GetLastWin32Error()}");
            return false;
        }

        _desktopEmbedded = true;
        _desktopParented = true;
        _desktopHost = desktopHost;
        WriteDesktopHostMarker(desktopHost);
        EnsureDesktopExitWatcher(desktopHost);
        diagnostics.Add($"main.after {DescribeWindow(_mainHwnd)}");
        diagnostics.Add($"parent.after {DescribeWindow(GetParent(_mainHwnd))}");
        WriteDesktopDebugLog(diagnostics);
        return true;
    }

    private void EnsureDesktopExitWatcher(IntPtr desktopHost)
    {
        if (_desktopExitWatcherStarted)
            return;

        int processId = Process.GetCurrentProcess().Id;
        string watcherPath = ProjectSettings.GlobalizePath("res://tools/desktop_wallpaper_exit_watcher.ps1");
        string logPath = ProjectSettings.GlobalizePath("user://desktop_wallpaper_exit_watcher.log");
        try
        {
            ProcessStartInfo startInfo = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };
            startInfo.ArgumentList.Add("-NoProfile");
            startInfo.ArgumentList.Add("-NonInteractive");
            startInfo.ArgumentList.Add("-WindowStyle");
            startInfo.ArgumentList.Add("Hidden");
            startInfo.ArgumentList.Add("-ExecutionPolicy");
            startInfo.ArgumentList.Add("Bypass");
            startInfo.ArgumentList.Add("-File");
            startInfo.ArgumentList.Add(watcherPath);
            startInfo.ArgumentList.Add("-GameProcessId");
            startInfo.ArgumentList.Add(processId.ToString());
            startInfo.ArgumentList.Add("-DesktopHost");
            startInfo.ArgumentList.Add(desktopHost.ToInt64().ToString());
            startInfo.ArgumentList.Add("-LogPath");
            startInfo.ArgumentList.Add(logPath);
            Process.Start(startInfo);
            _desktopExitWatcherStarted = true;
        }
        catch (Exception error)
        {
            GD.PrintErr($"[DesktopMode] Failed to start exit watcher: {error.Message}");
        }
    }

    private static void WriteDesktopHostMarker(IntPtr desktopHost)
    {
        try
        {
            string markerPath = ProjectSettings.GlobalizePath("user://desktop_wallpaper_host.txt");
            File.WriteAllText(markerPath, desktopHost.ToInt64().ToString());
        }
        catch (Exception error)
        {
            GD.PrintErr($"[DesktopMode] Failed to write desktop host marker: {error.Message}");
        }
    }

    private static void ClearDesktopHostMarker()
    {
        try
        {
            string markerPath = ProjectSettings.GlobalizePath("user://desktop_wallpaper_host.txt");
            if (File.Exists(markerPath))
                File.Delete(markerPath);
        }
        catch (Exception error)
        {
            GD.PrintErr($"[DesktopMode] Failed to clear desktop host marker: {error.Message}");
        }
    }

    public void RestoreMainWindowFromDesktop()
    {
        if (_mainHwnd == IntPtr.Zero || (!_desktopEmbedded && _desktopOriginalStyle == IntPtr.Zero))
            return;
        if (_desktopParented)
            SetParent(_mainHwnd, _desktopOriginalParent);
        SetWindowLongPointer(_mainHwnd, GWL_STYLE, _desktopOriginalStyle);
        SetWindowLongPointer(_mainHwnd, GWL_EXSTYLE, _desktopOriginalExStyle);
        SetWindowPos(_mainHwnd, IntPtr.Zero, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
        _desktopEmbedded = false;
        _desktopParented = false;
        RedrawDesktopHosts(_desktopHost);
        _desktopHost = IntPtr.Zero;
        _desktopOriginalParent = IntPtr.Zero;
        _desktopOriginalStyle = IntPtr.Zero;
        _desktopOriginalExStyle = IntPtr.Zero;
        ClearDesktopHostMarker();
    }

    public void PrepareDesktopWindowForProcessExit()
    {
        PrepareDesktopWindowForProcessExit("main_scene_shutdown");
    }

    private void PrepareDesktopWindowForProcessExit(string source)
    {
        if (_mainHwnd == IntPtr.Zero)
            return;
        IntPtr hostToRedraw = _desktopHost;
        List<string> diagnostics = new List<string>
        {
            $"=== Desktop mode process exit {DateTime.Now:O} ===",
            $"source={source}",
            $"main.before_exit {DescribeWindow(_mainHwnd)}",
            $"host.before_exit {DescribeWindow(hostToRedraw)}"
        };
        ShowWindow(_mainHwnd, SW_HIDE);
        if (_desktopParented)
            SetParent(_mainHwnd, _desktopOriginalParent);
        _desktopEmbedded = false;
        _desktopParented = false;
        _desktopHost = IntPtr.Zero;
        RedrawDesktopHosts(hostToRedraw);
        diagnostics.Add($"main.after_exit_detach {DescribeWindow(_mainHwnd)}");
        diagnostics.Add("Explorer desktop hosts redrawn.");
        WriteDesktopDebugLog(diagnostics);
    }

    private static void RedrawDesktopHosts(IntPtr desktopHost)
    {
        const uint redrawFlags = RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_UPDATENOW | RDW_FRAME;
        if (desktopHost != IntPtr.Zero)
            RedrawWindow(desktopHost, IntPtr.Zero, IntPtr.Zero, redrawFlags);
        IntPtr progman = FindWindow("Progman", null);
        if (progman != IntPtr.Zero)
            RedrawWindow(progman, IntPtr.Zero, IntPtr.Zero, redrawFlags);
        (IntPtr iconHost, _) = FindDesktopHostWindow();
        if (iconHost != IntPtr.Zero && iconHost != desktopHost)
            RedrawWindow(iconHost, IntPtr.Zero, IntPtr.Zero, redrawFlags);
    }

    public override void _ExitTree()
    {
        if (_desktopEmbedded || _desktopParented)
            PrepareDesktopWindowForProcessExit("window_detector_exit_tree");
    }

    /// <summary>
    /// 获取系统的空闲时间（毫秒），即用户最后一次鼠标或键盘输入距今的时间
    /// </summary>
    /// <returns>空闲毫秒数</returns>
    public uint GetIdleTimeMs()
    {
        LASTINPUTINFO lastInputInfo = new LASTINPUTINFO();
        lastInputInfo.cbSize = (uint)Marshal.SizeOf(lastInputInfo);
        lastInputInfo.dwTime = 0;

        if (GetLastInputInfo(ref lastInputInfo))
        {
            uint envTicks = (uint)System.Environment.TickCount;
            if (envTicks >= lastInputInfo.dwTime)
                return envTicks - lastInputInfo.dwTime;
            else
                return 0;
        }
        return 0;
    }

    /// <summary>
    /// 调整 Bitmap 的尺寸，等比例缩放到指定的最大宽/高
    /// </summary>
    private System.Drawing.Bitmap ResizeBitmap(System.Drawing.Bitmap original, int maxWidth, int maxHeight)
    {
        if (original.Width <= maxWidth && original.Height <= maxHeight)
        {
            return new System.Drawing.Bitmap(original); // 返回副本避免原图被销毁影响
        }

        float ratioX = (float)maxWidth / original.Width;
        float ratioY = (float)maxHeight / original.Height;
        float ratio = Math.Min(ratioX, ratioY);

        int newWidth = (int)(original.Width * ratio);
        int newHeight = (int)(original.Height * ratio);

        System.Drawing.Bitmap newImage = new System.Drawing.Bitmap(newWidth, newHeight, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(newImage))
        {
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            g.DrawImage(original, 0, 0, newWidth, newHeight);
        }
        return newImage;
    }

    /// <summary>
    /// 截取全屏并返回 Base64 编码的 JPEG 字符串（压缩质量为 60）
    /// 适用于发送给多模态大模型进行屏幕内容分析
    /// </summary>
    /// <returns>Base64 Image String</returns>
    public string CaptureScreenToBase64()
    {
        try
        {
            int screenLeft = 0;
            int screenTop = 0;
            int screenWidth = 0;
            int screenHeight = 0;

            // 计算所有显示器的总边界
            int screenCount = Godot.DisplayServer.GetScreenCount();
            for (int i = 0; i < screenCount; i++)
            {
                var pos = Godot.DisplayServer.ScreenGetPosition(i);
                var size = Godot.DisplayServer.ScreenGetSize(i);
                screenLeft = Math.Min(screenLeft, pos.X);
                screenTop = Math.Min(screenTop, pos.Y);
                screenWidth = Math.Max(screenWidth, pos.X + size.X - screenLeft);
                screenHeight = Math.Max(screenHeight, pos.Y + size.Y - screenTop);
            }

            using (System.Drawing.Bitmap bitmap = new System.Drawing.Bitmap(screenWidth, screenHeight, PixelFormat.Format32bppArgb))
            {
                using (Graphics g = Graphics.FromImage(bitmap))
                {
                    g.CopyFromScreen(screenLeft, screenTop, 0, 0, new Size(screenWidth, screenHeight), CopyPixelOperation.SourceCopy);
                }

                // 压缩图像分辨率以减少 Token 消耗并提升响应速度，限制最大尺寸为 1280x720
                using (System.Drawing.Bitmap resizedBitmap = ResizeBitmap(bitmap, 1280, 720))
                {
                    // 使用 JPEG 格式并压缩质量，减少 API 传输体积
                    ImageCodecInfo jpgEncoder = GetEncoder(ImageFormat.Jpeg);
                    System.Drawing.Imaging.Encoder myEncoder = System.Drawing.Imaging.Encoder.Quality;
                    EncoderParameters myEncoderParameters = new EncoderParameters(1);
                    EncoderParameter myEncoderParameter = new EncoderParameter(myEncoder, 60L); // 60% 质量
                    myEncoderParameters.Param[0] = myEncoderParameter;

                    using (MemoryStream ms = new MemoryStream())
                    {
                        resizedBitmap.Save(ms, jpgEncoder, myEncoderParameters);
                        byte[] imageBytes = ms.ToArray();
                        return Convert.ToBase64String(imageBytes);
                    }
                }
            }
        }
        catch (Exception ex)
        {
            GD.PrintErr($"截图失败: {ex.Message}");
            return string.Empty;
        }
    }

    private ImageCodecInfo GetEncoder(ImageFormat format)
    {
        ImageCodecInfo[] codecs = ImageCodecInfo.GetImageDecoders();
        foreach (ImageCodecInfo codec in codecs)
        {
            if (codec.FormatID == format.Guid)
            {
                return codec;
            }
        }
        return null;
    }

    /// <summary>
    /// 获取当前最顶层有效的外部应用程序窗口句柄
    /// </summary>
    /// <returns>窗口句柄，未找到则返回 IntPtr.Zero</returns>
    private IntPtr GetCurrentExternalWindowHandle()
    {
        IntPtr foundHwnd = IntPtr.Zero;

        EnumWindows((hWnd, lParam) =>
        {
            if (IsValidExternalWindow(hWnd))
            {
                foundHwnd = hWnd;
                return false;
            }
            return true;
        }, IntPtr.Zero);

        return foundHwnd;
    }

    /// <summary>
    /// 获取当前最顶层有效的外部应用程序窗口标题
    /// </summary>
    /// <returns>窗口标题，未找到则返回空字符串</returns>
    public string GetCurrentWindowTitle()
    {
        IntPtr hWnd = GetCurrentExternalWindowHandle();
        if (hWnd == IntPtr.Zero)
            return string.Empty;

        StringBuilder sb = new StringBuilder(256);
        GetWindowText(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }

    /// <summary>
    /// 获取当前最顶层有效的外部应用程序进程名
    /// </summary>
    /// <returns>进程名，未找到则返回空字符串</returns>
    public string GetCurrentProcessName()
    {
        IntPtr hWnd = GetCurrentExternalWindowHandle();
        if (hWnd == IntPtr.Zero)
            return string.Empty;

        GetWindowThreadProcessId(hWnd, out uint processId);
        try
        {
            Process proc = Process.GetProcessById((int)processId);
            return proc.ProcessName;
        }
        catch (Exception e)
        {
            GD.PrintErr($"获取进程信息失败: {e.Message}");
            return string.Empty;
        }
    }

    // 过滤掉特定尺寸过小的无效窗口，如托盘、浮窗等
    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern IntPtr GetDesktopWindow();

    [DllImport("user32.dll")]
    private static extern IntPtr GetShellWindow();

    [DllImport("user32.dll")]
    private static extern bool IsZoomed(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    private static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll")]
    private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    [StructLayout(LayoutKind.Sequential)]
    private struct LASTINPUTINFO
    {
        public uint cbSize;
        public uint dwTime;
    }

    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_TRANSPARENT = 0x00000020;
    private const int WS_EX_LAYERED = 0x00080000;
    private const int WS_EX_TOOLWINDOW = 0x00000080;

    /// <summary>
    /// 截取当前前台焦点窗口并返回 Base64 编码的 JPEG 字符串
    /// </summary>
    /// <returns>Base64 Image String</returns>
    public string CaptureForegroundWindowToBase64()
    {
        try
        {
            IntPtr hWnd = GetCurrentExternalWindowHandle();
            if (hWnd == IntPtr.Zero || hWnd == GetDesktopWindow() || hWnd == GetShellWindow())
            {
                return string.Empty;
            }

            GetWindowThreadProcessId(hWnd, out uint processId);
            if (_currentGodotProcessId == 0)
                _currentGodotProcessId = Process.GetCurrentProcess().Id;

            if (processId == 0 || processId == _currentGodotProcessId)
            {
                return string.Empty;
            }

            if (GetWindowRect(hWnd, out RECT rect))
            {
                int width = rect.Right - rect.Left;
                int height = rect.Bottom - rect.Top;

                if (width <= 0 || height <= 0) return string.Empty;

                using (System.Drawing.Bitmap bitmap = new System.Drawing.Bitmap(width, height, PixelFormat.Format32bppArgb))
                {
                    using (Graphics g = Graphics.FromImage(bitmap))
                    {
                        g.CopyFromScreen(rect.Left, rect.Top, 0, 0, new Size(width, height), CopyPixelOperation.SourceCopy);
                    }

                    // 压缩图像分辨率以减少 Token 消耗并提升响应速度，限制最大尺寸为 1280x720
                    using (System.Drawing.Bitmap resizedBitmap = ResizeBitmap(bitmap, 1280, 720))
                    {
                        ImageCodecInfo jpgEncoder = GetEncoder(ImageFormat.Jpeg);
                        System.Drawing.Imaging.Encoder myEncoder = System.Drawing.Imaging.Encoder.Quality;
                        EncoderParameters myEncoderParameters = new EncoderParameters(1);
                        EncoderParameter myEncoderParameter = new EncoderParameter(myEncoder, 60L);
                        myEncoderParameters.Param[0] = myEncoderParameter;

                        using (MemoryStream ms = new MemoryStream())
                        {
                            resizedBitmap.Save(ms, jpgEncoder, myEncoderParameters);
                            byte[] imageBytes = ms.ToArray();
                            return Convert.ToBase64String(imageBytes);
                        }
                    }
                }
            }
            return string.Empty;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"前台窗口截图失败: {ex.Message}");
            return string.Empty;
        }
    }

    /// <summary>
    /// 判断当前拥有焦点的窗口是否是全屏，如果不是，它会继续向下枚举找到最近的一个可见的全屏窗口。
    /// 只要有任何全屏窗口（非Godot）处于可见的最上层或焦点层，就会返回 true。
    /// </summary>
    public bool IsAnyFullScreenWindowCovering()
    {
        if (_mainHwnd == IntPtr.Zero) return false;

        bool isCovered = false;

        EnumWindows((hWnd, lParam) =>
        {
            if (isCovered) return false; // 已经找到全屏窗口，停止枚举

            // 精准匹配主窗口句柄
            if (hWnd == _mainHwnd)
            {
                if (!IsWindowVisible(hWnd)) return true; // 不可见的子窗口跳过（理论上主窗口不会走到这）
                return false; 
            }

            // 获取进程 ID 过滤自己（例如桌宠窗口），不让桌宠成为遮挡源
            GetWindowThreadProcessId(hWnd, out uint processId);
            if (_currentGodotProcessId == 0)
                _currentGodotProcessId = Process.GetCurrentProcess().Id;
                
            if (processId == _currentGodotProcessId)
            {
                // 跳过桌宠等内部窗口，继续寻找外部全屏窗口
                return true; 
            }

            // 既然不是 Godot 自己的窗口，那就判断它是不是有效的遮挡层
            if (!IsValidExternalWindow(hWnd)) return true;

            StringBuilder sb = new StringBuilder(256);
            GetWindowText(hWnd, sb, sb.Capacity);
            string winTitle = sb.ToString();

            // 获取窗口状态和大小
            if (IsZoomed(hWnd))
            {
                isCovered = true;
                return false;
            }

            if (GetWindowRect(hWnd, out RECT rect))
            {
                int width = rect.Right - rect.Left;
                int height = rect.Bottom - rect.Top;

                var currentScreen = Godot.DisplayServer.WindowGetCurrentScreen();
                var screenSize = Godot.DisplayServer.ScreenGetSize(currentScreen);
                
                if (width >= screenSize.X - 10 && height >= screenSize.Y - 10)
                {
                    isCovered = true;
                    return false;
                }
            }

            return true;
        }, IntPtr.Zero);

        return isCovered;
    }

    /// <summary>
    /// 判断当前处于前台（拥有焦点）的窗口是否是全屏窗口（且不是 Godot 自己）
    /// </summary>
    public bool IsForegroundWindowFullScreen()
    {
        IntPtr hWnd = GetForegroundWindow();
        if (hWnd == IntPtr.Zero) return false;
        if (hWnd == GetDesktopWindow() || hWnd == GetShellWindow()) return false;

        GetWindowThreadProcessId(hWnd, out uint processId);
        if (_currentGodotProcessId == 0)
            _currentGodotProcessId = Process.GetCurrentProcess().Id;
            
        if (processId == _currentGodotProcessId) return false;

        // 如果是最大化状态，直接判定为全屏覆盖
        if (IsZoomed(hWnd)) return true;

        if (GetWindowRect(hWnd, out RECT rect))
        {
            int width = rect.Right - rect.Left;
            int height = rect.Bottom - rect.Top;

            var currentScreen = Godot.DisplayServer.WindowGetCurrentScreen();
            var screenSize = Godot.DisplayServer.ScreenGetSize(currentScreen);
            
            // 考虑边框或轻微缩放差异，设置 10 像素容差
            if (width >= screenSize.X - 10 && height >= screenSize.Y - 10)
            {
                return true;
            }
        }
        return false;
    }

    /// <summary>
    /// 判断是否为有效的外部窗口（过滤 Godot 自身、隐藏窗口和系统级窗口）
    /// </summary>
    private bool IsValidExternalWindow(IntPtr hWnd)
    {
        // 1. 必须是可见窗口
        if (!IsWindowVisible(hWnd))
            return false;

        // 2. 获取窗口标题并过滤空标题
        StringBuilder sb = new StringBuilder(256);
        GetWindowText(hWnd, sb, sb.Capacity);
        string title = sb.ToString();

        if (string.IsNullOrWhiteSpace(title))
            return false;

        // 3. 获取进程 ID
        GetWindowThreadProcessId(hWnd, out uint processId);

        // 4. 过滤 Godot 自身进程及无效 PID
        if (_currentGodotProcessId == 0)
            _currentGodotProcessId = Process.GetCurrentProcess().Id;
            
        if (processId == _currentGodotProcessId || processId == 0)
            return false;

        // 5. 过滤常见的系统级进程名
        // 不再通过 GetProcessById 获取进程名，因为它非常耗时且容易抛出权限异常（Access Denied），
        // 这会导致枚举过程极度缓慢甚至卡死。对于检测全屏应用，这通常是不必要的。

        // 6. 过滤常见的系统级窗口标题和隐藏覆盖层
        string titleLower = title.ToLower();
        if (title == "Program Manager" || 
            title == "Settings" || 
            title == "Windows Input Experience" || 
            title == "Task Switching" || 
            titleLower.Contains("nvidia geforce") ||
            titleLower.Contains("overlay") ||
            title == "Microsoft Text Input Application" ||
            title == "Xbox Game Bar" ||
            title == "Steam Overlay")
        {
            return false;
        }

        // 7. 过滤特定的窗口样式（扩展样式）
        // 很多像 NVIDIA Overlay 这样的覆盖层，虽然尺寸是全屏的，但它们是透明的且不拦截鼠标。
        // 这些覆盖层通常会带有一个特定的窗口扩展样式：WS_EX_TRANSPARENT (0x00000020) 或 WS_EX_TOOLWINDOW (0x00000080)
        // 表示这个窗口在鼠标点击时是穿透的，或者是作为一个不可见的工具窗口存在，不应被视为阻挡用户的正常交互窗口。
        int exStyle = GetWindowLong(hWnd, GWL_EXSTYLE);
        if ((exStyle & WS_EX_TRANSPARENT) == WS_EX_TRANSPARENT || (exStyle & WS_EX_TOOLWINDOW) == WS_EX_TOOLWINDOW)
        {
            return false; // 这是一个点击穿透的透明层或工具窗，不应该视为遮挡
        }
        
        // 8. 过滤特定的窗口类名
        // 有些系统级别的透明覆盖层可能会使用特定的类名，例如 NVIDIA 的某些组件
        StringBuilder classNameSb = new StringBuilder(256);
        GetClassName(hWnd, classNameSb, classNameSb.Capacity);
        string className = classNameSb.ToString();
        if (className.Contains("CEF-OSC-WIDGET") || className == "WorkerW" || className.Contains("Overlay"))
        {
            return false;
        }

        // 9. 过滤过小的托盘窗口和组件
        if (GetWindowRect(hWnd, out RECT rect))
        {
            int width = rect.Right - rect.Left;
            int height = rect.Bottom - rect.Top;
            if (width < 100 || height < 100)
            {
                return false;
            }
        }

        return true;
    }
}
}
