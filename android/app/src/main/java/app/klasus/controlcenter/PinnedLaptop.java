package app.klasus.controlcenter;
import org.json.JSONObject;
import java.io.*;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.security.cert.*;
import javax.net.ssl.*;

// Tokens live only in native session memory, never preferences, JS state or logs.
final class PinnedLaptop {
    private URL base; private byte[] fingerprint; private String code,ticket,last; private volatile String token; private volatile double expires;
    static boolean privateURL(String raw) { return LANPolicy.privateURL(raw); }
    private static byte[] unhex(String value) throws Exception {if(!value.matches("[a-fA-F0-9]{64}"))throw new IOException("Full certificate fingerprint required.");byte[] b=new byte[32];for(int i=0;i<32;i++)b[i]=(byte)Integer.parseInt(value.substring(i*2,i*2+2),16);return b;}
    boolean paired(){return token!=null&&System.currentTimeMillis()/1000.0<expires;}
    private JSONObject send(String path,JSONObject body,boolean authenticated) throws Exception {
        if(base==null||fingerprint==null)throw new IOException("Not paired.");
        if(authenticated&&!paired())throw new IOException("Session expired.");
        byte[] expected=fingerprint.clone();
        X509TrustManager trust=new X509TrustManager(){public X509Certificate[] getAcceptedIssuers(){return new X509Certificate[0];}public void checkClientTrusted(X509Certificate[] c,String a)throws CertificateException{throw new CertificateException("No client trust.");}public void checkServerTrusted(X509Certificate[] c,String a)throws CertificateException{try{if(c==null||c.length==0)throw new CertificateException("No certificate.");c[0].checkValidity();byte[] actual=MessageDigest.getInstance("SHA-256").digest(c[0].getEncoded());if(!MessageDigest.isEqual(expected,actual))throw new CertificateException("Certificate pin mismatch.");}catch(GeneralSecurityException e){throw new CertificateException("Pinned certificate refused.",e);}}};
        SSLContext context=SSLContext.getInstance("TLSv1.2");context.init(null,new TrustManager[]{trust},new SecureRandom());
        URL endpoint=new URL(base.getProtocol(),base.getHost(),base.getPort(),path);
        HttpsURLConnection c=(HttpsURLConnection)endpoint.openConnection();c.setSSLSocketFactory(context.getSocketFactory());c.setHostnameVerifier((host,session)->host.equals(base.getHost()));c.setInstanceFollowRedirects(false);c.setConnectTimeout(7000);c.setReadTimeout(10000);c.setRequestMethod("POST");c.setRequestProperty("Content-Type","application/json");c.setRequestProperty("Cache-Control","no-store");if(authenticated)c.setRequestProperty("Authorization","Bearer "+token);
        byte[] raw=body.toString().getBytes(StandardCharsets.UTF_8);c.setFixedLengthStreamingMode(raw.length);c.setDoOutput(true);
        try {try(OutputStream out=c.getOutputStream()){out.write(raw);}int status=c.getResponseCode();InputStream input=status>=200&&status<300?c.getInputStream():c.getErrorStream();if(input==null)throw new IOException("LAN request refused.");ByteArrayOutputStream out=new ByteArrayOutputStream();try(InputStream in=input){byte[] b=new byte[4096];for(int n;(n=in.read(b))!=-1;){if(out.size()+n>262144)throw new IOException("Oversize response.");out.write(b,0,n);}}JSONObject response=new JSONObject(out.toString(StandardCharsets.UTF_8.name()));if(status!=200&&status!=202)throw new IOException("Laptop request refused or expired.");return response;}finally{c.disconnect();}
    }
    synchronized JSONObject pair(JSONObject params)throws Exception {
        String host=params.getString("host"),pin=params.getString("pin").toLowerCase(java.util.Locale.ROOT),secret=params.getString("code");if(params.length()!=3||!privateURL(host)||!secret.matches("[a-f0-9]{32}"))throw new IOException("Use a private LAN HTTPS URL and exact native code.");
        clear();base=new URL(host);fingerprint=unhex(pin);code=secret;
        JSONObject reply=send("/v1/pair",new JSONObject().put("code",code).put("platform","android"),false);ticket=reply.getString("ticket");return new JSONObject().put("status","Approve this Android phone on the laptop, then finish pairing.");
    }
    synchronized JSONObject finish()throws Exception {if(ticket==null||code==null)throw new IOException("Start pairing first.");JSONObject reply=send("/v1/pair/finish",new JSONObject().put("ticket",ticket).put("code",code),false);if("paired".equals(reply.optString("status"))){String t=reply.getString("token");if(!t.matches("[a-f0-9]{64}"))throw new IOException("Invalid token.");token=t;expires=reply.getDouble("expiresAt");code=null;ticket=null;}return new JSONObject().put("status",paired()?"Paired. Writes still require laptop confirmation.":"Awaiting laptop confirmation.");}
    synchronized JSONObject state()throws Exception {return send("/v1/state",new JSONObject(),true);}
    static boolean validCommand(JSONObject body){try{
        if(body.length()!=2||!(body.opt("operation") instanceof String)||!(body.opt("params") instanceof JSONObject))return false;
        String op=body.getString("operation");JSONObject p=body.getJSONObject("params");
        if(op.equals("setVolume")){Object v=p.opt("value");if(p.length()!=1||!(v instanceof Number))return false;double n=((Number)v).doubleValue();return Double.isFinite(n)&&n>=0&&n<=100;}
        if(op.equals("applyTweak")||op.equals("restoreTweak"))return p.length()==1&&p.opt("id") instanceof String&&java.util.Arrays.asList("dock-autohide","dock-reveal","dock-scale","dock-launch","finder-path","finder-status","finder-hidden","file-extensions","scrollbars","dock-recents","finder-folders-first","natural-scroll","win-extensions","win-hidden","win-theme-dark").contains(p.getString("id"));
        return (op.equals("restoreAll")||op.equals("keepAwake"))&&p.length()==0;
    }catch(Exception e){return false;}}
    synchronized JSONObject command(JSONObject body)throws Exception {if(!validCommand(body))throw new IOException("Remote operation refused.");JSONObject reply=send("/v1/command",body,true);last=reply.getString("id");return new JSONObject().put("status","Request queued; approve it on the laptop within 90 seconds.");}
    synchronized JSONObject result()throws Exception {if(last==null)throw new IOException("No requested action.");return send("/v1/result",new JSONObject().put("id",last),true);}
    synchronized void disconnect(){try{if(paired())send("/v1/disconnect",new JSONObject(),true);}catch(Exception ignored){}finally{clear();}}
    void invalidate(){token=null;expires=0;}
    synchronized void clear(){base=null;fingerprint=null;code=null;ticket=null;token=null;last=null;expires=0;}
}
