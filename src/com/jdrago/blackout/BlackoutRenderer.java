package com.jdrago.blackout;

// import com.jdrago.blackout.bridge.*;

import android.content.Context;
import android.graphics.Point;
import android.os.Trace;
import android.util.Log;

import java.lang.Thread;
import java.util.HashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import javax.microedition.khronos.opengles.GL10;

import com.eclipsesource.v8.V8;
import com.eclipsesource.v8.V8Array;

public class BlackoutRenderer extends QuadRenderer //implements NativeApp
{
    static private final int MAX_FPS = 30;
    static private final int MIN_MS_PER_FRAME = 1000 / MAX_FPS;

    public enum TouchType
    {
        DOWN,
        MOVE,
        UP
    }

    public class Touch
    {
        public Touch(TouchType atype, double ax, double ay)
        {
            type = atype;
            x = ax;
            y = ay;
        }
        public TouchType type;
        public double x;
        public double y;
    };

    private static String TAG = "Blackout";
    private HashMap<String, Texture> textures_;
    private BlackoutActivity activity_;
    private BlackoutView view_;
    private long lastTime_;
    private long frameCounter_;
    Point displaySize_;
    String script_;
    Context context_;
    private boolean scriptReady_;
    ConcurrentLinkedQueue<Touch> inputQueue_;
    private V8 v8_;

    public BlackoutRenderer(Context context, BlackoutActivity activity, BlackoutView view, Point displaySize, String script)
    {
        super(context);

        activity_ = activity;
        view_ = view;
        textures_ = new HashMap<String, Texture>();
        lastTime_ = System.currentTimeMillis();
        displaySize_ = displaySize;
        context_ = context;
        script_ = script;
        scriptReady_ = false;
        frameCounter_ = 0;
        inputQueue_ = new ConcurrentLinkedQueue<Touch>();

        //Log.d(TAG, "Renderer MaxFPS: "+MAX_FPS+", MinMSPerFrame: "+MIN_MS_PER_FRAME);

        // jsStartup(displaySize.x, displaySize.y);

        // String state = "";
        // if(savedInstanceState != null)
        //     state = savedInstanceState.getString("state");

        // Log.d(TAG, "about to call load with: "+state);
        // jsLoad(state);
    }

    public void loadTextures()
    {
        textures_.put("cards", loadPNG(R.raw.cards));
        textures_.put("unispace", loadPNG(R.raw.unispace));
        textures_.put("square", loadPNG(R.raw.square));
    }

    @Override
    public Texture getTexture(String textureName)
    {
        return textures_.get(textureName);
    }

    public void onDrawFrame(GL10 glUnused)
    {
        frameCounter_++;
        // Log.d(TAG, "onDrawFrame: "+frameCounter_);

        // Cap our framerate to MAX_FPS by measuring the time it took
        // to get back in this function and taking a break before rendering again
        long now = System.currentTimeMillis();
        long dt = now - lastTime_;
/*
        // Comment out this block to disable frame limiting
        {
            if(dt < MIN_MS_PER_FRAME)
            {
               try {
                   Thread.sleep(MIN_MS_PER_FRAME - dt);
               } catch(InterruptedException e) {
                   // Restore the interrupted status
                   Thread.currentThread().interrupt();
               }
            }

            // post-sleep, update now and dt again
            now = System.currentTimeMillis();
            dt = now - lastTime_;
        }
*/
        lastTime_ = now;

        jsUpdate((double)dt);

        renderBegin(0.0f, 0.25f, 0.0f);
        jsRender();
        renderEnd();
    }

    // --------------------------------------------------------------------------------------------
    // V8 Initialization

    public void initializeV8(Context context, String script)
    {
        Log.d(TAG, "Loading script, "+script.length()+" chars");

        v8_ = V8.createV8Runtime(null, context.getApplicationInfo().dataDir);
        v8_.registerJavaMethod(this, "nativeLog", "nativeLog", new Class<?>[] { String.class });
        v8_.registerJavaMethod(this, "nativeDrawImage", "nativeDrawImage", new Class<?>[] { String.class, Double.TYPE, Double.TYPE, Double.TYPE, Double.TYPE, Double.TYPE, Double.TYPE, Double.TYPE, Double.TYPE, Double.TYPE, Double.TYPE, Double.TYPE, Double.TYPE, Double.TYPE, Double.TYPE, Double.TYPE });
        v8_.executeVoidScript(script);
    }

