using System.Diagnostics;
using System.Runtime.InteropServices;
namespace KL06;
internal sealed class NativeDevice:IDisposable {
    [StructLayout(LayoutKind.Sequential)]private struct FileTime { public uint Low,High;public readonly ulong Value=>((ulong)High<<32)|Low; }
    [StructLayout(LayoutKind.Sequential)]private struct Memory {public uint Length,Load;public ulong TotalPhysical,AvailablePhysical,TotalPageFile,AvailablePageFile,TotalVirtual,AvailableVirtual,AvailableExtendedVirtual;}
    [StructLayout(LayoutKind.Sequential)]private struct Power {public byte ACLineStatus,BatteryFlag,BatteryLifePercent,SystemStatusFlag;public uint BatteryLifeTime,BatteryFullLifeTime;}
    [DllImport("kernel32.dll",SetLastError=true)]private static extern bool GetSystemTimes(out FileTime idle,out FileTime kernel,out FileTime user);
    [DllImport("kernel32.dll",SetLastError=true)]private static extern bool GlobalMemoryStatusEx(ref Memory memory);
    [DllImport("kernel32.dll",SetLastError=true)]private static extern bool GetSystemPowerStatus(out Power status);
    [DllImport("kernel32.dll",SetLastError=true)]private static extern uint SetThreadExecutionState(uint flags);
    private ulong? previousIdle,previousTotal;private DateTime previousAt;private DateTime? awakeUntil;private long awakeStarted;
    internal bool Awake=>awakeUntil.HasValue&&DateTime.UtcNow<awakeUntil&&Stopwatch.GetElapsedTime(awakeStarted).TotalSeconds<900;
    internal string ToggleAwake(){if(Awake){StopAwake();return "Idle-sleep assertion stopped.";}if(SetThreadExecutionState(0x80000001)==0)throw new InvalidOperationException("Windows refused the idle-sleep assertion.");awakeStarted=Stopwatch.GetTimestamp();awakeUntil=DateTime.UtcNow.AddMinutes(15);return "Idle SYSTEM sleep prevented for at most 15 minutes while this app runs. No display/lid/forced-sleep override.";}
    internal void Tick(){if(awakeUntil.HasValue&&!Awake)StopAwake();}
    private void StopAwake(){SetThreadExecutionState(0x80000000);awakeUntil=null;}
    internal Dictionary<string,object?> Snapshot(){Tick();var now=DateTime.UtcNow;double? load=null,interval=null;
        if(GetSystemTimes(out var i,out var k,out var u)){ulong total=k.Value+u.Value;if(previousTotal.HasValue&&total>previousTotal&&i.Value>=previousIdle&&(now-previousAt).TotalSeconds>0&&(now-previousAt).TotalSeconds<=10){ulong elapsed=total-previousTotal.Value,idle=i.Value-previousIdle!.Value;if(idle<=elapsed){load=100.0*(elapsed-idle)/elapsed;interval=(now-previousAt).TotalSeconds;}}previousIdle=i.Value;previousTotal=total;previousAt=now;}
        var memory=new Memory{Length=(uint)Marshal.SizeOf<Memory>()};object ram=GlobalMemoryStatusEx(ref memory)?new{totalGB=memory.TotalPhysical/1073741824.0,usedGB=(memory.TotalPhysical-memory.AvailablePhysical)/1073741824.0,source="Windows physical total minus available"}:new{source="Windows memory status unavailable"};
        object battery=new{};if(GetSystemPowerStatus(out var p))battery=new{chargePercent=p.BatteryLifePercent<=100?(double?)p.BatteryLifePercent:null,onAC=p.ACLineStatus==255?(bool?)null:p.ACLineStatus==1,charging=p.BatteryFlag==255?(bool?)null:(p.BatteryFlag&8)!=0};
        object disk=new{};try{var drive=new DriveInfo(Path.GetPathRoot(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData))!);disk=new{totalGB=drive.TotalSize/1073741824.0,freeGB=drive.AvailableFreeSpace/1073741824.0};}catch{}
        double? volume=null;try{volume=CoreAudio.Read();}catch{}
        return new(){["platform"]="windows",["version"]="0.5.2-beta.1",["build"]=15,["sampledAt"]=now.ToString("O"),["sampledAtUnix"]=new DateTimeOffset(now).ToUnixTimeMilliseconds()/1000.0,["cpu"]=new{loadPercent=load,logicalCores=Environment.ProcessorCount,source="GetSystemTimes delta; OS-exposed processor group",intervalSeconds=interval},["memory"]=ram,["battery"]=battery,["storage"]=disk,["volume"]=volume,["awake"]=Awake,["capabilities"]=new{volume=volume.HasValue,brightness=false,awake=true},["fan"]=AsusFan.Read()};
    }
    public void Dispose()=>StopAwake();
}
internal static class CoreAudio {
    [ComImport,Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]private class Enumerator{}
    [ComImport,Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]private interface IEnum {
        [PreserveSig]int EnumAudioEndpoints(int flow,uint mask,out IntPtr collection);
        [PreserveSig]int GetDefaultAudioEndpoint(int flow,int role,out IDevice device);
    }
    [ComImport,Guid("D666063F-1587-4E43-81F1-B948E807363F"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]private interface IDevice {
        [PreserveSig]int Activate(ref Guid iid,uint context,IntPtr parameters,[MarshalAs(UnmanagedType.IUnknown)]out object instance);
    }
    [ComImport,Guid("5CDF2C82-841E-4546-9722-0CF74078229A"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]private interface IVolume {
        [PreserveSig]int RegisterControlChangeNotify(IntPtr notify);[PreserveSig]int UnregisterControlChangeNotify(IntPtr notify);
        [PreserveSig]int GetChannelCount(out uint count);[PreserveSig]int SetMasterVolumeLevel(float level,ref Guid context);[PreserveSig]int SetMasterVolumeLevelScalar(float level,ref Guid context);
        [PreserveSig]int GetMasterVolumeLevel(out float level);[PreserveSig]int GetMasterVolumeLevelScalar(out float level);
    }
    private static T With<T>(Func<IVolume,T> action){object? e=null,device=null,volume=null;try{e=new Enumerator();var en=(IEnum)e;Marshal.ThrowExceptionForHR(en.GetDefaultAudioEndpoint(0,1,out var d));device=d;var id=typeof(IVolume).GUID;Marshal.ThrowExceptionForHR(d.Activate(ref id,23,IntPtr.Zero,out var v));volume=v;return action((IVolume)v);}finally{if(volume is not null)Marshal.ReleaseComObject(volume);if(device is not null)Marshal.ReleaseComObject(device);if(e is not null)Marshal.ReleaseComObject(e);}}
    internal static double Read()=>With(v=>{Marshal.ThrowExceptionForHR(v.GetMasterVolumeLevelScalar(out var f));if(!float.IsFinite(f)||f<0||f>1)throw new InvalidOperationException("Invalid output volume.");return 100.0*f;});
    internal static string Set(double value){if(!double.IsFinite(value)||value<0||value>100)throw new InvalidOperationException("Invalid volume.");return With(v=>{var context=Guid.Empty;Marshal.ThrowExceptionForHR(v.SetMasterVolumeLevelScalar((float)(value/100),ref context));Marshal.ThrowExceptionForHR(v.GetMasterVolumeLevelScalar(out var f));if(!float.IsFinite(f)||Math.Abs(f*100-value)>2)throw new InvalidOperationException("Windows did not confirm the requested volume.");return $"Default output volume read back at {f*100:0.#}%. No codec/DTS/microphone setting changed.";});}
}

/// <summary>Read-only ASUS ATK WMI fan tachometer (DSTS, device 0x00110013; value*100 = RPM on tested K513EA).
/// The ASUS WMI class is admin-only, so this works only when KL-06 is started as administrator.
/// It never calls any method that writes (no DEVS, no fan control).</summary>
internal static class AsusFan {
    private static double? rpm;private static DateTime at=DateTime.MinValue;private static bool busy;private static string state="starting";
    private const string Script="try{$c=Get-CimInstance -Namespace root/wmi -ClassName AsusAtkWmi_WMNB -ErrorAction Stop;$r=Invoke-CimMethod -InputObject $c -MethodName DSTS -Arguments @{Device_ID=[uint32]1114131} -ErrorAction Stop;'OK '+$r.device_status}catch{'ERR '+$_.Exception.Message}";
    internal static object Read(){
        if(!busy&&(DateTime.UtcNow-at).TotalSeconds>=4){busy=true;System.Threading.Tasks.Task.Run(Refresh);}
        var age=(DateTime.UtcNow-at).TotalSeconds;
        if(rpm.HasValue&&age<=10)return new{status="ok",source="ASUS ATK WMI DSTS 0x00110013 (read-only, value x100)",ageSeconds=(double?)age,manualControl=false,fans=new object[]{new{index=0,status="ok",rpm=rpm.Value}}};
        var why=state=="needs-admin"?"ASUS fan needs admin: run  Start-Process 'KL-06 Manager.exe' -ArgumentList --fan-admin -Verb RunAs  (phone transfer is disabled in that mode)":state=="no-fan"?"ASUS WMI reports no fan on this device":"ASUS fan RPM unavailable ("+state+"). Or import a HWiNFO CSV on History";
        return new{status="unsupported",source=why,ageSeconds=(double?)null,manualControl=false,fans=Array.Empty<object>()};
    }
    private static void Refresh(){
        try{
            var psi=new ProcessStartInfo("powershell.exe"){RedirectStandardOutput=true,UseShellExecute=false,CreateNoWindow=true};
            psi.ArgumentList.Add("-NoProfile");psi.ArgumentList.Add("-NonInteractive");psi.ArgumentList.Add("-Command");psi.ArgumentList.Add(Script);
            using var p=Process.Start(psi);if(p is null){state="no-powershell";return;}
            if(!p.WaitForExit(8000)){try{p.Kill();}catch{}state="timeout";return;}
            var o=p.StandardOutput.ReadToEnd().Trim();
            if(o.StartsWith("OK ")&&uint.TryParse(o.AsSpan(3),out var raw)){
                if((raw&0x10000)!=0&&(raw&0xFFFF)>0){rpm=(raw&0xFFFF)*100.0;at=DateTime.UtcNow;state="ok";}
                else{rpm=null;state="no-fan";}
            }else{rpm=null;state=o.Contains("denied",StringComparison.OrdinalIgnoreCase)?"needs-admin":"error";}
        }catch{rpm=null;state="error";}
        finally{busy=false;}
    }
}
