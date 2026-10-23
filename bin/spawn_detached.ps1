# Detached process spawner (Windows).
# Spawns a console app with DETACHED_PROCESS + CREATE_NEW_PROCESS_GROUP,
# so it owns no console and inherits no pipe handles.
# It therefore survives the exit of the launcher (双击 bat 的窗口关闭后仍在运行).
# NOTE: this file is intentionally ASCII-only, so it needs no UTF-8 BOM.

if (-not ('DetachedSpawn' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class DetachedSpawn
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct STARTUPINFO {
        public int cb;
        [MarshalAs(UnmanagedType.LPWStr)] public string lpReserved;
        [MarshalAs(UnmanagedType.LPWStr)] public string lpDesktop;
        [MarshalAs(UnmanagedType.LPWStr)] public string lpTitle;
        public int dwX; public int dwY; public int dwXSize; public int dwYSize;
        public int dwXCountChars; public int dwYCountChars; public int dwFillAttribute; public int dwFlags;
        public short wShowWindow; public short cbReserved2;
        public IntPtr lpReserved2; public IntPtr hStdInput; public IntPtr hStdOutput; public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess; public IntPtr hThread; public int dwProcessId;
    }

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CreateProcessW(string appName, StringBuilder cmdLine,
        IntPtr procAttr, IntPtr threadAttr, bool inheritHandles, uint flags,
        IntPtr env, string curDir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr h);

    const uint DETACHED_PROCESS          = 0x00000008;
    const uint CREATE_NEW_PROCESS_GROUP  = 0x00000200;
    const uint CREATE_BREAKAWAY_FROM_JOB = 0x01000000;
    const uint CREATE_NO_WINDOW          = 0x08000000;

    public static int Spawn(string exe, string args, string cwd)
    {
        return Spawn(exe, args, cwd, false);
    }

    // noWindow: use CREATE_NO_WINDOW instead of DETACHED_PROCESS.
    // Managed runtimes (powershell.exe) abort immediately under DETACHED_PROCESS
    // because they lose their console host; CREATE_NO_WINDOW keeps the process
    // alive without a visible window.
    public static int Spawn(string exe, string args, string cwd, bool noWindow)
    {
        STARTUPINFO si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
        PROCESS_INFORMATION pi;
        StringBuilder cmd = new StringBuilder();
        cmd.Append('"').Append(exe).Append('"');
        if (!string.IsNullOrEmpty(args)) { cmd.Append(' ').Append(args); }

        uint baseFlags = CREATE_NEW_PROCESS_GROUP;
        baseFlags |= noWindow ? CREATE_NO_WINDOW : DETACHED_PROCESS;
        bool ok = TryCreate(cmd.ToString(), cwd, si, out pi, baseFlags | CREATE_BREAKAWAY_FROM_JOB);
        if (!ok) { ok = TryCreate(cmd.ToString(), cwd, si, out pi, baseFlags); }
        if (!ok) { throw new Exception("CreateProcessW failed, win32=" + Marshal.GetLastWin32Error()); }
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        return pi.dwProcessId;
    }

    static bool TryCreate(string cmd, string cwd, STARTUPINFO si, out PROCESS_INFORMATION pi, uint flags)
    {
        STARTUPINFO s = si;
        s.cb = Marshal.SizeOf(typeof(STARTUPINFO));
        pi = new PROCESS_INFORMATION();
        return CreateProcessW(null, new StringBuilder(cmd), IntPtr.Zero, IntPtr.Zero, false, flags,
            IntPtr.Zero, cwd, ref s, out pi);
    }
}
'@
}

function Start-DetachedProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string]$ArgumentList = '',
        [string]$WorkingDirectory = '',
        [switch]$NoWindow
    )
    $exe = (Resolve-Path -LiteralPath $FilePath -ErrorAction Stop).Path
    $cwd = $WorkingDirectory
    if (-not $cwd -or -not (Test-Path -LiteralPath $cwd)) { $cwd = Split-Path -Parent $exe }
    return [DetachedSpawn]::Spawn($exe, $ArgumentList, $cwd, [bool]$NoWindow)
}
