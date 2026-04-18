using Godot;
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

public partial class WindowDetector : Node
{
    // P/Invoke 声明
    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    // 定义委托
    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    private static int _currentGodotProcessId;
    private IntPtr _mainHwnd = IntPtr.Zero;

    public override void _EnterTree()
    {
        // 缓存当前 Godot 进程 ID 以便过滤
        _currentGodotProcessId = Process.GetCurrentProcess().Id;
    }

    public void SetMainHwnd(long hwnd)
    {
        _mainHwnd = new IntPtr(hwnd);
    }

    /// <summary>
    /// 获取当前最顶层有效的外部应用程序窗口标题
    /// </summary>
    /// <returns>窗口标题，未找到则返回空字符串</returns>
    public string GetCurrentWindowTitle()
    {
        string windowTitle = string.Empty;
        bool found = false;

        EnumWindows((hWnd, lParam) =>
        {
            if (!found && IsValidExternalWindow(hWnd))
            {
                StringBuilder sb = new StringBuilder(256);
                GetWindowText(hWnd, sb, sb.Capacity);
                windowTitle = sb.ToString();
                found = true;
                // 找到最顶层有效窗口后停止枚举
                return false;
            }
            return true;
        }, IntPtr.Zero);

        return windowTitle;
    }

    /// <summary>
    /// 获取当前最顶层有效的外部应用程序进程名
    /// </summary>
    /// <returns>进程名，未找到则返回空字符串</returns>
    public string GetCurrentProcessName()
    {
        string processName = string.Empty;
        bool found = false;

        EnumWindows((hWnd, lParam) =>
        {
            if (!found && IsValidExternalWindow(hWnd))
            {
                GetWindowThreadProcessId(hWnd, out uint processId);
                try
                {
                    Process proc = Process.GetProcessById((int)processId);
                    processName = proc.ProcessName;
                    found = true;
                }
                catch (Exception e)
                {
                    GD.PrintErr($"获取进程信息失败: {e.Message}");
                }
                
                // 找到最顶层有效窗口后停止枚举
                return false;
            }
            return true;
        }, IntPtr.Zero);

        return processName;
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

    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_TRANSPARENT = 0x00000020;
    private const int WS_EX_LAYERED = 0x00080000;
    private const int WS_EX_TOOLWINDOW = 0x00000080;

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
