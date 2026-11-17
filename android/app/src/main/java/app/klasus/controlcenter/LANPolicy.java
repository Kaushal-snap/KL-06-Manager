package app.klasus.controlcenter;
import java.net.URL;
// Pure parser only: never resolve DNS, connect or install anything.
final class LANPolicy {
    static boolean privateURL(String raw) {
        if(raw==null||raw.length()>50||!raw.matches("https://(?:[0-9]{1,3}\\.){3}[0-9]{1,3}:8766/?"))return false;
        try { URL u=new URL(raw);if(!"https".equals(u.getProtocol())||u.getPort()!=8766||u.getUserInfo()!=null||u.getQuery()!=null||u.getRef()!=null||!(u.getPath().isEmpty()||u.getPath().equals("/")))return false;
            String[] p=u.getHost().split("\\.",-1);if(p.length!=4)return false;int[] n=new int[4];for(int i=0;i<4;i++){if(!p[i].matches("0|[1-9][0-9]{0,2}"))return false;n[i]=Integer.parseInt(p[i]);if(n[i]>255)return false;}
            return n[0]==10||n[0]==172&&n[1]>=16&&n[1]<=31||n[0]==192&&n[1]==168;
        } catch(Exception e){return false;}
    }
}
