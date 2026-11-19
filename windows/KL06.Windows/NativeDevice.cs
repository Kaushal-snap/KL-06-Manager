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
        return new(){["platform"]="windows",["version"]="0.4.7-beta",["build"]=12,["sampledAt"]=now.ToString("O"),["sampledAtUnix"]=new DateTimeOffset(now).ToUnixTimeMilliseconds()/1000.0,["cpu"]=new{loadPercent=load,logicalCores=Environment.ProcessorCount,source="GetSystemTimes delta; OS-exposed processor group",intervalSeconds=interval},["memory"]=ram,["battery"]=battery,["storage"]=disk,["volume"]=volume,["awake"]=Awake,["capabilities"]=new{volume=volume.HasValue,brightness=false,awake=true},["fan"]=new{status="unsupported",source="No bundled Windows sensor driver; import HWiNFO CSV history explicitly",ageSeconds=(double?)null,manualControl=false,fans=Array.Empty<object>()}};
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
