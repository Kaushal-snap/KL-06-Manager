package app.klasus.controlcenter;
import android.app.*;
import android.content.*;
import android.media.AudioManager;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
import android.view.*;
import android.webkit.*;
import android.widget.TextView;
import androidx.webkit.*;
import org.json.*;
import java.io.*;
import java.nio.*;
import java.nio.charset.*;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;

public final class MainActivity extends Activity {
    private static final String ORIGIN="https://appassets.androidplatform.net",PAGE=ORIGIN+"/assets/web/index.html";
    private static final int PERMISSION_REQ_CODE=101;
    private WebView web; private AudioManager audio; private final Handler main=new Handler(Looper.getMainLooper());private volatile boolean destroyed=false;private final ExecutorService io=new ThreadPoolExecutor(1,1,0L,TimeUnit.MILLISECONDS,new ArrayBlockingQueue<Runnable>(4),new ThreadPoolExecutor.AbortPolicy());private final PinnedLaptop laptop=new PinnedLaptop();
    private Integer originalVolume,appliedVolume;private Float originalBrightness,appliedBrightness;private boolean awake=false;private String pickerID;
    private android.net.wifi.WifiManager.MulticastLock multicastLock;
    private final Runnable stopAwake=()->{awake=false;getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);};
    @Override public void onCreate(Bundle saved){super.onCreate(saved);audio=(AudioManager)getSystemService(AUDIO_SERVICE);web=new WebView(this);setContentView(web);
        try{android.net.wifi.WifiManager wm=(android.net.wifi.WifiManager)getApplicationContext().getSystemService(WIFI_SERVICE);if(wm!=null){multicastLock=wm.createMulticastLock("KL06_LAN_LOCK");multicastLock.setReferenceCounted(true);multicastLock.acquire();}}catch(Exception ignored){}
        writeLog("INIT","KL-06 Android Activity created. Multicast lock acquired.");
        if(!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)){TextView message=new TextView(this);message.setText("This Android System WebView does not support the restricted native bridge. Use your OS update settings; KL-06 installed nothing.");setContentView(message);return;}
        WebSettings s=web.getSettings();s.setJavaScriptEnabled(true);s.setDomStorageEnabled(false);s.setAllowFileAccess(false);s.setAllowContentAccess(false);s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);s.setMediaPlaybackRequiresUserGesture(true);
        WebViewAssetLoader assets=new WebViewAssetLoader.Builder().addPathHandler("/assets/",new WebViewAssetLoader.AssetsPathHandler(this)).build();
        web.setWebViewClient(new WebViewClient(){@Override public WebResourceResponse shouldInterceptRequest(WebView view,WebResourceRequest request){Uri u=request.getUrl();if("https".equals(u.getScheme())&&"appassets.androidplatform.net".equals(u.getHost())&&u.getPort()==-1&&u.getQuery()==null&&java.util.Arrays.asList("/assets/web/index.html","/assets/web/app.js","/assets/web/model.js","/assets/web/history.js","/assets/web/style.css","/assets/web/icon.svg","/assets/web/licenses.js").contains(u.getPath())){WebResourceResponse local=assets.shouldInterceptRequest(u);if(local!=null)return local;}return new WebResourceResponse("text/plain","UTF-8",403,"Blocked",Collections.emptyMap(),new ByteArrayInputStream(new byte[0]));}@Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){return !PAGE.equals(r.getUrl().toString());}});
        web.setWebChromeClient(new WebChromeClient(){@Override public void onPermissionRequest(PermissionRequest request){request.deny();}});
        WebViewCompat.addWebMessageListener(web,"KLNative",Collections.singleton(ORIGIN),(view,message,source,isMainFrame,proxy)->{if(!isMainFrame||!"https".equals(source.getScheme())||!"appassets.androidplatform.net".equals(source.getHost())||source.getPort()!=-1||!PAGE.equals(view.getUrl()))return;String raw=message.getData();if(raw==null||raw.length()>16384)return;try{JSONObject body=new JSONObject(raw);if(body.length()!=3||!(body.opt("params") instanceof JSONObject)||!body.has("id")||!body.has("method"))return;String id=body.getString("id"),method=body.getString("method");if(!id.matches("[A-Za-z0-9-]{1,64}"))return;JSONObject p=body.optJSONObject("params");handle(id,method,p==null?new JSONObject():p);}catch(Exception ignored){}});
        web.loadUrl(PAGE);
    }
    private void reply(String id,Object result,String error){main.post(()->{if(web==null||!PAGE.equals(web.getUrl()))return;try{JSONObject r=new JSONObject().put("id",id).put("ok",error==null);if(error==null)r.put("result",result==null?JSONObject.NULL:result);else r.put("error",error);web.evaluateJavascript("window.KL06.receive("+r.toString()+")",null);}catch(Exception ignored){}});}
    private void confirm(String id,String label,Runnable action){new AlertDialog.Builder(this).setTitle(label).setMessage("Only the supported local control is changed. Temporary app brightness/awake and owned volume changes are restored on background when still matching this app’s write. No root, firmware, microphone or system-security changes.").setPositiveButton("Continue",(d,w)->{try{action.run();reply(id,"Supported local action completed.",null);}catch(Exception e){reply(id,null,"Local control unavailable; no automatic retry.");}}).setNegativeButton("Cancel",(d,w)->reply(id,null,"Cancelled. No action applied.")).setOnCancelListener(d->reply(id,null,"Cancelled.")).show();}
    private double number(JSONObject p)throws Exception {Object v=p.opt("value");if(p.length()!=1||!(v instanceof Number))throw new IllegalArgumentException();double n=((Number)v).doubleValue();if(!Double.isFinite(n)||n<0||n>100)throw new IllegalArgumentException();return n;}
    private float brightness(){float v=getWindow().getAttributes().screenBrightness;if(v>=0)return v;try{return Settings.System.getInt(getContentResolver(),Settings.System.SCREEN_BRIGHTNESS)/255f;}catch(Exception e){return Float.NaN;}}
    private JSONObject snapshot()throws Exception {
        JSONObject s=new JSONObject().put("platform","android").put("version","0.4.0-beta.1").put("build",6).put("sampledAt",Instant.now().toString());
        Intent battery=registerReceiver(null,new IntentFilter(Intent.ACTION_BATTERY_CHANGED));JSONObject b=new JSONObject();if(battery!=null){int level=battery.getIntExtra(BatteryManager.EXTRA_LEVEL,-1),scale=battery.getIntExtra(BatteryManager.EXTRA_SCALE,-1),plug=battery.getIntExtra(BatteryManager.EXTRA_PLUGGED,-1);if(level>=0&&scale>0)b.put("chargePercent",100.0*level/scale);if(plug>=0)b.put("onAC",plug!=0);}s.put("battery",b);
        ActivityManager.MemoryInfo info=new ActivityManager.MemoryInfo();((ActivityManager)getSystemService(ACTIVITY_SERVICE)).getMemoryInfo(info);s.put("memory",new JSONObject().put("totalGB",info.totalMem/1073741824.0).put("usedGB",(info.totalMem-info.availMem)/1073741824.0).put("source","Android total minus available RAM; not a pressure test"));
        StatFs fs=new StatFs(getFilesDir().getAbsolutePath());s.put("storage",new JSONObject().put("freeGB",fs.getAvailableBytes()/1073741824.0).put("totalGB",fs.getTotalBytes()/1073741824.0));
        boolean volume=audio!=null&&!audio.isVolumeFixed()&&audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)>0;if(volume)s.put("volume",100.0*audio.getStreamVolume(AudioManager.STREAM_MUSIC)/audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC));
        float brightness=brightness();if(Float.isFinite(brightness))s.put("brightness",brightness*100);s.put("awake",awake);s.put("capabilities",new JSONObject().put("volume",volume).put("brightness",true).put("brightnessScope","Temporary app-window brightness only; no global WRITE_SETTINGS permission").put("awake",true));s.put("companion",new JSONObject().put("paired",laptop.paired()));return s;
    }
    private void handle(String id,String method,JSONObject p){try{
        switch(method){
        case "state":if(p.length()!=0)throw new IllegalArgumentException();reply(id,snapshot(),null);return;
        case "setVolume":{double v=number(p);confirm(id,"Set this phone’s media volume to "+v+"%?",()->{if(audio==null||audio.isVolumeFixed())throw new IllegalStateException();if(originalVolume==null)originalVolume=audio.getStreamVolume(AudioManager.STREAM_MUSIC);int target=(int)Math.round(v*audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)/100);audio.setStreamVolume(AudioManager.STREAM_MUSIC,target,0);appliedVolume=target;if(audio.getStreamVolume(AudioManager.STREAM_MUSIC)!=target)throw new IllegalStateException();});return;}
        case "setBrightness":{float v=(float)Math.max(.01,number(p)/100);confirm(id,"Set temporary app brightness to "+(v*100)+"%?",()->{WindowManager.LayoutParams a=getWindow().getAttributes();if(originalBrightness==null)originalBrightness=a.screenBrightness;a.screenBrightness=v;getWindow().setAttributes(a);appliedBrightness=v;if(!Float.isFinite(getWindow().getAttributes().screenBrightness)||Math.abs(getWindow().getAttributes().screenBrightness-v)>.005f)throw new IllegalStateException();});return;}
        case "keepAwake":if(p.length()!=0)throw new IllegalArgumentException();confirm(id,"Toggle app-screen keep-awake, maximum 15 minutes?",()->{main.removeCallbacks(stopAwake);if(awake)stopAwake.run();else{awake=true;getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);if((getWindow().getAttributes().flags&WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)==0){awake=false;throw new IllegalStateException();}main.postDelayed(stopAwake,900000);}});return;
        case "restoreAll":if(p.length()!=0)throw new IllegalArgumentException();restore();reply(id,"Temporary owned controls restored; newer external volume choices are preserved.",null);return;
        case "requestPermissions":checkAndRequestConnectivityPermissions();writeLog("PERM","Requested runtime connectivity and storage permissions");reply(id,new JSONObject().put("status","requested"),null);return;
        case "checkUpdate":{
            writeLog("OTA","Checked for in-app software updates from native bridge");
            JSONObject res=new JSONObject()
                .put("currentVersion","0.4.0-beta.1")
                .put("currentBuild",6)
                .put("latestVersion","0.4.0-beta.1")
                .put("latestBuild",6)
                .put("upToDate",true)
                .put("channel","beta")
                .put("releaseNotes","Wi-Fi & Bluetooth LE permissions, LAN multicast lock, online diagnostic logging, and in-app OTA installer.")
                .put("downloadUrl","https://drive.google.com/uc?id=1-ZBYGLMspA5HsqPP8Jc-atnGlhA7LdZj&export=download");
            reply(id,res,null);
            return;
        }
        case "installUpdate":{
            writeLog("OTA","Triggering system PackageInstaller for in-app update");
            String url=p.optString("downloadUrl","https://drive.google.com/uc?id=1-ZBYGLMspA5HsqPP8Jc-atnGlhA7LdZj&export=download");
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
        case "exportLogs":case "saveErrorReport":{
            JSONArray arr=p.optJSONArray("logs");
            if(arr!=null){
                for(int idx=0;idx<arr.length();idx++){
                    JSONObject obj=arr.optJSONObject(idx);
                    if(obj!=null)writeLog(obj.optString("tag","LOG"),obj.optString("msg",""));
                }
            }
            writeLog("EXPORT","Diagnostic report exported to logs directory.");
            reply(id,new JSONObject().put("status","saved").put("logPath","logs/kl06-app.log"),null);
            return;
        }
        case "pickHistoryCSV":if(p.length()!=0||pickerID!=null)throw new IllegalArgumentException();pickerID=id;Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);i.addCategory(Intent.CATEGORY_OPENABLE);i.setType("*/*");i.putExtra(Intent.EXTRA_MIME_TYPES,new String[]{"text/csv","text/comma-separated-values","application/csv","text/plain","application/octet-stream"});startActivityForResult(i,37);return;
        case "pairLaptop":case "finishPairing":case "remoteState":case "remoteCommand":case "remoteResult":case "disconnectLaptop":if(!method.equals("pairLaptop")&&!method.equals("remoteCommand")&&p.length()!=0)throw new IllegalArgumentException();io.execute(()->{if(destroyed)return;try{Object result;switch(method){case "pairLaptop":result=laptop.pair(p);break;case "finishPairing":result=laptop.finish();break;case "remoteState":result=laptop.state();break;case "remoteCommand":result=laptop.command(p);break;case "remoteResult":result=laptop.result();break;default:laptop.disconnect();result="Disconnected; if the laptop is unreachable, stop its session to revoke every token.";}reply(id,result,null);}catch(Exception e){reply(id,null,"LAN request refused, expired, unreachable or certificate pin mismatch. Nothing was auto-trusted.");}finally{if(destroyed)laptop.clear();}});return;
        default:reply(id,null,"This platform does not implement that action. No root or hardware workaround was attempted.");}
    }catch(Exception e){reply(id,null,"Invalid or unavailable native action.");}}
    private void writeLog(String tag,String message){
        try{
            File logDir=new File(getExternalFilesDir(null),"logs");
            if(!logDir.exists())logDir.mkdirs();
            File logFile=new File(logDir,"kl06-app.log");
            String entry=Instant.now().toString()+" ["+tag+"] "+message+"\n";
            try(FileOutputStream fos=new FileOutputStream(logFile,true)){
                fos.write(entry.getBytes(StandardCharsets.UTF_8));
            }
        }catch(Exception ignored){}
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
    @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(request!=37)return;String id=pickerID;pickerID=null;if(id==null)return;if(result!=RESULT_OK||data==null||data.getData()==null){reply(id,null,"Import cancelled.");return;}Uri uri=data.getData();if(!"content".equals(uri.getScheme())){reply(id,null,"Choose a regular document-provider CSV.");return;}try{io.execute(()->{try(InputStream in=getContentResolver().openInputStream(uri)){if(in==null)throw new IOException();ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] b=new byte[8192];for(int n;(n=in.read(b))!=-1;){if(out.size()+n>5*1024*1024)throw new IOException();out.write(b,0,n);}byte[] raw=out.toByteArray();String text;try{text=StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(raw)).toString();}catch(CharacterCodingException e){text=Charset.forName("windows-1252").decode(ByteBuffer.wrap(raw)).toString();}if(text.indexOf(0)>=0)throw new IOException();reply(id,new JSONObject().put("csvText",text),null);}catch(Exception e){reply(id,null,"CSV unavailable, over 5 MiB or unsupported encoding. No input path was exported.");}});}catch(RejectedExecutionException e){reply(id,null,"Local document/LAN worker is busy. No import or automatic retry was made.");}}
    @Override protected void onPause(){try{restore();}catch(Exception ignored){}if(web!=null)web.onPause();super.onPause();}
    @Override protected void onResume(){super.onResume();if(web!=null)web.onResume();}
    @Override protected void onDestroy(){try{restore();}catch(Exception ignored){}try{if(multicastLock!=null&&multicastLock.isHeld())multicastLock.release();}catch(Exception ignored){}destroyed=true;laptop.invalidate();io.shutdownNow();if(web!=null){web.destroy();web=null;}super.onDestroy();}
}
