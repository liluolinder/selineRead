package dev.canghui.android;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Window;
import android.view.WindowManager;

/** Launcher for the Android Draw IR renderer demo. */
public final class CangHuiDrawIrDemoActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        CangHuiDrawIrView view = new CangHuiDrawIrView(this);
        view.setSceneJson(demoSceneJson());
        setContentView(view);
    }

    private static String demoSceneJson() {
        // A small CangHui native-scene v0 report that mirrors an ExplorerX
        // dashboard card. The renderer is protocol-driven; product state can
        // later be produced by Cangjie on hosts with a Cangjie Android runtime.
        return "{"
            + "\"protocol\":\"canghui.native-scene.v0\","
            + "\"name\":\"explorerx.android.demo\","
            + "\"ok\":true,"
            + "\"frames\":[{"
            + "\"width\":1080,\"height\":2160,\"inputCount\":0,\"selectedAction\":\"\","
            + "\"drawIr\":["
            + "{\"kind\":\"scene.begin\",\"scope\":\"demo\",\"data\":{\"width\":1080,\"height\":2160,\"color\":{\"r\":239,\"g\":243,\"b\":248,\"a\":255}}},"
            + "{\"kind\":\"paint.fill-rounded-rect\",\"scope\":\"demo\",\"data\":{\"x\":36,\"y\":80,\"width\":1008,\"height\":140,\"radius\":16,\"color\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255}}},"
            + "{\"kind\":\"text\",\"scope\":\"demo\",\"data\":{\"text\":\"ExplorerX Android\",\"x\":72,\"y\":106,\"pointSize\":34,\"bold\":true,\"color\":{\"r\":28,\"g\":35,\"b\":46,\"a\":255}}},"
            + "{\"kind\":\"text\",\"scope\":\"demo\",\"data\":{\"text\":\"CangHui Draw IR -> Android Canvas\",\"x\":72,\"y\":158,\"pointSize\":20,\"bold\":false,\"color\":{\"r\":104,\"g\":115,\"b\":130,\"a\":255}}},"
            + "{\"kind\":\"paint.fill-rounded-rect\",\"scope\":\"demo\",\"data\":{\"x\":36,\"y\":260,\"width\":1008,\"height\":180,\"radius\":16,\"color\":{\"r\":46,\"g\":120,\"b\":198,\"a\":255}}},"
            + "{\"kind\":\"text\",\"scope\":\"demo\",\"data\":{\"text\":\"已发现节点  3\",\"x\":72,\"y\":310,\"pointSize\":40,\"bold\":true,\"color\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255}}},"
            + "{\"kind\":\"text\",\"scope\":\"demo\",\"data\":{\"text\":\"HTTP / SoonLink\",\"x\":72,\"y\":376,\"pointSize\":22,\"bold\":false,\"color\":{\"r\":230,\"g\":240,\"b\":252,\"a\":255}}},"
            + "{\"kind\":\"paint.fill-rounded-rect\",\"scope\":\"demo\",\"data\":{\"x\":36,\"y\":480,\"width\":1008,\"height\":120,\"radius\":12,\"color\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255}}},"
            + "{\"kind\":\"paint.line\",\"scope\":\"demo\",\"data\":{\"x1\":72,\"y1\":550,\"x2\":1008,\"y2\":550,\"width\":2,\"color\":{\"r\":216,\"g\":223,\"b\":232,\"a\":255}}},"
            + "{\"kind\":\"text\",\"scope\":\"demo\",\"data\":{\"text\":\"传输概览\",\"x\":72,\"y\":508,\"pointSize\":24,\"bold\":true,\"color\":{\"r\":28,\"g\":35,\"b\":46,\"a\":255}}},"
            + "{\"kind\":\"paint.fill-rounded-rect\",\"scope\":\"demo\",\"data\":{\"x\":72,\"y\":560,\"width\":600,\"height\":18,\"radius\":9,\"color\":{\"r\":216,\"g\":223,\"b\":232,\"a\":255}}},"
            + "{\"kind\":\"paint.fill-rounded-rect\",\"scope\":\"demo\",\"data\":{\"x\":72,\"y\":560,\"width\":408,\"height\":18,\"radius\":9,\"color\":{\"r\":46,\"g\":120,\"b\":198,\"a\":255}}},"
            + "{\"kind\":\"text\",\"scope\":\"demo\",\"data\":{\"text\":\"68%\",\"x\":330,\"y\":548,\"pointSize\":14,\"bold\":true,\"color\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255}}}"
            + "]}]}";
    }
}
