using System.Text.Json;
using System.Text.RegularExpressions;
namespace KL06;
internal sealed record PreferenceSpec(string Id, string Title, string RegistryPath, string Name, int Applied) {
    internal static readonly PreferenceSpec[] All = [
        new("win-extensions", "Show file extensions", @"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "HideFileExt", 0),
        new("win-hidden", "Show ordinary hidden files", @"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "Hidden", 1),
        new("win-theme-dark", "Dark application theme", @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 0)
    ];
    internal static PreferenceSpec Find(string id) => All.FirstOrDefault(x => x.Id == id) ?? throw new InvalidOperationException("Unsupported preference.");
}
internal static class ControlPolicy {
    internal static bool Exact(JsonElement value, params string[] keys) => value.ValueKind == JsonValueKind.Object && value.EnumerateObject().Count() == keys.Length && value.EnumerateObject().Select(x => x.Name).Order().SequenceEqual(keys.Order());
    internal static bool PrivateIPv4(string text) {
        var p=text.Split('.'); if(p.Length!=4) return false;
        var n=new int[4];for(int i=0;i<4;i++)if(!Regex.IsMatch(p[i], @"\A(0|[1-9][0-9]{0,2})\z")||!int.TryParse(p[i],out n[i])||n[i]>255)return false;
        return n[0]==10||n[0]==172&&n[1]>=16&&n[1]<=31||n[0]==192&&n[1]==168;
    }
    internal static double Volume(JsonElement p) {
        if(!Exact(p,"value")||p.GetProperty("value").ValueKind!=JsonValueKind.Number||!p.GetProperty("value").TryGetDouble(out var n)||!double.IsFinite(n)||n<0||n>100)throw new InvalidOperationException("Invalid volume.");return n;
    }
    internal static string Tweak(JsonElement p) {if(!Exact(p,"id")||p.GetProperty("id").ValueKind!=JsonValueKind.String)throw new InvalidOperationException("Invalid preference.");var id=p.GetProperty("id").GetString()!;PreferenceSpec.Find(id);return id;}
    internal static bool Allowed(string method,JsonElement p) {try{switch(method){case "setVolume":Volume(p);return true;case "applyTweak":case "restoreTweak":Tweak(p);return true;case "restoreAll":case "keepAwake":return Exact(p);default:return false;}}catch{return false;}}
    internal static string Describe(string method, JsonElement p) => method switch {
        "setVolume" => $"Set default output volume to {Volume(p):0.##}% (immediate; no desktop volume journal)",
        "applyTweak" => $"Apply {PreferenceSpec.Find(Tweak(p)).Title} [{Tweak(p)}]",
        "restoreTweak" => $"Restore the exact saved original for {PreferenceSpec.Find(Tweak(p)).Title} [{Tweak(p)}] if still owned",
        "restoreAll" => "Restore all three eligible saved preferences; skip newer external choices",
        "keepAwake" => "Toggle idle-SYSTEM-sleep prevention, maximum 15 minutes; no display/lid/forced-sleep override",
        _ => throw new InvalidOperationException("Unsupported operation.")
    };
}
