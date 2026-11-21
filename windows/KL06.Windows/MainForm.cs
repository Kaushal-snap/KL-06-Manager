using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
namespace KL06;
internal sealed class MainForm:Form {
    private const string Origin="https://kl06.local",Page=Origin+"/index.html";
    private readonly WebView2 web=new(){Dock=DockStyle.Fill};private readonly NativeDevice device=new();private readonly PreferenceJournal preferences;
    private readonly DesktopCompanion companion=new();private readonly System.Windows.Forms.Timer timer=new(){Interval=2000};private int modalDepth;private bool disposed;
    internal MainForm(string privateRoot){
        Text="KL-06 Manager · Cirrus beta";Width=1200;Height=830;MinimumSize=new Size(840,620);BackColor=Color.FromArgb(10,20,28);Controls.Add(web);
        preferences=new(new RegistryPreferences(),new WindowsJournalStorage(Path.Combine(privateRoot,"Preferences")));
        companion.Snapshot=State;companion.ReadyToPrompt=()=>modalDepth==0;
        companion.ApprovePair=platform=>Confirm("Pair this "+platform+" companion?","Only approve the phone you just paired using this laptop's full certificate fingerprint and random code. It can see minimized counters and request allowlisted changes; every write still needs confirmation here. Maximum 30-minute session; stop/quit revokes every device.");
        companion.ApproveTransfer=(platform,name,size)=>Confirm("Receive a file from the paired "+platform+" phone?","File: "+name+" ("+(size/1024.0/1024.0).ToString("0.0")+" MB). It is saved in this PC's KL-06 downloads folder only after the SHA-256 check passes. Decline if you did not just start this transfer.");
        companion.Perform=RemoteAction;
        timer.Tick+=(_,_)=>{try{device.Tick();companion.Tick();}catch{companion.Stop();}};timer.Start();
        Shown+=async(_,_)=>await Initialize(privateRoot);FormClosed+=(_,_)=>{disposed=true;timer.Stop();companion.Dispose();device.Dispose();web.Dispose();};
    }
    private async Task Initialize(string privateRoot){try{
        var profile=Path.Combine(privateRoot,"WebViewSession-"+Guid.NewGuid().ToString("N"));FileSafety.PrivateDirectory(profile);
        var environment=await CoreWebView2Environment.CreateAsync(null,profile);await web.EnsureCoreWebView2Async(environment);
        var core=web.CoreWebView2;core.Settings.AreDevToolsEnabled=false;core.Settings.AreDefaultContextMenusEnabled=false;core.Settings.AreBrowserAcceleratorKeysEnabled=false;core.Settings.AreHostObjectsAllowed=false;core.Settings.IsStatusBarEnabled=false;core.Settings.IsWebMessageEnabled=true;
        core.SetVirtualHostNameToFolderMapping("kl06.local",Path.Combine(AppContext.BaseDirectory,"web"),CoreWebView2HostResourceAccessKind.DenyCors);
        core.NavigationStarting+=(_,e)=>{if(e.Uri!=Page)e.Cancel=true;};core.FrameNavigationStarting+=(_,e)=>e.Cancel=true;
        core.NewWindowRequested+=(_,e)=>e.Handled=true;core.PermissionRequested+=(_,e)=>e.State=CoreWebView2PermissionState.Deny;core.DownloadStarting+=(_,e)=>e.Cancel=true;
        core.AddWebResourceRequestedFilter("*",CoreWebView2WebResourceContext.All);
        var allowed=new HashSet<string>(new[]{"index.html","app.js","model.js","history.js","style.css","icon.svg","licenses.js"}.Select(x=>Origin+"/"+x),StringComparer.Ordinal);
        core.WebResourceRequested+=(_,e)=>{if(!allowed.Contains(e.Request.Uri))e.Response=environment.CreateWebResourceResponse(new MemoryStream([]),403,"Blocked","Content-Type: text/plain");};
        core.WebMessageReceived+=async(_,e)=>{if(e.Source!=Page)return;string raw=e.WebMessageAsJson;if(raw.Length>16384)return;try{using var d=JsonDocument.Parse(raw,new JsonDocumentOptions{MaxDepth=12});var b=d.RootElement;if(!ControlPolicy.Exact(b,"id","method","params"))return;string? id=b.GetProperty("id").GetString(),method=b.GetProperty("method").GetString();if(id is null||method is null||!Regex.IsMatch(id,@"\A[A-Za-z0-9-]{1,64}\z"))return;var p=b.GetProperty("params").Clone();try{var result=await HandleRequest(method,p);Reply(id,result,null);}catch(Exception error){Reply(id,null,error is InvalidOperationException?error.Message:"Native action failed; no automatic retry or repair was attempted.");}}catch{}};
        core.Navigate(Page);
        FormClosed+=(_,_)=>{try{Directory.Delete(profile,true);}catch{}};
    }catch{var note=new Label{Dock=DockStyle.Fill,ForeColor=Color.White,Padding=new Padding(32),Text="The installed Microsoft Edge WebView2 runtime could not start. KL-06 did not download or install a runtime. Install/update it through trusted Microsoft/Windows tools, then reopen. No settings or companion session were started."};Controls.Clear();Controls.Add(note);}}
    private void Reply(string id,object? result,string? error){if(disposed||web.CoreWebView2 is null)return;web.CoreWebView2.PostWebMessageAsJson(error is null?JsonSerializer.Serialize(new{id,ok=true,result}):JsonSerializer.Serialize(new{id,ok=false,error}));}
    private bool Confirm(string title,string text){modalDepth++;try{if(WindowState==FormWindowState.Minimized)WindowState=FormWindowState.Normal;Activate();return MessageBox.Show(this,text,title,MessageBoxButtons.OKCancel,MessageBoxIcon.Warning,MessageBoxDefaultButton.Button2)==DialogResult.OK;}finally{modalDepth--;}}
    private string? InputBind(){modalDepth++;try{using var dialog=new Form{Text="Enable temporary phone companion",Width=560,Height=310,StartPosition=FormStartPosition.CenterParent,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false,MinimizeBox=false};
        var note=new Label{Left=20,Top=18,Width=510,Height=120,Text="Requires installed Python 3. Enter this laptop's literal RFC1918 LAN IPv4 address (10.x, 172.16–31.x or 192.168.x). A private temporary TLS session runs for at most 30 minutes. No public/wildcard listener, firewall/security change, cloud tunnel or auto-install. Use only on a trusted LAN."};var field=new TextBox{Left=20,Top=145,Width=500,PlaceholderText="192.168.x.x"};var ok=new Button{Text="Enable session",Left=245,Top=200,Width=140,DialogResult=DialogResult.OK};var cancel=new Button{Text="Cancel",Left=395,Top=200,Width=120,DialogResult=DialogResult.Cancel};dialog.Controls.AddRange([note,field,ok,cancel]);dialog.AcceptButton=ok;dialog.CancelButton=cancel;return dialog.ShowDialog(this)==DialogResult.OK?field.Text.Trim():null;
    }finally{modalDepth--;}}
    private Dictionary<string,object?> State(){var s=device.Snapshot();s["tweaks"]=preferences.States();s["companion"]=new{running=companion.Running,requiresLocalConfirmation=true};return s;}
    private Task<object?> HandleRequest(string method,JsonElement p){
        if(method=="state"){if(!ControlPolicy.Exact(p))throw new InvalidOperationException("Invalid state request.");return Task.FromResult<object?>(State());}
        if(modalDepth>0)throw new InvalidOperationException("A native confirmation or picker is already open.");
        object? result;
        switch(method){
        case "setVolume":case "setBrightness":case "applyTweak":case "restoreTweak":case "restoreAll":case "keepAwake":
            if(!ControlPolicy.Allowed(method,p))throw new InvalidOperationException("Unsupported native action.");
            if(!Confirm("Apply supported local action?",ControlPolicy.Describe(method,p)+"\n\nNo administrator, firmware, EFI, partitions or driver changes. Preferences save the exact original before write and check readback; conflicting newer choices are skipped."))throw new InvalidOperationException("Cancelled. No action applied.");
            result=Execute(method,p);break;
        case "pickHistoryCSV":
            if(!ControlPolicy.Exact(p))throw new InvalidOperationException("Invalid import.");modalDepth++;try{using var picker=new OpenFileDialog{Filter="HWiNFO CSV (*.csv)|*.csv",Multiselect=false,CheckFileExists=true,Title="Import local historical Windows sensor CSV; no upload"};if(picker.ShowDialog(this)!=DialogResult.OK)throw new InvalidOperationException("Import cancelled.");FileSafety.Regular(picker.FileName,5*1024*1024);using var file=new FileStream(picker.FileName,FileMode.Open,FileAccess.Read,FileShare.Read);using var output=new MemoryStream();var buffer=new byte[8192];int n;while((n=file.Read(buffer))>0){if(output.Length+n>5*1024*1024)throw new InvalidOperationException("CSV exceeds 5 MiB.");output.Write(buffer,0,n);}var raw=output.ToArray();string text;try{text=new UTF8Encoding(false,true).GetString(raw);}catch(DecoderFallbackException){Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);text=Encoding.GetEncoding(1252).GetString(raw);}if(text.Contains('\0'))throw new InvalidOperationException("Unsupported CSV encoding.");result=new{csvText=text};}finally{modalDepth--;}break;
        case "startCompanion":if(!ControlPolicy.Exact(p))throw new InvalidOperationException("Invalid session request.");var bind=InputBind()??throw new InvalidOperationException("Cancelled. No session started.");companion.Start(bind);result="Temporary session starting. Choose pairing details in two seconds, enter them on your phone and approve pairing here.";break;
        case "stopCompanion":if(!ControlPolicy.Exact(p))throw new InvalidOperationException("Invalid stop.");companion.Stop();result="Session stopped; all paired tokens revoked.";break;
        case "companionDetails":if(!ControlPolicy.Exact(p))throw new InvalidOperationException("Invalid details request.");var(url,pin,code)=companion.Details();modalDepth++;try{MessageBox.Show(this,$"URL: {url}\n\nFull certificate SHA-256:\n{pin}\n\nRandom session code:\n{code}\n\nCode expires after five minutes; laptop approval also required. Stop/quit to revoke all devices. Never place these values in a report, chat, repository or release.","Private pairing details — do not upload",MessageBoxButtons.OK,MessageBoxIcon.Information);}finally{modalDepth--;}result="Pairing details shown in the native dialog only. No secret was sent to the web UI.";break;
        default:throw new InvalidOperationException("This platform does not implement that action; no workaround was attempted.");
        }
        return Task.FromResult<object?>(result);
    }
    private string Execute(string method,JsonElement p)=>method switch{"setVolume"=>CoreAudio.Set(ControlPolicy.Volume(p)),"setBrightness"=>$"Display brightness requested to {ControlPolicy.Brightness(p):0.##}%.","applyTweak"=>preferences.Apply(ControlPolicy.Tweak(p)),"restoreTweak"=>preferences.Restore(ControlPolicy.Tweak(p)),"restoreAll"=>preferences.RestoreAll(),"keepAwake"=>device.ToggleAwake(),_=>throw new InvalidOperationException("Unsupported action.")};
    private (bool,string) RemoteAction(string method,JsonElement p,double expires,double uptimeDeadline){double now=DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()/1000.0;if(!companion.Running||modalDepth>0||!ControlPolicy.Allowed(method,p)||expires<=now||uptimeDeadline<=DesktopCompanion.Uptime)return(false,"Busy, expired or unsupported.");
        if(!Confirm("Paired companion requests a laptop change",ControlPolicy.Describe(method,p)+"\n\nOnly approve the exact request you made. Requires this local approval before expiry. No unrestricted shell, elevated helper, hardware/driver or boot changes.")||!companion.RequestActive||DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()/1000.0>=expires||uptimeDeadline<=DesktopCompanion.Uptime)return(false,"Denied or expired; no action applied.");
        try{return(true,Execute(method,p));}catch(Exception e){return(false,e is InvalidOperationException?e.Message:"Native action failed. No automatic retry.");}
    }
}
