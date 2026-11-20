using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

internal sealed class CrestBaker : Form
{
    private readonly TextBox export = new TextBox();
    private readonly Button bake = new Button();
    private readonly Label status = new Label();
    private bool baking;

    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new CrestBaker());
    }

    internal CrestBaker()
    {
        Text = "Epicast Crest Baker";
        StartPosition = FormStartPosition.CenterScreen;
        AutoScaleMode = AutoScaleMode.Font;
        Font = SystemFonts.MessageBoxFont;
        ClientSize = new Size(720, 450);
        MinimumSize = new Size(450, 300);

        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(16), RowCount = 3, ColumnCount = 1 };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        Controls.Add(layout);

        layout.Controls.Add(new Label {
            Text = "Paste the export from Epicast’s Copy crest bake window.",
            AutoSize = true, Margin = new Padding(0, 0, 0, 10)
        }, 0, 0);

        export.Multiline = true;
        export.AcceptsReturn = true;
        export.ScrollBars = ScrollBars.Vertical;
        export.MaxLength = 262144;
        export.Font = new Font("Consolas", 10);
        export.Dock = DockStyle.Fill;
        export.Margin = new Padding(0);
        export.AccessibleName = "Crest bake export";
        export.TextChanged += delegate { RefreshButton(); };
        layout.Controls.Add(export, 0, 1);

        var footer = new TableLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, ColumnCount = 2, Margin = new Padding(0, 12, 0, 0) };
        footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        footer.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        layout.Controls.Add(footer, 0, 2);

        status.Text = "Bake updates the project and installed WoW Forever crest bakes.";
        status.Dock = DockStyle.Fill;
        status.TextAlign = ContentAlignment.MiddleLeft;
        status.Margin = new Padding(0, 0, 12, 0);
        status.AutoEllipsis = true;
        footer.Controls.Add(status, 0, 0);

        bake.Text = "Bake";
        bake.AutoSize = true;
        bake.MinimumSize = new Size(96, 34);
        bake.Margin = new Padding(0);
        bake.Click += BakeClicked;
        footer.Controls.Add(bake, 1, 0);
        FormClosing += delegate(object sender, FormClosingEventArgs e) { if (baking) e.Cancel = true; };
        RefreshButton();
        ActiveControl = export;
    }

    private void RefreshButton()
    {
        bake.Enabled = !baking && !String.IsNullOrWhiteSpace(export.Text);
    }

    private async void BakeClicked(object sender, EventArgs args)
    {
        string json = export.Text;
        baking = true;
        export.ReadOnly = true;
        RefreshButton();
        status.ForeColor = SystemColors.ControlText;
        status.Text = "Validating and baking…";
        try
        {
            var info = await Task.Run(() => {
                string root = FindProject();
                string result = BakeExport(root, json);
                try { InstallBake(root, @"D:\World of Warcraft\_forever_\Interface\AddOns\Epicast"); }
                catch (Exception error) {
                    throw new InvalidOperationException(result + " Project updated. Installation failed. " + error.Message);
                }
                return result + " Installed. Use /reload in WoW.";
            });
            status.Text = info;
        }
        catch (Exception error)
        {
            status.ForeColor = Color.Firebrick;
            status.Text = "Bake failed. " + error.Message;
            MessageBox.Show(this, error.Message, "Bake failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            baking = false;
            export.ReadOnly = false;
            RefreshButton();
        }
    }

    private static void CheckRegularPath(string path)
    {
        for (string current = Path.GetFullPath(path); current != null; current = Path.GetDirectoryName(current))
        {
            if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0)
                throw new IOException("An unexpected link was found at " + current);
        }
    }

    private static string FileHash(string path)
    {
        using (var sha = SHA256.Create())
        using (var stream = File.OpenRead(path))
            return BitConverter.ToString(sha.ComputeHash(stream));
    }

    internal static void InstallBake(string root, string installedDirectory)
    {
        string target = Path.Combine(installedDirectory, "CrestBakes.lua");
        string source = Path.Combine(root, "CrestBakes.lua");
        string toc = Path.Combine(installedDirectory, "Epicast.toc");
        CheckRegularPath(target);
        CheckRegularPath(toc);
        if (!Array.Exists(File.ReadAllLines(toc), line => line.Trim() == "CrestBakes.lua"))
            throw new IOException("The installed Epicast build does not load CrestBakes.lua.");

        string expected = FileHash(source);
        string original = FileHash(target);
        if (expected == original) return;
        string backupDirectory = Path.Combine(root, "artifacts", "crest-baker", "backups",
            DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(backupDirectory);
        string backup = Path.Combine(backupDirectory, "CrestBakes.lua");
        File.Copy(target, backup);
        if (FileHash(backup) != original) throw new IOException("Installed bake backup verification failed.");

        string staged = Path.Combine(installedDirectory, ".crest-bake-" + Guid.NewGuid().ToString("N") + ".tmp");
        bool replaced = false;
        try
        {
            File.Copy(source, staged);
            if (FileHash(staged) != expected || FileHash(target) != original)
                throw new IOException("A bake file changed during installation. Try Bake again.");
            File.Replace(staged, target, null);
            replaced = true;
            if (FileHash(target) != expected) throw new IOException("Installed bake verification failed.");
        }
        catch
        {
            if (replaced)
            {
                File.Copy(backup, staged, true);
                File.Replace(staged, target, null);
                if (FileHash(target) != original)
                    throw new IOException("Restore failed. The previous bake is at " + backup);
            }
            throw;
        }
        finally
        {
            if (File.Exists(staged)) File.Delete(staged);
        }
    }

    private static string FindProject()
    {
        for (var directory = new DirectoryInfo(AppDomain.CurrentDomain.BaseDirectory); directory != null; directory = directory.Parent)
        {
            if (File.Exists(Path.Combine(directory.FullName, "tools", "Build-CrestBake.cjs")) &&
                File.Exists(Path.Combine(directory.FullName, "CrestBakes.lua")))
                return directory.FullName;
        }
        throw new InvalidOperationException("Open the tool from inside the Epicast project folder.");
    }

    internal static string BakeExport(string root, string json)
    {
        if (!File.Exists(Path.Combine(root, "node_modules", "luaparse", "package.json")))
            throw new InvalidOperationException("Run npm ci in the Epicast project to install the bake compiler’s dependencies.");

        var start = new ProcessStartInfo("node.exe", "tools\\Build-CrestBake.cjs -") {
            WorkingDirectory = root, UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8
        };
        Process compiler;
        try { compiler = Process.Start(start); }
        catch (System.ComponentModel.Win32Exception error)
        {
            if (error.NativeErrorCode != 2) throw;
            throw new InvalidOperationException("Node.js is required. Add it to PATH and reopen the tool.");
        }

        using (compiler)
        {
            var output = compiler.StandardOutput.ReadToEndAsync();
            var errors = compiler.StandardError.ReadToEndAsync();
            byte[] bytes = Encoding.UTF8.GetBytes(json);
            try { compiler.StandardInput.BaseStream.Write(bytes, 0, bytes.Length); }
            catch (IOException) { /* The compiler may exit early. Show its error below. */ }
            finally { compiler.StandardInput.Close(); }
            compiler.WaitForExit();
            if (compiler.ExitCode != 0)
            {
                string detail = errors.Result.Trim();
                throw new InvalidOperationException(String.IsNullOrEmpty(detail) ? "The compiler rejected the export." : detail);
            }
            return output.Result.Trim();
        }
    }
}
