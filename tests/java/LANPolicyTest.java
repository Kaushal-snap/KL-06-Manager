package app.klasus.controlcenter;
public final class LANPolicyTest {
    private static int checks;
    private static void check(String value,boolean expected){checks++;if(LANPolicy.privateURL(value)!=expected)throw new AssertionError("LAN URL parser did not enforce the literal private HTTPS boundary.");}
    public static void main(String[] args){
        for(String good:new String[]{"https://10.0.0.1:8766","https://172.16.0.1:8766/","https://172.31.255.254:8766","https://192.168.1.2:8766"})check(good,true);
        for(String bad:new String[]{null,"","http://10.0.0.1:8766","https://8.8.8.8:8766","https://127.0.0.1:8766","https://0.0.0.0:8766","https://169.254.1.1:8766","https://172.32.0.1:8766","https://laptop.local:8766","https://[::1]:8766","https://10.0.0.1:443","https://10.0.0.1:08766","https://010.0.0.1:8766","https://10.0.0.999:8766","https://0xc0a80102:8766","https://3232235778:8766","https://name@10.0.0.1:8766","https://10.0.0.1:8766/path","https://10.0.0.1:8766?x=1","https://10.0.0.1:8766#x","https://10.0.0.1:8766\n"," https://10.0.0.1:8766","https://10.0.0.1:8766 ","https://10.0.1:8766"})check(bad,false);
        System.out.println(checks+" pure Java LAN-policy checks passed. No Android/device or network operation was performed.");
    }
}
