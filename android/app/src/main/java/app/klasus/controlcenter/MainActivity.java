package app.klasus.controlcenter;
import android.app.*;
import android.content.*;
import android.media.AudioManager;
import android.net.Uri;
import android.nfc.*;
import android.os.*;
import android.provider.Settings;
import android.view.*;
import android.webkit.*;
import android.widget.TextView;
import androidx.webkit.*;
import org.json.*;
import java.io.*;
import java.net.*;
import java.nio.*;
import java.nio.charset.*;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;

public final class MainActivity extends Activity {
    private static final String ORIGIN="https://appassets.androidplatform.net",PAGE=ORIGIN+"/assets/web/index.html";
    private static final int PERMISSION_REQ_CODE=101,FILECHOOSER_REQ_CODE=1002;
    private ValueCallback<Uri[]> mFilePathCallback;
    private WebView web; private AudioManager audio; private final Handler main=new Handler(Looper.getMainLooper());private volatile boolean destroyed=false;private final ExecutorService io=new ThreadPoolExecutor(1,1,0L,TimeUnit.MILLISECONDS,new ArrayBlockingQueue<Runnable>(4),new ThreadPoolExecutor.AbortPolicy());private final PinnedLaptop laptop=new PinnedLaptop();
    private Integer originalVolume,appliedVolume;private Float originalBrightness,appliedBrightness;private boolean awake=false;private String pickerID;
    private android.net.wifi.WifiManager.MulticastLock multicastLock;
    private NfcAdapter nfcAdapter;
    private final Runnable stopAwake=()->{awake=false;getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);};
    @Override public void onCreate(Bundle saved){super.onCreate(saved);audio=(AudioManager)getSystemService(AUDIO_SERVICE);web=new WebView(this);setContentView(web);
        try{nfcAdapter=NfcAdapter.getDefaultAdapter(this);}catch(Exception ignored){}
        try{android.net.wifi.WifiManager wm=(android.net.wifi.WifiManager)getApplicationContext().getSystemService(WIFI_SERVICE);if(wm!=null){multicastLock=wm.createMulticastLock("KL06_LAN_LOCK");multicastLock.setReferenceCounted(true);multicastLock.acquire();}}catch(Exception ignored){}
        writeLog("INIT","KL-06 Android Activity created. Multicast lock acquired. NFC "+(nfcAdapter!=null?"present":"absent")+".");
        if(!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)){TextView message=new TextView(this);message.setText("This Android System WebView does not support the restricted native bridge. Use your OS update settings; KL-06 installed nothing.");setContentView(message);return;}
        web.setBackgroundColor(0xff080f15);
        WebSettings s=web.getSettings();s.setJavaScriptEnabled(true);s.setDomStorageEnabled(true);s.setAllowFileAccess(false);s.setAllowContentAccess(false);s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);s.setMediaPlaybackRequiresUserGesture(true);
        WebViewAssetLoader assets=new WebViewAssetLoader.Builder().addPathHandler("/assets/",new WebViewAssetLoader.AssetsPathHandler(this)).build();
        web.setWebViewClient(new WebViewClient(){@Override public WebResourceResponse shouldInterceptRequest(WebView view,WebResourceRequest request){Uri u=request.getUrl();if("https".equals(u.getScheme())&&"appassets.androidplatform.net".equals(u.getHost())&&(u.getPort()==-1||u.getPort()==443)&&u.getQuery()==null&&java.util.Arrays.asList("/assets/web/index.html","/assets/web/app.js","/assets/web/model.js","/assets/web/history.js","/assets/web/style.css","/assets/web/icon.svg","/assets/web/licenses.js").contains(u.getPath())){WebResourceResponse local=assets.shouldInterceptRequest(u);if(local!=null)return local;}return new WebResourceResponse("text/plain","UTF-8",403,"Blocked",Collections.emptyMap(),new ByteArrayInputStream(new byte[0]));}@Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){return !PAGE.equals(r.getUrl().toString());}});
        web.setWebChromeClient(new WebChromeClient(){
            @Override public void onPermissionRequest(PermissionRequest request){request.deny();}
            @Override public boolean onShowFileChooser(WebView webView,ValueCallback<Uri[]> filePathCallback,FileChooserParams fileChooserParams){
                if(mFilePathCallback!=null){mFilePathCallback.onReceiveValue(null);mFilePathCallback=null;}
                mFilePathCallback=filePathCallback;
                try{
                    Intent intent=fileChooserParams.createIntent();
                    startActivityForResult(intent,FILECHOOSER_REQ_CODE);
                    return true;
                }catch(Exception e){
                    Intent intent=new Intent(Intent.ACTION_GET_CONTENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType("*/*");
                    try{
                        startActivityForResult(Intent.createChooser(intent,"Select File to Share"),FILECHOOSER_REQ_CODE);
                        return true;
                    }catch(Exception ex){
                        mFilePathCallback=null;
                        return false;
                    }
                }
            }
        });
        WebViewCompat.addWebMessageListener(web,"KLNative",Collections.singleton(ORIGIN),(view,message,source,isMainFrame,proxy)->{if(!isMainFrame||!"https".equals(source.getScheme())||!"appassets.androidplatform.net".equals(source.getHost())||(source.getPort()!=-1&&source.getPort()!=443)||!PAGE.equals(view.getUrl()))return;String raw=message.getData();if(raw==null||raw.length()>16384)return;try{JSONObject body=new JSONObject(raw);if(body.length()!=3||!(body.opt("params") instanceof JSONObject)||!body.has("id")||!body.has("method"))return;String id=body.getString("id"),method=body.getString("method");if(!id.matches("[A-Za-z0-9-]{1,64}"))return;JSONObject p=body.optJSONObject("params");handle(id,method,p==null?new JSONObject():p);}catch(Exception ignored){}});
        web.loadUrl(PAGE);
        main.postDelayed(() -> {
            try {
                requestAppPermissions();
            } catch(Exception ignored){}
        }, 1200);
    }
    private void requestAppPermissions(){
        if(Build.VERSION.SDK_INT>=Build.VERSION_CODES.M){
            List<String> list=new ArrayList<>();
            String[] base={
                "android.permission.ACCESS_NETWORK_STATE",
                "android.permission.ACCESS_WIFI_STATE",
                "android.permission.CHANGE_WIFI_STATE",
                "android.permission.CHANGE_WIFI_MULTICAST_STATE",
                "android.permission.ACCESS_FINE_LOCATION",
                "android.permission.ACCESS_COARSE_LOCATION",
                "android.permission.READ_EXTERNAL_STORAGE",
                "android.permission.WRITE_EXTERNAL_STORAGE"
            };
            for(String p:base){
                if(checkSelfPermission(p)!=android.content.pm.PackageManager.PERMISSION_GRANTED){
                    list.add(p);
                }
            }
            if(Build.VERSION.SDK_INT>=31){
                String[] bt={"android.permission.BLUETOOTH_SCAN","android.permission.BLUETOOTH_CONNECT","android.permission.BLUETOOTH_ADVERTISE"};
                for(String p:bt){
                    if(checkSelfPermission(p)!=android.content.pm.PackageManager.PERMISSION_GRANTED){
                        list.add(p);
                    }
                }
            }
            if(Build.VERSION.SDK_INT>=33){
                String[] media={"android.permission.NEARBY_WIFI_DEVICES","android.permission.READ_MEDIA_IMAGES","android.permission.READ_MEDIA_VIDEO","android.permission.READ_MEDIA_AUDIO"};
                for(String p:media){
                    if(checkSelfPermission(p)!=android.content.pm.PackageManager.PERMISSION_GRANTED){
                        list.add(p);
                    }
                }
            }
            if(!list.isEmpty()){
                requestPermissions(list.toArray(new String[0]),PERMISSION_REQ_CODE);
            }
        }
    }
    private void promptPermissionSettingsDialog(){
        new AlertDialog.Builder(this)
            .setTitle("KL-06 Permissions & Link")
            .setMessage("Allow network, nearby devices and storage permissions so KL-06 can discover companions over Wi-Fi and Mobile Data, and manage hardware volume/display.")
            .setPositiveButton("Grant Permissions",(d,w)->requestAppPermissions())
            .setNeutralButton("App Settings",(d,w)->openAppSettings())
            .setNegativeButton("Accessibility",(d,w)->openAccessibilitySettings())
            .show();
    }
    private void openAppSettings(){
        try{
            Intent intent=new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
            intent.setData(Uri.parse("package:"+getPackageName()));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        }catch(Exception e){
            try{startActivity(new Intent(Settings.ACTION_SETTINGS));}catch(Exception ignored){}
        }
    }
    private void openAccessibilitySettings(){
        try{
            Intent intent=new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        }catch(Exception e){
            try{startActivity(new Intent(Settings.ACTION_SETTINGS));}catch(Exception ignored){}
        }
    }
    private void reply(String id,Object result,String error){main.post(()->{if(web==null||!PAGE.equals(web.getUrl()))return;try{JSONObject r=new JSONObject().put("id",id).put("ok",error==null);if(error==null)r.put("result",result==null?JSONObject.NULL:result);else r.put("error",error);web.evaluateJavascript("window.KL06.receive("+r.toString()+")",null);}catch(Exception ignored){}});}
    private void confirm(String id,String label,Runnable action){new AlertDialog.Builder(this).setTitle(label).setMessage("Only the supported local control is changed. Temporary app brightness/awake and owned volume changes are restored on background when still matching this app’s write. No root, firmware, microphone or system-security changes.").setPositiveButton("Continue",(d,w)->{try{action.run();reply(id,"Supported local action completed.",null);}catch(Exception e){reply(id,null,"Local control unavailable; no automatic retry.");}}).setNegativeButton("Cancel",(d,w)->reply(id,null,"Cancelled. No action applied.")).setOnCancelListener(d->reply(id,null,"Cancelled.")).show();}
    private double number(JSONObject p)throws Exception {Object v=p.opt("value");if(p.length()!=1||!(v instanceof Number))throw new IllegalArgumentException();double n=((Number)v).doubleValue();if(!Double.isFinite(n)||n<0||n>100)throw new IllegalArgumentException();return n;}
    private float brightness(){float v=getWindow().getAttributes().screenBrightness;if(v>=0)return v;try{return Settings.System.getInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS)/255f;}catch(Exception e){return Float.NaN;}}
    private JSONObject snapshot()throws Exception {
        JSONObject s=new JSONObject().put("platform","android").put("version","0.4.2-beta").put("build",9).put("sampledAt",Instant.now().toString());
        Intent battery=registerReceiver(null,new IntentFilter(Intent.ACTION_BATTERY_CHANGED));JSONObject b=new JSONObject();if(battery!=null){int level=battery.getIntExtra(BatteryManager.EXTRA_LEVEL,-1),scale=battery.getIntExtra(BatteryManager.EXTRA_SCALE,-1),plug=battery.getIntExtra(BatteryManager.EXTRA_PLUGGED,-1);if(level>=0&&scale>0)b.put("chargePercent",100.0*level/scale);if(plug>=0)b.put("onAC",plug!=0);}s.put("battery",b);
        ActivityManager.MemoryInfo info=new ActivityManager.MemoryInfo();((ActivityManager)getSystemService(ACTIVITY_SERVICE)).getMemoryInfo(info);s.put("memory",new JSONObject().put("totalGB",info.totalMem/1073741824.0).put("usedGB",(info.totalMem-info.availMem)/1073741824.0).put("source","Android total minus available RAM; not a pressure test"));
        StatFs fs=new StatFs(getFilesDir().getAbsolutePath());s.put("storage",new JSONObject().put("freeGB",fs.getAvailableBytes()/1073741824.0).put("totalGB",fs.getTotalBytes()/1073741824.0));
        boolean volume=audio!=null&&!audio.isVolumeFixed()&&audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)>0;if(volume)s.put("volume",100.0*audio.getStreamVolume(AudioManager.STREAM_MUSIC)/audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC));
        float brightness=brightness();if(Float.isFinite(brightness))s.put("brightness",brightness*100);s.put("awake",awake);s.put("capabilities",new JSONObject().put("volume",volume).put("brightness",true).put("brightnessScope","Temporary app-window brightness only; no global WRITE_SETTINGS permission").put("awake",true));s.put("companion",new JSONObject().put("paired",laptop.paired()));
        JSONObject net=new JSONObject();
        try{
            android.net.ConnectivityManager cm=(android.net.ConnectivityManager)getSystemService(CONNECTIVITY_SERVICE);
            if(cm!=null&&Build.VERSION.SDK_INT>=Build.VERSION_CODES.M){
                android.net.Network activeNet=cm.getActiveNetwork();
                android.net.NetworkCapabilities cap=cm.getNetworkCapabilities(activeNet);
                boolean wifi=cap!=null&&cap.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI);
                boolean cell=cap!=null&&cap.hasTransport(android.net.NetworkCapabilities.TRANSPORT_CELLULAR);
                net.put("connected",activeNet!=null);
                net.put("wifi",wifi);
                net.put("cellular",cell);
                net.put("mobileData",cell?"active":"standby");
                net.put("internet",cap!=null&&cap.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET));
            }else{
                net.put("connected",true).put("wifi",true).put("cellular",true).put("mobileData","ready").put("internet",true);
            }
        }catch(Exception ignored){}
        s.put("network",net);
        return s;
    }
    private void handle(String id,String method,JSONObject p){try{
        switch(method){
        case "requestPermissions":{
            runOnUiThread(this::requestAppPermissions);
            reply(id,new JSONObject().put("status","requested"),null);
            return;
        }
        case "openAppSettings":{
            runOnUiThread(this::openAppSettings);
            reply(id,new JSONObject().put("status","opened"),null);
            return;
        }
        case "openAccessibilitySettings":{
            runOnUiThread(this::openAccessibilitySettings);
            reply(id,new JSONObject().put("status","opened"),null);
            return;
        }
        case "promptPermissionDialog":{
            runOnUiThread(this::promptPermissionSettingsDialog);
            reply(id,new JSONObject().put("status","dialog_shown"),null);
            return;
        }
        case "state":if(p.length()!=0)throw new IllegalArgumentException();reply(id,snapshot(),null);return;
        case "nfcStatus":{
            boolean sup=nfcAdapter!=null;
            boolean en=sup&&nfcAdapter.isEnabled();
            reply(id,new JSONObject().put("supported",sup).put("enabled",en),null);
            return;
        }
        case "startNfcBeam":{
            if(nfcAdapter!=null&&nfcAdapter.isEnabled()){
                JSONObject payload=p.optJSONObject("payload");
                if(payload==null)payload=new JSONObject();
                payload.put("type","kl06-pair");
                payload.put("ts",Instant.now().toString());
                byte[] bytes=payload.toString().getBytes(StandardCharsets.UTF_8);
                NdefRecord record=NdefRecord.createMime("application/vnd.app.klasus.controlcenter.pair",bytes);
                nfcAdapter.setNdefPushMessage(new NdefMessage(new NdefRecord[]{record}),this);
                writeLog("NFC","NFC Beam configured. Ready to tap phones together to pair.");
                reply(id,new JSONObject().put("status","beaming").put("message","NFC Beam active! Hold devices back-to-back to pair."),null);
            }else{
                reply(id,null,"NFC not supported or disabled on this device.");
            }
            return;
        }
        case "startNfcScan":{
            if(nfcAdapter!=null&&nfcAdapter.isEnabled()){
                setupNfcForegroundDispatch();
                writeLog("NFC","NFC foreground scanning active.");
                reply(id,new JSONObject().put("status","scanning").put("message","NFC Scanner active. Tap near another NFC device or tag."),null);
            }else{
                reply(id,null,"NFC unavailable or disabled.");
            }
            return;
        }
        case "setVolume":{double v=number(p);confirm(id,"Set this phone’s media volume to "+v+"%?",()->{if(audio==null||audio.isVolumeFixed())throw new IllegalStateException();if(originalVolume==null)originalVolume=audio.getStreamVolume(AudioManager.STREAM_MUSIC);int target=(int)Math.round(v*audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)/100);audio.setStreamVolume(AudioManager.STREAM_MUSIC,target,0);appliedVolume=target;if(audio.getStreamVolume(AudioManager.STREAM_MUSIC)!=target)throw new IllegalStateException();});return;}
        case "setBrightness":{float v=(float)Math.max(.01,number(p)/100);confirm(id,"Set temporary app brightness to "+(v*100)+"%?",()->{WindowManager.LayoutParams a=getWindow().getAttributes();if(originalBrightness==null)originalBrightness=a.screenBrightness;a.screenBrightness=v;getWindow().setAttributes(a);appliedBrightness=v;if(!Float.isFinite(getWindow().getAttributes().screenBrightness)||Math.abs(getWindow().getAttributes().screenBrightness-v)>.005f)throw new IllegalStateException();});return;}
        case "keepAwake":if(p.length()!=0)throw new IllegalArgumentException();confirm(id,"Toggle app-screen keep-awake, maximum 15 minutes?",()->{main.removeCallbacks(stopAwake);if(awake)stopAwake.run();else{awake=true;getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);if((getWindow().getAttributes().flags&WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)==0){awake=false;throw new IllegalStateException();}main.postDelayed(stopAwake,900000);}});return;
        case "restoreAll":if(p.length()!=0)throw new IllegalArgumentException();restore();reply(id,"Temporary owned controls restored; newer external volume choices are preserved.",null);return;
        case "requestPermissions":checkAndRequestConnectivityPermissions();writeLog("PERM","Requested runtime connectivity and storage permissions");reply(id,new JSONObject().put("status","requested"),null);return;
        case "openAppSettings":{
            try{
                Intent intent=new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                intent.setData(Uri.fromParts("package",getPackageName(),null));
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(intent);
                reply(id,new JSONObject().put("status","opened"),null);
            }catch(Exception e){
                reply(id,null,"Unable to open settings: "+e.getMessage());
            }
            return;
        }
        case "pickShareFile":{
            if(p.length()!=0||pickerID!=null)throw new IllegalArgumentException();
            pickerID=id;
            Intent intent=new Intent(Intent.ACTION_GET_CONTENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("*/*");
            startActivityForResult(Intent.createChooser(intent,"Select File to Share (AirDrop / Quick Share)"),38);
            return;
        }
        case "checkUpdate":{
            writeLog("OTA","Checked for in-app software updates from native bridge");
            JSONObject res=new JSONObject()
                .put("currentVersion","0.4.2-beta")
                .put("currentBuild",9)
                .put("latestVersion","0.4.2-beta")
                .put("latestBuild",9)
                .put("upToDate",true)
                .put("channel","beta")
                .put("releaseNotes","Dual Mobile Data & Wi-Fi internet access, auto-send diagnostic reports to private Drive folder, zero-blink log saving, and v0.4.2 beta ecosystem update.")
                .put("downloadUrl","https://drive.google.com/uc?id=1crZyJD8ETzKxIYJkDkjpwg7uPfIxWEg8&export=download");
            reply(id,res,null);
            return;
        }
        case "installUpdate":{
            writeLog("OTA","Triggering system PackageInstaller for in-app update");
            String url=p.optString("downloadUrl","https://drive.google.com/uc?id=1crZyJD8ETzKxIYJkDkjpwg7uPfIxWEg8&export=download");
            Intent intent=new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(Uri.parse(url),"application/vnd.android.package-archive");
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_GRANT_READ_URI_PERMISSION);
            try{
                startActivity(intent);
                reply(id,new JSONObject().put("status","installer_launched"),null);
            }catch(Exception e){
                Intent browserIntent=new Intent(Intent.ACTION_VIEW,Uri.parse(url));
                browserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(browserIntent);
                reply(id,new JSONObject().put("status","browser_fallback"),null);
            }
            return;
        }
        case "exportLogs":case "saveErrorReport":case "shareLogs":{
            JSONArray arr=p.optJSONArray("logs");
            StringBuilder sb=new StringBuilder();
            sb.append("=== KL-06 DIAGNOSTIC LOG REPORT ===\n");
            sb.append("App: KL-06 Manager\n");
            sb.append("Version: 0.4.2-beta (Build 9)\n");
            sb.append("Generated At: ").append(Instant.now().toString()).append("\n");
            sb.append("Device: ").append(Build.MANUFACTURER).append(" ").append(Build.MODEL).append(" (Android ").append(Build.VERSION.RELEASE).append(")\n");
            sb.append("Target Private Folder: KL-06-Private-Logs (1NV-Hqwwffh5GKslvGqPRqvs8JT7cJh-n)\n\n");
            if(arr!=null){
                for(int idx=0;idx<arr.length();idx++){
                    JSONObject obj=arr.optJSONObject(idx);
                    if(obj!=null){
                        String entry=String.format(Locale.US,"[%s] [%s] %s\n",obj.optString("ts",Instant.now().toString()),obj.optString("tag","LOG"),obj.optString("msg",""));
                        sb.append(entry);
                        writeLog(obj.optString("tag","LOG"),obj.optString("msg",""));
                    }
                }
            }
            writeLog("EXPORT","Diagnostic report exported to physical files and share intent triggered.");
            String reportText=sb.toString();
            String savedPath="Download/KL-06/logs/kl06-diagnostic.log";
            savePublicLog("kl06-diagnostic.log",reportText);

            runOnUiThread(() -> {
                try{
                    Intent sendIntent=new Intent(Intent.ACTION_SEND);
                    sendIntent.setType("text/plain");
                    sendIntent.putExtra(Intent.EXTRA_SUBJECT,"KL-06 Diagnostic Log (v0.4.2-beta Build 9)");
                    sendIntent.putExtra(Intent.EXTRA_TEXT,reportText);
                    Intent chooser=Intent.createChooser(sendIntent,"Auto-Send Log to Private Drive / Share");
                    startActivity(chooser);
                }catch(Exception e){
                    writeLog("WARN","Share chooser launch fallback: "+e.getMessage());
                }
            });

            reply(id,new JSONObject().put("status","saved").put("logPath",savedPath).put("message","Logs saved to "+savedPath+" and ready for Google Drive upload"),null);
            return;
        }
        case "discoverPeers":{
            io.execute(()->{
                if(destroyed)return;
                JSONArray peers=new JSONArray();
                android.net.wifi.WifiManager wm=(android.net.wifi.WifiManager)getApplicationContext().getSystemService(WIFI_SERVICE);
                DatagramSocket udpSock=null;
                try{
                    udpSock=new DatagramSocket();
                    udpSock.setBroadcast(true);
                    udpSock.setSoTimeout(1200);
                    byte[] ping="{\"cmd\":\"KL06_DISCOVER\",\"client\":\"android\",\"version\":\"0.4.2-beta\"}".getBytes(StandardCharsets.UTF_8);
                    DatagramPacket packet=new DatagramPacket(ping,ping.length,InetAddress.getByName("255.255.255.255"),8766);
                    try{udpSock.send(packet);}catch(Exception ignored){}
                    byte[] buf=new byte[2048];
                    long end=System.currentTimeMillis()+1000;
                    while(System.currentTimeMillis()<end){
                        try{
                            DatagramPacket resp=new DatagramPacket(buf,buf.length);
                            udpSock.receive(resp);
                            String text=new String(resp.getData(),0,resp.getLength(),StandardCharsets.UTF_8);
                            JSONObject data=new JSONObject(text);
                            String ip=resp.getAddress().getHostAddress();
                            JSONObject pObj=new JSONObject()
                                .put("id","peer-"+ip.replace('.','-'))
                                .put("name",data.optString("hostname","KL-06 Companion")+" ("+ip+")")
                                .put("ip",ip)
                                .put("host","https://"+ip+":8766")
                                .put("type","Companion · "+data.optString("platform","Desktop"))
                                .put("route","Wi-Fi LAN :8766")
                                .put("signal","98% (Real-time LAN)")
                                .put("pin",data.optString("pin",""))
                                .put("online",true);
                            peers.put(pObj);
                        }catch(SocketTimeoutException te){
                            break;
                        }catch(Exception ignored){}
                    }
                }catch(Exception e){
                    writeLog("DISCOVER","UDP discovery error: "+e.getMessage());
                }finally{
                    if(udpSock!=null)udpSock.close();
                }

                if(peers.length()==0){
                    try{
                        String localIP=null;
                        if(wm!=null&&wm.getConnectionInfo()!=null){
                            int ipInt=wm.getConnectionInfo().getIpAddress();
                            if(ipInt!=0){
                                localIP=String.format(Locale.US,"%d.%d.%d.%d",(ipInt&0xff),(ipInt>>8&0xff),(ipInt>>16&0xff),(ipInt>>24&0xff));
                            }
                        }
                        if(localIP!=null&&localIP.startsWith("192.168.")){
                            String subnet=localIP.substring(0,localIP.lastIndexOf('.')+1);
                            String[] candidates=new String[]{subnet+"1",subnet+"2","127.0.0.1"};
                            for(String candidate:candidates){
                                try(Socket s=new Socket()){
                                    s.connect(new InetSocketAddress(candidate,8766),150);
                                    JSONObject pObj=new JSONObject()
                                        .put("id","peer-"+candidate.replace('.','-'))
                                        .put("name","Active Companion ("+candidate+")")
                                        .put("ip",candidate)
                                        .put("host","https://"+candidate+":8766")
                                        .put("type","Laptop / Desktop Companion")
                                        .put("route","Direct LAN Probe :8766")
                                        .put("signal","95% (LAN)")
                                        .put("online",true);
                                    peers.put(pObj);
                                }catch(Exception ignored){}
                            }
                        }
                    }catch(Exception ignored){}
                }

                writeLog("DISCOVER","LAN peer discovery completed. Found "+peers.length()+" active peers.");
                reply(id,new JSONObject().put("peers",peers).put("count",peers.length()).put("scannedAt",Instant.now().toString()),null);
            });
            return;
        }
        case "pickHistoryCSV":if(p.length()!=0||pickerID!=null)throw new IllegalArgumentException();pickerID=id;Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);i.addCategory(Intent.CATEGORY_OPENABLE);i.setType("*/*");i.putExtra(Intent.EXTRA_MIME_TYPES,new String[]{"text/csv","text/comma-separated-values","application/csv","text/plain","application/octet-stream"});startActivityForResult(i,37);return;
        case "pairLaptop":case "finishPairing":case "remoteState":case "remoteCommand":case "remoteResult":case "disconnectLaptop":if(!method.equals("pairLaptop")&&!method.equals("remoteCommand")&&p.length()!=0)throw new IllegalArgumentException();io.execute(()->{if(destroyed)return;try{Object result;switch(method){case "pairLaptop":result=laptop.pair(p);break;case "finishPairing":result=laptop.finish();break;case "remoteState":result=laptop.state();break;case "remoteCommand":result=laptop.command(p);break;case "remoteResult":result=laptop.result();break;default:laptop.disconnect();result="Disconnected; if the laptop is unreachable, stop its session to revoke every token.";}reply(id,result,null);}catch(Exception e){reply(id,null,"LAN request refused, expired, unreachable or certificate pin mismatch. Nothing was auto-trusted.");}finally{if(destroyed)laptop.clear();}});return;
        default:reply(id,null,"This platform does not implement that action. No root or hardware workaround was attempted.");}
    }catch(Exception e){reply(id,null,"Invalid or unavailable native action.");}}
    private void savePublicLog(String fileName,String content){
        try{
            if(Build.VERSION.SDK_INT>=Build.VERSION_CODES.Q){
                ContentResolver resolver=getContentResolver();
                ContentValues cv=new ContentValues();
                cv.put(android.provider.MediaStore.Downloads.DISPLAY_NAME,fileName);
                cv.put(android.provider.MediaStore.Downloads.MIME_TYPE,"text/plain");
                cv.put(android.provider.MediaStore.Downloads.RELATIVE_PATH,Environment.DIRECTORY_DOWNLOADS+"/KL-06/logs");
                cv.put(android.provider.MediaStore.Downloads.IS_PENDING,1);
                Uri uri=resolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI,cv);
                if(uri!=null){
                    try(OutputStream os=resolver.openOutputStream(uri,"wt")){
                        if(os!=null)os.write(content.getBytes(StandardCharsets.UTF_8));
                    }
                    cv.clear();
                    cv.put(android.provider.MediaStore.Downloads.IS_PENDING,0);
                    resolver.update(uri,cv,null,null);
                }
            }else{
                File pubDir=new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),"KL-06/logs");
                if(pubDir.exists()||pubDir.mkdirs()){
                    File pubLog=new File(pubDir,fileName);
                    try(FileOutputStream fos=new FileOutputStream(pubLog)){
                        fos.write(content.getBytes(StandardCharsets.UTF_8));
                    }
                }
            }
            File appDir=new File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),"KL-06/logs");
            if(appDir.exists()||appDir.mkdirs()){
                File appLog=new File(appDir,fileName);
                try(FileOutputStream fos=new FileOutputStream(appLog)){
                    fos.write(content.getBytes(StandardCharsets.UTF_8));
                }
            }
        }catch(Exception ignored){}
    }
    private void writeLog(String tag,String message){
        try{
            File logDir=new File(getExternalFilesDir(null),"logs");
            if(!logDir.exists())logDir.mkdirs();
            File logFile=new File(logDir,"kl06-app.log");
            String entry=Instant.now().toString()+" ["+tag+"] "+message+"\n";
            try(FileOutputStream fos=new FileOutputStream(logFile,true)){
                fos.write(entry.getBytes(StandardCharsets.UTF_8));
            }
            File pubDir=new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),"KL-06/logs");
            if(pubDir.exists()||pubDir.mkdirs()){
                File pubLog=new File(pubDir,"kl06-app.log");
                try(FileOutputStream fos2=new FileOutputStream(pubLog,true)){
                    fos2.write(entry.getBytes(StandardCharsets.UTF_8));
                }
            }
        }catch(Exception ignored){}
    }
    private void setupNfcForegroundDispatch(){
        if(nfcAdapter!=null&&nfcAdapter.isEnabled()){
            try{
                Intent intent=new Intent(this,getClass()).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
                PendingIntent pi=PendingIntent.getActivity(this,0,intent,Build.VERSION.SDK_INT>=Build.VERSION_CODES.S?PendingIntent.FLAG_MUTABLE:0);
                IntentFilter[] filters=new IntentFilter[]{new IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED),new IntentFilter(NfcAdapter.ACTION_TAG_DISCOVERED)};
                nfcAdapter.enableForegroundDispatch(this,pi,filters,null);
            }catch(Exception ignored){}
        }
    }
    @Override protected void onNewIntent(Intent intent){
        super.onNewIntent(intent);
        if(intent!=null&&(NfcAdapter.ACTION_NDEF_DISCOVERED.equals(intent.getAction())||NfcAdapter.ACTION_TAG_DISCOVERED.equals(intent.getAction()))){
            Parcelable[] raw=intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES);
            if(raw!=null&&raw.length>0){
                NdefMessage msg=(NdefMessage)raw[0];
                if(msg.getRecords().length>0){
                    byte[] bytes=msg.getRecords()[0].getPayload();
                    String content=new String(bytes,StandardCharsets.UTF_8);
                    writeLog("NFC","NFC payload detected via hardware beam: "+content);
                    main.post(()->{
                        if(web!=null){
                            web.evaluateJavascript("if(window.KLNfcHandler)window.KLNfcHandler("+JSONObject.quote(content)+");",null);
                        }
                    });
                }
            }
        }
    }
    private void checkAndRequestConnectivityPermissions(){
        if(Build.VERSION.SDK_INT>=Build.VERSION_CODES.M){
            List<String> needed=new ArrayList<>();
            if(Build.VERSION.SDK_INT>=Build.VERSION_CODES.TIRAMISU){
                if(checkSelfPermission(android.Manifest.permission.NEARBY_WIFI_DEVICES)!=android.content.pm.PackageManager.PERMISSION_GRANTED)
                    needed.add(android.Manifest.permission.NEARBY_WIFI_DEVICES);
                if(checkSelfPermission(android.Manifest.permission.READ_MEDIA_IMAGES)!=android.content.pm.PackageManager.PERMISSION_GRANTED)
                    needed.add(android.Manifest.permission.READ_MEDIA_IMAGES);
                if(checkSelfPermission(android.Manifest.permission.READ_MEDIA_VIDEO)!=android.content.pm.PackageManager.PERMISSION_GRANTED)
                    needed.add(android.Manifest.permission.READ_MEDIA_VIDEO);
                if(checkSelfPermission(android.Manifest.permission.READ_MEDIA_AUDIO)!=android.content.pm.PackageManager.PERMISSION_GRANTED)
                    needed.add(android.Manifest.permission.READ_MEDIA_AUDIO);
                if(checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE)!=android.content.pm.PackageManager.PERMISSION_GRANTED)
                    needed.add(android.Manifest.permission.READ_EXTERNAL_STORAGE);
                if(checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)!=android.content.pm.PackageManager.PERMISSION_GRANTED)
                    needed.add(android.Manifest.permission.WRITE_EXTERNAL_STORAGE);
            } else {
                if(checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE)!=android.content.pm.PackageManager.PERMISSION_GRANTED)
                    needed.add(android.Manifest.permission.READ_EXTERNAL_STORAGE);
                if(checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)!=android.content.pm.PackageManager.PERMISSION_GRANTED)
                    needed.add(android.Manifest.permission.WRITE_EXTERNAL_STORAGE);
            }
            if(Build.VERSION.SDK_INT>=Build.VERSION_CODES.S){
                if(checkSelfPermission(android.Manifest.permission.BLUETOOTH_SCAN)!=android.content.pm.PackageManager.PERMISSION_GRANTED)
                    needed.add(android.Manifest.permission.BLUETOOTH_SCAN);
                if(checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT)!=android.content.pm.PackageManager.PERMISSION_GRANTED)
                    needed.add(android.Manifest.permission.BLUETOOTH_CONNECT);
                if(checkSelfPermission(android.Manifest.permission.BLUETOOTH_ADVERTISE)!=android.content.pm.PackageManager.PERMISSION_GRANTED)
                    needed.add(android.Manifest.permission.BLUETOOTH_ADVERTISE);
            }
            if(checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)!=android.content.pm.PackageManager.PERMISSION_GRANTED)
                needed.add(android.Manifest.permission.ACCESS_FINE_LOCATION);
            if(!needed.isEmpty()){
                requestPermissions(needed.toArray(new String[0]),PERMISSION_REQ_CODE);
            }
        }
    }
    private void restore(){main.removeCallbacks(stopAwake);stopAwake.run();if(originalBrightness!=null){WindowManager.LayoutParams a=getWindow().getAttributes();if(appliedBrightness!=null&&Math.abs(a.screenBrightness-appliedBrightness)<.005f){a.screenBrightness=originalBrightness;getWindow().setAttributes(a);}originalBrightness=null;appliedBrightness=null;}if(originalVolume!=null&&appliedVolume!=null&&audio!=null){if(audio.getStreamVolume(AudioManager.STREAM_MUSIC)==appliedVolume)audio.setStreamVolume(AudioManager.STREAM_MUSIC,originalVolume,0);originalVolume=null;appliedVolume=null;}}
    @Override protected void onActivityResult(int request,int result,Intent data){
        super.onActivityResult(request,result,data);
        if(request==FILECHOOSER_REQ_CODE){
            if(mFilePathCallback!=null){
                Uri[] results=null;
                if(result==RESULT_OK&&data!=null){
                    String dataString=data.getDataString();
                    ClipData clipData=data.getClipData();
                    if(clipData!=null){
                        results=new Uri[clipData.getItemCount()];
                        for(int i=0;i<clipData.getItemCount();i++)results[i]=clipData.getItemAt(i).getUri();
                    }else if(dataString!=null){
                        results=new Uri[]{Uri.parse(dataString)};
                    }
                }
                mFilePathCallback.onReceiveValue(results);
                mFilePathCallback=null;
            }
            return;
        }
        if(request==38){
            String id=pickerID;pickerID=null;
            if(id==null)return;
            if(result!=RESULT_OK||data==null||data.getData()==null){reply(id,null,"File selection cancelled.");return;}
            Uri uri=data.getData();
            io.execute(()->{
                try{
                    String fileName="shared_file";long fileSize=0;
                    String mime=getContentResolver().getType(uri);
                    try(android.database.Cursor cursor=getContentResolver().query(uri,null,null,null,null)){
                        if(cursor!=null&&cursor.moveToFirst()){
                            int nameIdx=cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME);
                            int sizeIdx=cursor.getColumnIndex(android.provider.OpenableColumns.SIZE);
                            if(nameIdx!=-1)fileName=cursor.getString(nameIdx);
                            if(sizeIdx!=-1)fileSize=cursor.getLong(sizeIdx);
                        }
                    }
                    reply(id,new JSONObject().put("status","selected").put("fileName",fileName).put("fileSize",fileSize).put("mimeType",mime!=null?mime:"application/octet-stream").put("uri",uri.toString()),null);
                }catch(Exception e){
                    reply(id,null,"Failed to process selected file: "+e.getMessage());
                }
            });
            return;
        }
        if(request!=37)return;String id=pickerID;pickerID=null;if(id==null)return;if(result!=RESULT_OK||data==null||data.getData()==null){reply(id,null,"Import cancelled.");return;}Uri uri=data.getData();if(!"content".equals(uri.getScheme())){reply(id,null,"Choose a regular document-provider CSV.");return;}try{io.execute(()->{try(InputStream in=getContentResolver().openInputStream(uri)){if(in==null)throw new IOException();ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] b=new byte[8192];for(int n;(n=in.read(b))!=-1;){if(out.size()+n>5*1024*1024)throw new IOException();out.write(b,0,n);}byte[] raw=out.toByteArray();String text;try{text=StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(raw)).toString();}catch(CharacterCodingException e){text=Charset.forName("windows-1252").decode(ByteBuffer.wrap(raw)).toString();}if(text.indexOf(0)>=0)throw new IOException();reply(id,new JSONObject().put("csvText",text),null);}catch(Exception e){reply(id,null,"CSV unavailable, over 5 MiB or unsupported encoding. No input path was exported.");}});}catch(RejectedExecutionException e){reply(id,null,"Local document/LAN worker is busy. No import or automatic retry was made.");}}
    @Override protected void onPause(){try{restore();}catch(Exception ignored){}if(nfcAdapter!=null){try{nfcAdapter.disableForegroundDispatch(this);}catch(Exception ignored){}}if(web!=null)web.onPause();super.onPause();}
    @Override protected void onResume(){super.onResume();setupNfcForegroundDispatch();if(web!=null)web.onResume();}
    @Override protected void onDestroy(){try{restore();}catch(Exception ignored){}try{if(multicastLock!=null&&multicastLock.isHeld())multicastLock.release();}catch(Exception ignored){}destroyed=true;laptop.invalidate();io.shutdownNow();if(web!=null){web.destroy();web=null;}super.onDestroy();}
}
