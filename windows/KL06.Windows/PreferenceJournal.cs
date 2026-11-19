using System.Text.Json;
namespace KL06;
internal interface IPreferenceBackend { int? Read(PreferenceSpec spec); void Write(PreferenceSpec spec,int? value); bool Managed(PreferenceSpec spec); }
internal interface IJournalStorage { string? Read(); void Save(string json); }
internal sealed record RestoreEntry(bool OriginalExists,int? Original,int Applied);
internal sealed record RestoreDocument(int Schema,Dictionary<string,RestoreEntry> Entries);
internal sealed class PreferenceJournal {
    private readonly IPreferenceBackend backend;private readonly IJournalStorage storage;
    private Dictionary<string,RestoreEntry> entries=[];private readonly bool blocked;
    internal PreferenceJournal(IPreferenceBackend backend,IJournalStorage storage){this.backend=backend;this.storage=storage;try{
        var raw=storage.Read();if(raw is null)return;
        using var document=JsonDocument.Parse(raw,new JsonDocumentOptions{MaxDepth=8});
        if(!ControlPolicy.Exact(document.RootElement,"Schema","Entries"))throw new InvalidDataException();
        var d=JsonSerializer.Deserialize<RestoreDocument>(raw)??throw new InvalidDataException();if(d.Schema!=1||d.Entries is null||d.Entries.Count>3)throw new InvalidDataException();
        foreach(var (id,e) in d.Entries){var spec=PreferenceSpec.Find(id);if(e is null||e.Applied!=spec.Applied||e.OriginalExists!=e.Original.HasValue)throw new InvalidDataException();}
        var items=document.RootElement.GetProperty("Entries");if(items.ValueKind!=JsonValueKind.Object||items.EnumerateObject().Count()!=d.Entries.Count)throw new InvalidDataException();
        foreach(var item in items.EnumerateObject())if(!ControlPolicy.Exact(item.Value,"OriginalExists","Original","Applied"))throw new InvalidDataException();
        entries=d.Entries;
    }catch{blocked=true;}}
    private void Check(PreferenceSpec spec){if(blocked)throw new InvalidOperationException("Restore journal is unsafe or corrupt. Writes are blocked; preserve it for review.");if(backend.Managed(spec))throw new InvalidOperationException("A policy-managed preference is blocked.");}
    private void Save(Dictionary<string,RestoreEntry> next){storage.Save(JsonSerializer.Serialize(new RestoreDocument(1,next)));entries=next;}
    internal string Apply(string id){var s=PreferenceSpec.Find(id);Check(s);var current=backend.Read(s);
        if(entries.TryGetValue(id,out var existing)){if(current!=existing.Applied)throw new InvalidOperationException("Newer external change or incomplete prior write: restore/review first.");return "Already applied; saved original was preserved.";}
        if(current==s.Applied)return "Already configured; no invented original was saved.";
        var next=new Dictionary<string,RestoreEntry>(entries){[id]=new(current.HasValue,current,s.Applied)};Save(next);
        if(backend.Read(s)!=current)throw new InvalidOperationException("Preference changed externally before the write; no setting was written. Preserve/review the journal.");
        backend.Write(s,s.Applied);if(backend.Read(s)!=s.Applied)throw new InvalidOperationException("Readback did not confirm the write; journal retained for review.");return "Applied and read back. Reopen the relevant Windows UI if needed; no Explorer process was killed.";
    }
    internal string Restore(string id){var s=PreferenceSpec.Find(id);Check(s);if(!entries.TryGetValue(id,out var e))return "No saved original for this preference.";var current=backend.Read(s);
        if(current!=e.Applied&&current!=e.Original)throw new InvalidOperationException("Newer external choice preserved; restore was skipped.");
        if(current==e.Applied){backend.Write(s,e.Original);if(backend.Read(s)!=e.Original)throw new InvalidOperationException("Restore readback failed; original remains in the journal.");}
        var next=new Dictionary<string,RestoreEntry>(entries);next.Remove(id);Save(next);return "Original value/absence restored and read back; newer conflicting choices are never overwritten.";
    }
    internal string RestoreAll()=>string.Join("\n",PreferenceSpec.All.Select(s=>{try{return s.Title+": "+Restore(s.Id);}catch(Exception e){return s.Title+": "+e.Message;}}));
    internal object[] States()=>PreferenceSpec.All.Select(s=>{bool saved=entries.TryGetValue(s.Id,out var entry);bool managed=true,conflict=false,unavailable=false;try{managed=backend.Managed(s);var current=backend.Read(s);conflict=saved&&current!=entry!.Applied&&current!=entry.Original;}catch{unavailable=true;}return (object)new{id=s.Id,saved,conflict,managed,blocked=blocked||unavailable};}).ToArray();
}
