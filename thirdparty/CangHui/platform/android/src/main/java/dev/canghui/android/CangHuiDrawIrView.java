package dev.canghui.android;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.util.AttributeSet;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Android Canvas renderer for CangHui native-scene Draw IR (v0).
 *
 * This is the Android expression counterpart of the iOS
 * CangHuiNativeSceneSurfaceView. It consumes the same
 * "canghui.native-scene.v0" JSON report and paints it with android.graphics.
 */
public final class CangHuiDrawIrView extends View {
    private static final String TAG = "CangHuiDrawIr";

    private String sceneJson = "";
    private int sceneWidth = 0;
    private int sceneHeight = 0;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF rect = new RectF();

    public CangHuiDrawIrView(Context context) {
        super(context);
        setFocusable(true);
        setContentDescription("CangHui Draw IR Android renderer");
    }

    public CangHuiDrawIrView(Context context, AttributeSet attrs) {
        super(context, attrs);
        setFocusable(true);
    }

    public void setSceneJson(String json) {
        this.sceneJson = json == null ? "" : json;
        postInvalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        canvas.drawColor(Color.rgb(239, 243, 248));
        if (sceneJson.isEmpty()) {
            return;
        }
        try {
            JSONObject root = new JSONObject(sceneJson);
            JSONArray frames = root.optJSONArray("frames");
            if (frames == null || frames.length() == 0) {
                return;
            }
            JSONObject frame = frames.getJSONObject(0);
            sceneWidth = frame.optInt("width", getWidth());
            sceneHeight = frame.optInt("height", getHeight());
            JSONArray commands = frame.optJSONArray("drawIr");
            if (commands == null) {
                return;
            }
            float sx = getWidth() / (float) sceneWidth;
            float sy = getHeight() / (float) sceneHeight;
            canvas.save();
            canvas.scale(sx, sy);
            for (int i = 0; i < commands.length(); i++) {
                JSONObject command = commands.getJSONObject(i);
                String kind = command.optString("kind");
                JSONObject data = command.optJSONObject("data");
                if (data == null) {
                    continue;
                }
                drawCommand(canvas, kind, data);
            }
            canvas.restore();
        } catch (Exception e) {
            Log.w(TAG, "drawIr parse failed", e);
        }
    }

    private void drawCommand(Canvas canvas, String kind, JSONObject data) {
        switch (kind) {
            case "scene.begin":
                canvas.drawColor(color(data.optJSONObject("color")));
                break;
            case "paint.fill":
                paint.setStyle(Paint.Style.FILL);
                paint.setColor(color(data.optJSONObject("color")));
                rect.set(x(data), y(data), x(data) + w(data), y(data) + h(data));
                canvas.drawRect(rect, paint);
                break;
            case "paint.fill-rounded-rect":
                paint.setStyle(Paint.Style.FILL);
                paint.setColor(color(data.optJSONObject("color")));
                rect.set(x(data), y(data), x(data) + w(data), y(data) + h(data));
                canvas.drawRoundRect(rect, radius(data), radius(data), paint);
                break;
            case "paint.stroke-rounded-rect":
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth((float) data.optDouble("strokeWidth", 1.0));
                paint.setColor(color(data.optJSONObject("color")));
                rect.set(x(data), y(data), x(data) + w(data), y(data) + h(data));
                canvas.drawRoundRect(rect, radius(data), radius(data), paint);
                break;
            case "paint.line":
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth((float) data.optDouble("width", 1.0));
                paint.setColor(color(data.optJSONObject("color")));
                canvas.drawLine(
                        (float) data.optDouble("x1"), (float) data.optDouble("y1"),
                        (float) data.optDouble("x2"), (float) data.optDouble("y2"), paint);
                break;
            case "paint.fill-circle":
                paint.setStyle(Paint.Style.FILL);
                paint.setColor(color(data.optJSONObject("color")));
                canvas.drawCircle(
                        (float) data.optDouble("cx"), (float) data.optDouble("cy"),
                        (float) data.optDouble("radius"), paint);
                break;
            case "text":
                paint.setStyle(Paint.Style.FILL);
                paint.setColor(color(data.optJSONObject("color")));
                paint.setTextSize((float) data.optDouble("pointSize", 15.0));
                paint.setTypeface(data.optBoolean("bold", false)
                        ? Typeface.DEFAULT_BOLD : Typeface.DEFAULT);
                canvas.drawText(data.optString("text", ""),
                        (float) data.optDouble("x"), (float) data.optDouble("y") + paint.getTextSize(),
                        paint);
                break;
            case "symbol":
                // Android has no SF Symbols; draw a placeholder glyph/box.
                paint.setStyle(Paint.Style.FILL);
                paint.setColor(color(data.optJSONObject("color")));
                rect.set(x(data), y(data), x(data) + w(data), y(data) + h(data));
                canvas.drawOval(rect, paint);
                break;
            case "clip.push":
                canvas.save();
                rect.set(x(data), y(data), x(data) + w(data), y(data) + h(data));
                canvas.clipRect(rect);
                break;
            case "clip.pop":
                canvas.restore();
                break;
            default:
                break;
        }
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        Log.i(TAG, "touch action=" + event.getActionMasked()
                + " x=" + event.getX() + " y=" + event.getY());
        return true;
    }

    private static float x(JSONObject data) { return (float) data.optDouble("x", 0.0); }
    private static float y(JSONObject data) { return (float) data.optDouble("y", 0.0); }
    private static float w(JSONObject data) { return (float) data.optDouble("width", 0.0); }
    private static float h(JSONObject data) { return (float) data.optDouble("height", 0.0); }
    private static float radius(JSONObject data) { return (float) data.optDouble("radius", 0.0); }

    private static int color(JSONObject c) {
        if (c == null) { return Color.WHITE; }
        int r = c.optInt("r", 255);
        int g = c.optInt("g", 255);
        int b = c.optInt("b", 255);
        int a = c.optInt("a", 255);
        return Color.argb(a, r, g, b);
    }
}
