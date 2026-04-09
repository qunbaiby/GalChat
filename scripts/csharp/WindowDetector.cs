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

    public override void _EnterTree()
    {
        // 缓存当前 Godot 进程 ID 以便过滤
        _currentGodotProcessId = Process.GetCurrentProcess().Id;
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
        try
        {
            Process proc = Process.GetProcessById((int)processId);
            string processName = proc.ProcessName.ToLower();

            if (processName == "explorer" || processName == "dwm" || processName == "searchapp" || processName == "textinputhost" || processName == "applicationframehost" || processName == "startmenuexperiencehost" || processName == "systemsettings")
                return false;
        }
        catch
        {
            // 获取进程失败则认为无效
            return false;
        }

        // 6. 过滤常见的系统级窗口标题
        if (title == "Program Manager" || title == "Settings" || title == "Windows Input Experience" || title == "Task Switching")
            return false;

        // 7. 过滤过小的托盘窗口和组件
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
