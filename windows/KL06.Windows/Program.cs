using System.Security.Principal;
namespace KL06;
internal static class Program {
    [STAThread]private static void Main(){
        ApplicationConfiguration.Initialize();
        if(!OperatingSystem.IsWindowsVersionAtLeast(10,0,19041)){MessageBox.Show("This testing candidate requires a supported Windows 10/11 installation and .NET 10 Desktop Runtime. Older Windows is not supported.","KL-06 Manager");return;}
        if(new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator)){MessageBox.Show("Run KL-06 normally, not as administrator. No settings, service or companion session were started.","KL-06 Manager");return;}
        using var mutex=new Mutex(true,@"Local\KL06-Manager-"+FileSafety.User.Value,out bool first);if(!first){MessageBox.Show("KL-06 is already running for this user. Open that copy or quit it first; no restore journal was reset.","KL-06 Manager");return;}
        try{var root=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"KL-06");FileSafety.PrivateDirectory(root);Application.Run(new MainForm(root));}catch{MessageBox.Show("KL-06 could not prepare its private app-data directory. No automatic repair, privilege elevation or security change was attempted.","KL-06 Manager");}
    }
}