    // --------------------------------------------------------------------------------------------
    // Calls into JS

    public void jsUpdate(double dt)
    {
        if(!scriptReady_)
        {
            initializeV8(context_, script_);
            jsStartup();
            scriptReady_ = true;
        }

        boolean needsRender = false;
        Touch touch;
        while((touch = inputQueue_.poll()) != null)
        {
            String functionName;
            switch(touch.type)
            {
                case DOWN: functionName = "touchDown"; break;
                case UP:   functionName = "touchUp";   break;
                default:
                case MOVE: functionName = "touchMove"; break;
            };

            // Log.d(TAG, functionName+": "+touch.x+","+touch.y+"");

            Trace.beginSection("touch"); try {
            V8Array parameters = new V8Array(v8_);
            parameters.push(touch.x);
            parameters.push(touch.y);
            v8_.executeVoidFunction(functionName, parameters);
            } finally { Trace.endSection(); }

            needsRender = true;
        }

        V8Array parameters = new V8Array(v8_);
        parameters.push(dt);
        Trace.beginSection("update"); try {
        if(v8_.executeBooleanFunction("update", parameters))
            needsRender = true;
        } finally { Trace.endSection(); }

        // if(needsRender) {
            // Log.d(TAG, "needsRender from onDrawFrame");
            view_.requestRender();
        // }
    }

    public void jsStartup()
    {
        V8Array parameters = new V8Array(v8_);
        parameters.push(displaySize_.x);
        parameters.push(displaySize_.y);
        v8_.executeVoidFunction("startup", parameters);
    }

    public void jsRender()
    {
        V8Array parameters = new V8Array(v8_);
        Trace.beginSection("render"); try {
        v8_.executeVoidFunction("render", parameters);
        } finally { Trace.endSection(); }
    }

    public void jsLoad(String s)
    {
        // synchronized(v8_) {
        //     V8Array parameters = new V8Array(v8_);
        //     parameters.push(s);
        //     v8_.executeVoidFunction("load", parameters);
        // }
    }

    public String jsSave()
    {
        String s = "";
        // synchronized(v8_) {
        //     V8Array parameters = new V8Array(v8_);
        //     s = v8_.executeStringFunction("save", parameters);
        // }
        return s;
    }

    public void jsTouchDown(double x, double y)
    {
        Touch touch = new Touch(TouchType.DOWN, x, y);
        inputQueue_.offer(touch);
    }

    public void jsTouchMove(double x, double y)
    {
        Touch touch = new Touch(TouchType.MOVE, x, y);
        inputQueue_.offer(touch);
    }

    public void jsTouchUp(double x, double y)
    {
        Touch touch = new Touch(TouchType.UP, x, y);
        inputQueue_.offer(touch);
    }

    // --------------------------------------------------------------------------------------------
    // Calls from JS

    public void nativeLog(String s)
    {
        Log.d(TAG, "nativeLog: " + s);
    }

    public void nativeDrawImage(String textureName, final double srcX, final double srcY, final double srcW, final double srcH, final double dstX, final double dstY, final double dstW, final double dstH, final double rot, final double anchorX, final double anchorY, final double r, final double g, final double b, final double a)
    {
        // Log.d(TAG, "nativeDrawImage() textureName: "+textureName+" srcX: "+srcX+" srcY: "+srcY+" srcW: "+srcW+" srcH: "+srcH+" dstX: "+dstX+" dstY: "+dstY+" dstW: "+dstW+" dstH: "+dstH+" rot: "+rot+" anchorX: "+anchorX+" anchorY: "+anchorY+" r: "+r+" g: "+g+" b: "+b+" a: "+a);
        for(int i = 0; i < 10; i++)
        view_.renderer().drawImage(textureName,
            (float)srcX, (float)srcY, (float)srcW, (float)srcH,
            (float)dstX, (float)dstY, (float)dstW, (float)dstH,
            (float)rot, (float)anchorX, (float)anchorY,
            (float)r, (float)g, (float)b, (float)a);
    }
}