Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$source = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Drawing;

public class AlwaysOnTopApp : Form
{
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int X, int Y, int cx, int cy,
        uint uFlags);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex);

    private static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    private static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);

    private const int WM_HOTKEY = 0x0312;
    private const int HOTKEY_ID = 9001;

    private const uint MOD_CONTROL = 0x0002;
    private const uint MOD_WIN = 0x0008;
    private const uint MOD_NOREPEAT = 0x4000;
    private const uint VK_X = 0x58;

    private const uint SWP_NOSIZE = 0x0001;
    private const uint SWP_NOMOVE = 0x0002;
    private const uint SWP_NOACTIVATE = 0x0010;

    private const int GWL_EXSTYLE = -20;
    private const long WS_EX_TOPMOST = 0x00000008L;

    private NotifyIcon tray;

    public AlwaysOnTopApp()
    {
        ShowInTaskbar = false;
        FormBorderStyle = FormBorderStyle.FixedToolWindow;
        WindowState = FormWindowState.Minimized;
        Opacity = 0;
        Width = 1;
        Height = 1;

        tray = new NotifyIcon();
        tray.Icon = SystemIcons.Information;
        tray.Text = "Always On Top - Win+Ctrl+X";
        tray.Visible = true;

        var menu = new ContextMenuStrip();
        var exitItem = new ToolStripMenuItem("Quitter");
        exitItem.Click += (s, e) => Application.Exit();
        menu.Items.Add(exitItem);
        tray.ContextMenuStrip = menu;
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);

        bool ok = RegisterHotKey(
            this.Handle,
            HOTKEY_ID,
            MOD_CONTROL | MOD_WIN | MOD_NOREPEAT,
            VK_X
        );

        if (!ok)
        {
            MessageBox.Show(
                "Impossible d'activer Win + Ctrl + X.\nLe raccourci est peut-être déjà utilisé par Windows ou un autre logiciel.",
                "Always On Top",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );
            BeginInvoke(new Action(() => Application.Exit()));
            return;
        }

        tray.BalloonTipTitle = "Always On Top actif";
        tray.BalloonTipText = "Win + Ctrl + X : épingler / désépingler la fenêtre active.";
        tray.ShowBalloonTip(1800);
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_HOTKEY && m.WParam.ToInt32() == HOTKEY_ID)
        {
            IntPtr hwnd = GetForegroundWindow();

            if (hwnd != IntPtr.Zero && hwnd != this.Handle)
            {
                long exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE).ToInt64();
                bool isTopMost = (exStyle & WS_EX_TOPMOST) != 0;

                SetWindowPos(
                    hwnd,
                    isTopMost ? HWND_NOTOPMOST : HWND_TOPMOST,
                    0, 0, 0, 0,
                    SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
                );

                tray.BalloonTipTitle = isTopMost ? "Toujours au-dessus désactivé" : "Toujours au-dessus activé";
                tray.BalloonTipText = isTopMost
                    ? "La fenêtre est revenue à son comportement normal."
                    : "La fenêtre restera au-dessus des autres.";
                tray.ShowBalloonTip(900);
            }
        }

        base.WndProc(ref m);
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        try { UnregisterHotKey(this.Handle, HOTKEY_ID); } catch {}
        if (tray != null)
        {
            tray.Visible = false;
            tray.Dispose();
        }
        base.OnFormClosed(e);
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies System.Windows.Forms,System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run((New-Object AlwaysOnTopApp))
