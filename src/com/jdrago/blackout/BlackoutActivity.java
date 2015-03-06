package com.jdrago.blackout;

import android.app.Activity;
import android.graphics.Point;
import android.os.Bundle;
import android.util.Log;
import android.view.Display;
import android.view.View;

import com.jdrago.blackout.bridge.*;
import com.jdrago.blackout.BlackoutView;

class BlackoutApp implements NativeApp
{
    private static final String TAG = "Blackout";

    private BlackoutActivity activity_;

    public BlackoutApp(BlackoutActivity activity)
    {
        activity_ = activity;
    }

    public void drawImage(String textureName, float srcX, float srcY, float srcW, float srcH, float dstX, float dstY, float dstW, float dstH, float rot, float anchorX, float anchorY)
    {
        activity_.drawImage(textureName, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH, rot, anchorX, anchorY);
    }

    public void log(String s)
    {
        Log.v(TAG, s);
    }
}

public class BlackoutActivity extends Activity
{
    private static final String TAG = "Blackout";

    private BlackoutApp app_;
    private BlackoutView view_;
    private BlackoutRenderer renderer_;
    private Script script_;
    private long lastTime_;

    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);

        lastTime_ = System.currentTimeMillis();

        Display display = getWindowManager().getDefaultDisplay();
        Point size = new Point();
        display.getSize(size);

        app_ = new BlackoutApp(this);
        script_ = new Script();
        synchronized(script_) {
            script_.startup(app_, size.x, size.y);
        }
        renderer_ = new BlackoutRenderer(getApplication(), this);
        view_ = new BlackoutView(getApplication(), renderer_, this);
        setContentView(view_);
        immerse();

        String state = "";
        if(savedInstanceState != null)
            state = savedInstanceState.getString("state");

        Log.d(TAG, "about to call load with: "+state);
        synchronized(script_) {
            script_.load(state);
        }
    }

    @Override
    protected void onPause()
    {
        Log.d(TAG, "onPause (native)");

        super.onPause();
    }

    @Override
    protected void onResume()
    {
        Log.d(TAG, "onResume (native)");

        super.onResume();
        immerse();
    }

    protected void onSaveInstanceState(Bundle savedInstanceState)
    {
        super.onSaveInstanceState(savedInstanceState);

        Log.d(TAG, "onSaveInstanceState (native)");

        String state;
        synchronized(script_) {
            state = script_.save();
        }
        savedInstanceState.putString("state", state);
    }

    void immerse()
    {
        this.getWindow().getDecorView().setSystemUiVisibility(
              View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_FULLSCREEN
            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            | View.INVISIBLE);
    }

    public void update()
    {
        long now = System.currentTimeMillis();
        double dt = (double)(now - lastTime_);
        lastTime_ = now;
        synchronized(script_) {
            script_.update(dt);
        }
    }

    public void touchDown(double x, double y)
    {
        synchronized(script_) {
            script_.touchDown(x, y);
        }
    }

    public void touchMove(double x, double y)
    {
        synchronized(script_) {
            script_.touchMove(x, y);
        }
    }

    public void touchUp(double x, double y)
    {
        synchronized(script_) {
            script_.touchUp(x, y);
        }
    }

    public void drawImage(String textureName, float srcX, float srcY, float srcW, float srcH, float dstX, float dstY, float dstW, float dstH, float rot, float anchorX, float anchorY)
    {
        renderer_.drawImage(textureName, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH, rot, anchorX, anchorY);
    }
}
