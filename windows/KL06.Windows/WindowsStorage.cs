using Microsoft.Win32;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Runtime.InteropServices;
namespace KL06;
internal static class FileSafety {
    internal static readonly SecurityIdentifier User=WindowsIdentity.GetCurrent().User??throw new InvalidOperationException("No local identity.");
    internal static void Regular(string path,long limit){var f=new FileInfo(path);if((f.Attributes&(FileAttributes.ReparsePoint|FileAttributes.Directory))!=0||f.Length>limit)throw new IOException("Unsafe or oversized local file.");}
    internal static void PrivateDirectory(string path){
        if(File.Exists(path))throw new IOException("Unsafe private directory.");Directory.CreateDirectory(path);
        if((File.GetAttributes(path)&FileAttributes.ReparsePoint)!=0)throw new IOException("Private directory cannot be a link.");
        var acl=new DirectorySecurity();acl.SetOwner(User);acl.SetAccessRuleProtection(true,false);
        var inheritance=InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit;
        acl.AddAccessRule(new FileSystemAccessRule(User,FileSystemRights.FullControl,inheritance,PropagationFlags.None,AccessControlType.Allow));
        acl.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(WellKnownSidType.LocalSystemSid,null),FileSystemRights.FullControl,inheritance,PropagationFlags.None,AccessControlType.Allow));
        new DirectoryInfo(path).SetAccessControl(acl);
    }
    internal static void Atomic(string path,string json){
        var parent=Path.GetDirectoryName(path)!;PrivateDirectory(parent);if(File.Exists(path))Regular(path,262144);
        var temp=Path.Combine(parent,"."+Guid.NewGuid().ToString("N")+".tmp");
        try{using(var f=new FileStream(temp,FileMode.CreateNew,FileAccess.Write,FileShare.None)){byte[] b=Encoding.UTF8.GetBytes(json);f.Write(b);f.Flush(true);}File.Move(temp,path,true);}finally{if(File.Exists(temp))File.Delete(temp);}
    }
    [DllImport("shell32.dll",CharSet=CharSet.Unicode)]private static extern void SHChangeNotify(uint eventId,uint flags,IntPtr item1,IntPtr item2);
    internal static void NotifyPreferences()=>SHChangeNotify(0x08000000,0,IntPtr.Zero,IntPtr.Zero);
}
internal sealed class WindowsJournalStorage:IJournalStorage {
    private readonly string path;
    internal WindowsJournalStorage(string directory){FileSafety.PrivateDirectory(directory);path=Path.Combine(directory,"Restore-v1.json");}
    public string? Read(){if(!File.Exists(path))return null;FileSafety.Regular(path,65536);return File.ReadAllText(path,Encoding.UTF8);}
    public void Save(string json)=>FileSafety.Atomic(path,json);
}
internal sealed class RegistryPreferences:IPreferenceBackend {
    public int? Read(PreferenceSpec s){using var k=Registry.CurrentUser.OpenSubKey(s.RegistryPath,false);if(k is null||!k.GetValueNames().Contains(s.Name,StringComparer.OrdinalIgnoreCase))return null;if(k.GetValueKind(s.Name)!=RegistryValueKind.DWord)throw new InvalidOperationException("Unexpected registry type; not overwritten.");return k.GetValue(s.Name) is int n?n:throw new InvalidOperationException("Unsupported preference value.");}
    public bool Managed(PreferenceSpec s){
        // Conservative presence checks: no policy edits or bypass. A managed machine may have other restrictions; writes still require readback.
        foreach(var hive in new[]{Registry.CurrentUser,Registry.LocalMachine})foreach(var path in new[]{@"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer",@"Software\Policies\Microsoft\Windows\Explorer",@"Software\Microsoft\Windows\CurrentVersion\Policies\System",@"Software\Policies\Microsoft\Windows\Personalization"}){using var k=hive.OpenSubKey(path,false);if(k is not null&&k.ValueCount>0)return true;}
        return false;
    }
    public void Write(PreferenceSpec s,int? value){if(Managed(s))throw new InvalidOperationException("Policy-managed preference is blocked.");using var key=Registry.CurrentUser.CreateSubKey(s.RegistryPath,true);if(value.HasValue)key.SetValue(s.Name,value.Value,RegistryValueKind.DWord);else key.DeleteValue(s.Name,false);key.Flush();FileSafety.NotifyPreferences();}
}
