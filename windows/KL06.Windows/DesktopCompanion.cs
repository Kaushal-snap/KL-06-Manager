using System.Diagnostics;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
namespace KL06;
internal sealed class DesktopCompanion:IDisposable {
    private Process? process;private string? folder;private bool processing;private string? activeRequest;
    internal static double Uptime=>Stopwatch.GetTimestamp()/(double)Stopwatch.Frequency;
    internal bool RequestActive=>Running&&activeRequest is not null&&File.Exists(activeRequest);
    internal Func<Dictionary<string,object?>>? Snapshot;
    internal Func<bool>? ReadyToPrompt;
    internal Func<string,bool>? ApprovePair;
    internal Func<string,JsonElement,double,double,(bool,string)>? Perform;
    internal bool Running{get{try{return process is not null&&!process.HasExited;}catch{return false;}}}
    private static string? Python(){
        var candidates=new List<string>();
        foreach(var root in new[]{Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Programs","Python"),Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles)}){
            if(!Directory.Exists(root))continue;
            try{foreach(var d in Directory.GetDirectories(root,"Python3*").OrderDescending()){if((File.GetAttributes(d)&FileAttributes.ReparsePoint)!=0)continue;candidates.Add(Path.Combine(d,"python.exe"));}}catch{}
        }
        // No PATH/current-directory search, Store-launch/install alias or py launcher.
        return candidates.FirstOrDefault(p=>File.Exists(p)&&(File.GetAttributes(p)&FileAttributes.ReparsePoint)==0);
    }
    internal void Start(string bind){
        if(Running||!ControlPolicy.PrivateIPv4(bind))throw new InvalidOperationException("Use a literal private LAN IPv4 address; stop an existing session first.");
        var python=Python()??throw new InvalidOperationException("No supported installed Python 3 executable was found in its standard per-user/Program Files install directories. Nothing was downloaded. Mac/Windows local controls work without the broker.");
        Stop();var root=Path.Combine(Path.GetTempPath(),"KL06-Companion-"+Guid.NewGuid().ToString("N"));FileSafety.PrivateDirectory(root);folder=root;
        try{
            using var rsa=RSA.Create(2048);var request=new CertificateRequest("CN=KL-06-Local-Companion",rsa,HashAlgorithmName.SHA256,RSASignaturePadding.Pkcs1);
            using var cert=request.CreateSelfSigned(DateTimeOffset.UtcNow.AddMinutes(-1),DateTimeOffset.UtcNow.AddDays(1));
            FileSafety.Atomic(Path.Combine(root,"cert.pem"),cert.ExportCertificatePem());FileSafety.Atomic(Path.Combine(root,"key.pem"),rsa.ExportPkcs8PrivateKeyPem());
            var script=Path.Combine(AppContext.BaseDirectory,"companion","server.py");FileSafety.Regular(script,131072);
            var start=new ProcessStartInfo(python){UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=root};
            foreach(var a in new[]{"-I",script,"--directory",root,"--bind",bind})start.ArgumentList.Add(a);
            process=Process.Start(start)??throw new InvalidOperationException("Broker start failed.");
        }catch{Stop();throw;}
    }
    private static JsonDocument Read(string path,int limit){FileSafety.Regular(path,limit);return JsonDocument.Parse(File.ReadAllText(path,Encoding.UTF8),new JsonDocumentOptions{MaxDepth=16});}
    internal (string,string,string) Details(){
        if(!Running||folder is null)throw new InvalidOperationException("Session is off or still starting.");using var d=Read(Path.Combine(folder,"session.json"),16384);var r=d.RootElement;
        string url=r.GetProperty("url").GetString()??"",pin=r.GetProperty("certificateSha256").GetString()??"",code=r.GetProperty("pairCode").GetString()??"";
        if(r.GetProperty("schema").GetString()!="KL06_COMPANION_V1"||!Uri.TryCreate(url,UriKind.Absolute,out var u)||u.Scheme!="https"||u.Port!=8766||!ControlPolicy.PrivateIPv4(u.Host)||!Regex.IsMatch(pin,@"\A[a-f0-9]{64}\z")||!Regex.IsMatch(code,@"\A[a-f0-9]{32}\z"))throw new InvalidOperationException("Invalid private session record.");
        if(r.GetProperty("pairCodeExpiresAt").GetDouble()<=DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()/1000.0||r.GetProperty("pairCodeExpiresMonotonic").GetDouble()<=Uptime)throw new InvalidOperationException("Pairing code expired. Stop and explicitly start a new session; existing tokens are not silently extended.");
        return(url,pin,code);
    }
    internal void Tick(){
        if(processing)return;if(!Running||folder is null){if(folder is not null)Stop();return;}processing=true;
        try{
            var root=folder;var value=Snapshot?.Invoke();if(value is not null)FileSafety.Atomic(Path.Combine(root,"snapshot.json"),JsonSerializer.Serialize(new{schema="KL06_DESKTOP_SNAPSHOT_V1",writtenAt=DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()/1000.0,state=value}));
            if(ReadyToPrompt?.Invoke()==false)return;var queue=Path.Combine(root,"requests");if(!Directory.Exists(queue)||(File.GetAttributes(queue)&FileAttributes.ReparsePoint)!=0)return;
            foreach(var path in Directory.GetFiles(queue,"*.json").Order().Take(32)){
                var filename=Path.GetFileName(path);if(!Regex.IsMatch(filename,@"\A[a-f0-9]{32}\.json\z"))continue;
                try{
                    using var d=Read(path,16384);var r=d.RootElement;double now=DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()/1000.0;
                    var id=r.GetProperty("id").GetString();double expires=r.GetProperty("expiresAt").GetDouble(),created=r.GetProperty("createdAt").GetDouble(),createdUptime=r.GetProperty("createdMonotonic").GetDouble(),uptimeDeadline=r.GetProperty("expiresMonotonic").GetDouble();
                    if(id+".json"!=filename||r.GetProperty("schema").GetString()!="KL06_COMPANION_V1"||!double.IsFinite(expires)||!double.IsFinite(created)||expires<=now||created>now+2||expires<created||expires-created>91||!double.IsFinite(createdUptime)||!double.IsFinite(uptimeDeadline)||createdUptime>Uptime+2||uptimeDeadline<createdUptime||uptimeDeadline-createdUptime>91||uptimeDeadline<=Uptime)continue;
                    bool ok=false,approved=false;string message="Denied, expired or unsupported.";
                    if(r.GetProperty("kind").GetString()=="pair"){
                        var platform=r.GetProperty("platform").GetString();if(platform is "android" or "ios")approved=ApprovePair?.Invoke(platform)==true&&DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()/1000.0<expires&&uptimeDeadline>Uptime&&Running;
                    }else if(r.GetProperty("kind").GetString()=="command"){
                        var operation=r.GetProperty("operation").GetString();var p=r.GetProperty("params");if(operation is not null&&ControlPolicy.Allowed(operation,p)&&Perform is not null){activeRequest=path;try{(ok,message)=Perform(operation,p,expires,uptimeDeadline);}finally{activeRequest=null;}}
                    }
                    FileSafety.Atomic(Path.Combine(queue,id+".result.json"),JsonSerializer.Serialize(new{ok,approved,message}));
                }catch{}finally{try{File.Delete(path);}catch{}}
            }
        }finally{processing=false;}
    }
    internal void Stop(){activeRequest=null;
        if(process is not null){try{if(!process.HasExited){process.Kill(true);process.WaitForExit(3000);}}catch{}process.Dispose();process=null;}
        if(folder is not null){try{if((File.GetAttributes(folder)&FileAttributes.ReparsePoint)==0)Directory.Delete(folder,true);}catch{}folder=null;}
    }
    public void Dispose()=>Stop();
}
