package com.jdrago.blackout;

import android.app.Activity;
import android.graphics.Point;
import android.os.Bundle;
import android.util.Log;
import android.view.Display;
import android.view.View;
import android.view.Window;

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
    private Script script_;
    private long lastTime_;
    Point displaySize_;
    private double coordinateScale_;

    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);

        lastTime_ = System.currentTimeMillis();

        Display display = getWindowManager().getDefaultDisplay();
        displaySize_ = new Point();
        display.getRealSize(displaySize_);
        coordinateScale_ = 1;
        Log.d(TAG, "BlackoutActivity::onCreate(): displaySize: "+displaySize_.x+","+displaySize_.y);

        app_ = new BlackoutApp(this);
        script_ = new Script();
        synchronized(script_) {
            script_.startup(app_, displaySize_.x, displaySize_.y);
        }

        view_ = new BlackoutView(getApplication(), this, displaySize_);
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
    public void onWindowFocusChanged (boolean hasFocus)
    {
        super.onWindowFocusChanged(hasFocus);

        View content = getWindow().findViewById(Window.ID_ANDROID_CONTENT);
        double touchWidth = content.getWidth();
        double touchHeight = content.getHeight();
        coordinateScale_ = displaySize_.x / touchWidth;
        Log.d(TAG, "touchSize: "+touchWidth+","+touchHeight+" coordinateScale: "+coordinateScale_);
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

    public boolean update()
    {
        long now = System.currentTimeMillis();
        double dt = (double)(now - lastTime_);
        lastTime_ = now;
        boolean needsRender = false;
        synchronized(script_) {
            needsRender = script_.update(dt);
        }
        return needsRender;
    }

    public void render()
    {
        synchronized(script_) {
            script_.render();
        }
    }

    public void touchDown(double x, double y)
    {
        x *= coordinateScale_;
        y *= coordinateScale_;
        synchronized(script_) {
            script_.touchDown(x, y);
        }
        view_.requestRender();
    }

    public void touchMove(double x, double y)
    {
        x *= coordinateScale_;
        y *= coordinateScale_;
        synchronized(script_) {
            script_.touchMove(x, y);
        }
        view_.requestRender();
    }

    public void touchUp(double x, double y)
    {
        x *= coordinateScale_;
        y *= coordinateScale_;
        synchronized(script_) {
            script_.touchUp(x, y);
        }
        view_.requestRender();
    }

    public void drawImage(String textureName, float srcX, float srcY, float srcW, float srcH, float dstX, float dstY, float dstW, float dstH, float rot, float anchorX, float anchorY)
    {
        view_.renderer().drawImage(textureName, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH, rot, anchorX, anchorY);
    }
}
